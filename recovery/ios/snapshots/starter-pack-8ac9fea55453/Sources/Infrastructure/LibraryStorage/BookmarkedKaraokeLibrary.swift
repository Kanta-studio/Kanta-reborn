import Foundation
import GeloKaraokeCore
import LegacyCompatibility

public struct LibraryLoadIssue: Equatable, Sendable {
    public let sourceID: UUID
    public let sourceName: String
    public let message: String

    public init(
        sourceID: UUID,
        sourceName: String,
        message: String
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.message = message
    }
}

public struct LibrarySoundFontSelection: Sendable {
    public let primaryURL: URL
    public let fallbackURLs: [URL]

    public init(
        primaryURL: URL,
        fallbackURLs: [URL]
    ) {
        self.primaryURL = primaryURL
        self.fallbackURLs = fallbackURLs
    }
}

public struct LibraryReloadReport: Equatable, Sendable {
    public let sourceCount: Int
    public let songCount: Int
    public let issues: [LibraryLoadIssue]

    public init(
        sourceCount: Int,
        songCount: Int,
        issues: [LibraryLoadIssue]
    ) {
        self.sourceCount = sourceCount
        self.songCount = songCount
        self.issues = issues
    }
}

/// Per-source counts projected from the current validated in-memory library.
/// Catalog-only songs can be searched but cannot be queued or played.
public struct LibraryCatalogSummary: Equatable, Sendable {
    public var playableCount: Int
    public var catalogOnlyCount: Int

    public var searchableCount: Int {
        playableCount + catalogOnlyCount
    }

    public init(playableCount: Int = 0, catalogOnlyCount: Int = 0) {
        self.playableCount = playableCount
        self.catalogOnlyCount = catalogOnlyCount
    }
}

public enum BookmarkedKaraokeLibraryError:
    Error,
    Equatable,
    Sendable
{
    case songNotFound(SongID)
    case catalogOnlySong(SongID)
    case sourceUnavailable(UUID)
    case invalidRelativePath(String)
    case fileUnavailable(String)
    case fileSizeUnavailable(String)
}

extension BookmarkedKaraokeLibraryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .songNotFound(songID):
            return "The selected song is no longer in the loaded library (\(songID.rawValue))."
        case .catalogOnlySong:
            return "This title is searchable, but its compatible media is not available for playback."
        case .sourceUnavailable:
            return "The song library folder is unavailable. Reopen Song Library and grant access again."
        case let .invalidRelativePath(path):
            return "The library contains an unsafe or invalid path: \(path)."
        case let .fileUnavailable(name):
            return "The media file is missing or unavailable: \(name)."
        case let .fileSizeUnavailable(name):
            return "The media file size could not be verified: \(name)."
        }
    }
}

public actor BookmarkedKaraokeLibrary: KaraokeLibraryAccess {
    private struct ActiveSource: Sendable {
        let rootURL: URL
        let didStartSecurityScope: Bool
    }

    private let starterStore: StarterKaraokeStore?
    private let starterSoundFontURL: URL?
    private var starterRevision: UInt64 = 0
    private var starterURLs: [SongID: URL] = [:]
    private var starterSongs: [LibrarySong] = []
    private var starterRemoved: Set<String> = []
    private static let starterSourceID = UUID(uuidString: "00000000-0000-0000-0000-000000000045")!

    private let registry: LibrarySourceRegistry
    private let containerCacheRoot: URL

    private var reloadGeneration = UUID()
    private var initialLoadTask: Task<LibraryReloadReport, Never>?
    private var lastReloadReport: LibraryReloadReport?
    private var activeSources: [UUID: ActiveSource] = [:]
    private var sourceRecordsByID:
        [UUID: LibrarySourceRecord] = [:]
    private var looseEntriesByID: [SongID: LooseMediaCatalogEntry] = [:]
    private var containerEntriesByID: [SongID: IndexedContainerCatalogEntry] = [:]
    private var catalogOnlySongsByID: [SongID: LibrarySong] = [:]
    private var orderedSongs: [LibrarySong] = []
    private let artistOverridesURL: URL
    private var artistOverrides: [String: String] = [:]

    private let catalogFileURL: URL
    private var catalogIndex: SQLiteSongCatalog?
    private var midiFileCache: [SongID: StandardMIDIFile] = [:]
    private var lyricCache: [SongID: [KaraokeLyricCue]] = [:]
    private var scoringTargetCache:
        [SongID: MIDIMelodyTargetExtraction] = [:]

    public init(registry: LibrarySourceRegistry,
                starterStore: StarterKaraokeStore? = nil,
                starterSoundFontURL: URL? = nil,
                catalogFileURL: URL? = nil) {
        self.starterStore = starterStore
        self.starterSoundFontURL = starterSoundFontURL
        self.registry = registry
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.catalogFileURL = catalogFileURL ?? root.appendingPathComponent("KANTA/song-catalog.sqlite")
        self.artistOverridesURL = root.appendingPathComponent(
            "KANTA/song-artists.json"
        )
        if let data = try? Data(contentsOf: artistOverridesURL),
           let overrides = try? JSONDecoder().decode(
                [String: String].self, from: data
           ) {
            self.artistOverrides = overrides
        }
        self.containerCacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "KANTA-ContainerPayloads/" + UUID().uuidString,
                isDirectory: true
            )
    }

    public func loadIfNeeded() async -> LibraryReloadReport {
        if let report = lastReloadReport { return report }
        if let task = initialLoadTask { return await task.value }
        let task = Task { await self.reload() }
        initialLoadTask = task
        let report = await task.value
        initialLoadTask = nil
        return report
    }

    @discardableResult
    public func reload() async -> LibraryReloadReport {
        let generation = UUID()
        reloadGeneration = generation
        var starterIssue: LibraryLoadIssue?
        if let starterStore {
            do { _ = try await starterStore.installAvailableSongs() }
            catch {
                starterIssue = LibraryLoadIssue(sourceID: Self.starterSourceID,
                    sourceName: "Starter Songs", message: error.localizedDescription)
            }
            let snapshot = await starterStore.snapshot()
            guard generation == reloadGeneration, !Task.isCancelled else {
                return LibraryReloadReport(sourceCount: activeSources.count,
                                           songCount: orderedSongs.count, issues: [])
            }
            applyStarterSnapshot(snapshot)
        }
        let sources = await registry.all()
        guard generation == reloadGeneration, !Task.isCancelled else {
            return LibraryReloadReport(sourceCount: activeSources.count,
                                       songCount: orderedSongs.count, issues: [])
        }
        var refreshedBookmarks: [(UUID, Data)] = []
        releaseActiveSources()
        clearContainerCache()
        midiFileCache.removeAll(keepingCapacity: false)
        lyricCache.removeAll(keepingCapacity: false)
        scoringTargetCache.removeAll(keepingCapacity: false)

        sourceRecordsByID = Dictionary(
            uniqueKeysWithValues: sources.map {
                ($0.id, $0)
            }
        )
        var issues: [LibraryLoadIssue] = starterIssue.map { [$0] } ?? []
        var newLooseEntries: [LooseMediaCatalogEntry] = []
        var newContainerEntries: [IndexedContainerCatalogEntry] = []
        var newCatalogOnlySongs: [LibrarySong] = []

        for source in sources {
            do {
                var stale = false
                let rootURL = try URL(
                    resolvingBookmarkData: source.bookmarkData,
                    bookmarkDataIsStale: &stale
                )

                let didStart =
                    rootURL.startAccessingSecurityScopedResource()

                activeSources[source.id] = ActiveSource(
                    rootURL: rootURL,
                    didStartSecurityScope: didStart
                )
                var updatedSource = source
                if stale {
                    updatedSource.bookmarkData =
                        try rootURL.bookmarkData(
                            options: .minimalBookmark,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                    refreshedBookmarks.append((source.id, updatedSource.bookmarkData))
                    sourceRecordsByID[source.id] =
                        updatedSource
                }

                newLooseEntries.append(
                    contentsOf: LooseMediaCatalog.entries(
                        for: updatedSource
                    )
                )

                if let indexPath = IndexedContainerCatalog.indexRelativePath(
                    for: updatedSource
                ) {
                    do {
                        let indexURL = try resolvedURL(
                            relativePath: indexPath, under: rootURL
                        )
                        try validateRegularFile(indexURL)
                        let indexData = try Data(
                            contentsOf: indexURL, options: [.mappedIfSafe]
                        )

                        if let files = IndexedContainerCatalog.sourceFiles(
                            for: updatedSource
                        ) {
                            do {
                                let containerURL = try resolvedURL(
                                    relativePath: files.blobRelativePath,
                                    under: rootURL
                                )
                                try validateRegularFile(containerURL)
                                newContainerEntries.append(
                                    contentsOf: try IndexedContainerCatalog.entries(
                                        for: updatedSource, indexData: indexData,
                                        containerURL: containerURL
                                    )
                                )
                            } catch {
                                // Keep the titles searchable, without
                                // inferring unsupported playback offsets.
                                newCatalogOnlySongs.append(
                                    contentsOf: try IndexedContainerCatalog.catalogOnlySongs(
                                        for: updatedSource, indexData: indexData
                                    )
                                )
                                issues.append(LibraryLoadIssue(
                                    sourceID: source.id,
                                    sourceName: source.displayName,
                                    message: "Song titles are available for search, "
                                        + "but media playback is not supported: "
                                        + error.localizedDescription
                                ))
                            }
                        } else {
                            newCatalogOnlySongs.append(
                                contentsOf: try IndexedContainerCatalog.catalogOnlySongs(
                                    for: updatedSource, indexData: indexData
                                )
                            )
                        }
                    } catch {
                        issues.append(LibraryLoadIssue(
                            sourceID: source.id,
                            sourceName: source.displayName,
                            message: "The indexed song titles could not be read: "
                                + error.localizedDescription
                        ))
                    }
                }
            } catch {
                issues.append(
                    LibraryLoadIssue(
                        sourceID: source.id,
                        sourceName: source.displayName,
                        message: error.localizedDescription
                    )
                )
            }
        }

        looseEntriesByID = Dictionary(
            newLooseEntries.map { ($0.song.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        containerEntriesByID = Dictionary(
            newContainerEntries.map { ($0.song.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        catalogOnlySongsByID = Dictionary(
            newCatalogOnlySongs.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        orderedSongs = (
            looseEntriesByID.values.map(\.song)
            + containerEntriesByID.values.map(\.song)
            + catalogOnlySongsByID.values
            + starterSongs
        )
        .map { withArtistOverride($0) }
        .sorted {
            let order = $0.title.localizedStandardCompare($1.title)
            if order != .orderedSame {
                return order == .orderedAscending
            }
            return $0.id.rawValue < $1.id.rawValue
        }

        // Persist only successfully validated active sources. This transaction
        // replaces the catalog atomically and never saves karaoke payload bytes.
        // An unavailable/corrupted index falls back to the in-memory catalog;
        // do not expose potentially stale persisted entries.
        do {
            if catalogIndex == nil {
                catalogIndex = try SQLiteSongCatalog(fileURL: catalogFileURL)
            }
            try catalogIndex?.replaceIfChanged(orderedSongs)
        } catch {
            catalogIndex = nil
        }

        lastReloadReport = LibraryReloadReport(
            sourceCount: activeSources.count, songCount: orderedSongs.count, issues: issues
        )
        // Rebuild is complete before crossing an actor boundary again.
        for (id, bookmark) in refreshedBookmarks {
            guard generation == reloadGeneration else { break }
            do {
                try await registry.refreshBookmark(id: id, bookmarkData: bookmark)
            } catch {
                issues.append(LibraryLoadIssue(
                    sourceID: id,
                    sourceName: sourceRecordsByID[id]?.displayName ?? "Library",
                    message: error.localizedDescription
                ))
            }
        }
        let report = LibraryReloadReport(
            sourceCount: activeSources.count,
            songCount: orderedSongs.count,
            issues: issues
        )
        if generation == reloadGeneration { lastReloadReport = report }
        return report
    }

    /// Store snapshots carry a monotonic revision. A delayed actor continuation
    /// cannot republish a song removed/restored by a newer operation.
    private func applyStarterSnapshot(_ snapshot: StarterKaraokeStore.Snapshot) {
        guard snapshot.revision >= starterRevision else { return }
        starterRevision = snapshot.revision
        for id in starterURLs.keys {
            midiFileCache[id] = nil
            lyricCache[id] = nil
            scoringTargetCache[id] = nil
        }
        starterURLs = Dictionary(uniqueKeysWithValues: snapshot.urls.map {
            (StarterKaraokeStore.song($0.key).id, $0.value)
        })
        starterSongs = StarterKaraokeStore.identifiers.compactMap {
            snapshot.urls[$0] == nil ? nil : StarterKaraokeStore.song($0)
        }
        starterRemoved = snapshot.removed
        orderedSongs.removeAll { $0.id.rawValue.hasPrefix("starter:") }
        orderedSongs += starterSongs.map { withArtistOverride($0) }
        orderedSongs.sort {
            let order = $0.title.localizedStandardCompare($1.title)
            return order == .orderedSame ? $0.id.rawValue < $1.id.rawValue : order == .orderedAscending
        }
        do { try catalogIndex?.replaceIfChanged(orderedSongs) }
        catch { catalogIndex = nil }
        if let report = lastReloadReport {
            lastReloadReport = LibraryReloadReport(sourceCount: report.sourceCount,
                songCount: orderedSongs.count, issues: report.issues)
        }
    }

    public func starterSongAvailability() -> Set<String> {
        Set(StarterKaraokeStore.identifiers.filter {
            starterURLs[StarterKaraokeStore.song($0).id] != nil
        })
    }

    /// Store owns file transactions; this actor owns every catalog publication.
    /// No reload of imported scopes or active container payloads is needed.
    public func changeStarterSong(_ identifier: String?, restore: Bool) async throws {
        _ = await loadIfNeeded()
        try Task.checkCancellation()
        guard let starterStore else { throw StarterKaraokeStore.StoreError.invalidBundledFile }
        do {
            if let identifier {
                if restore { _ = try await starterStore.restore(identifier) }
                else { try await starterStore.remove(identifier) }
            } else if restore {
                try await starterStore.restoreAll()
            } else { throw StarterKaraokeStore.StoreError.unknownSong }
        } catch {
            applyStarterSnapshot(await starterStore.snapshot())
            throw error
        }
        // Always publish completed durable effects, even if the caller canceled.
        applyStarterSnapshot(await starterStore.snapshot())
    }

    public func sourceSongCounts() -> [UUID: LibraryCatalogSummary] {
        // Only the currently loaded, validated library entries count.
        // No SQLite query, index re-read, or media/container traversal.
        var counts: [UUID: LibraryCatalogSummary] = [:]
        for entry in looseEntriesByID.values {
            counts[entry.sourceID, default: LibraryCatalogSummary()]
                .playableCount += 1
        }
        for entry in containerEntriesByID.values {
            counts[entry.sourceID, default: LibraryCatalogSummary()]
                .playableCount += 1
        }
        for (songID, _) in catalogOnlySongsByID {
            // Catalog-only IDs are generated as indexed:<UUID>:<ordinal>.
            let fields = songID.rawValue.split(separator: ":")
            guard fields.count == 3,
                  let sourceID = UUID(uuidString: String(fields[1])) else {
                continue
            }
            counts[sourceID, default: LibraryCatalogSummary()]
                .catalogOnlyCount += 1
        }
        return counts
    }

    /// Shareable metadata-only book for the user's currently imported library.
    /// No audio, encrypted payload, SoundFont, bookmark or file-system path
    /// is included. Files are generated on device, not uploaded.
    static func songbookExportURL() -> URL {
        // The caller owns cleanup after sharing; never overwrite an active export.
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "KANTA-Songbook-" + UUID().uuidString + ".csv"
        )
    }

    public func exportSongbookCSV() async throws -> URL {
        _ = await loadIfNeeded()
        let path = Self.songbookExportURL()

        try KantaSongbookCSV.encode(orderedSongs).write(
            to: path, options: [.atomic]
        )
        return path
    }

    public func searchSongs(
        matching query: String,
        limit: Int = 200
    ) -> [LibrarySong] {
        searchSongs(matching: query, limit: limit, offset: 0)
    }

    /// Each request is bounded. Local CONTROL and paired LAN remote share
    /// this actor-owned search index and its validated SongIDs.
    public func searchSongs(
        matching query: String, limit: Int, offset: Int
    ) -> [LibrarySong] {
        let count = min(max(limit, 1), 500)
        let start = min(max(offset, 0), 500_000)
        let normalized = String(
            query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
        )
        if let catalogIndex,
           let results = try? catalogIndex.search(
                normalized, limit: count, offset: start
           ) {
            return results
        }

        // Fail-safe on older environments where SQLite FTS5 is unavailable,
        // disk full, or a catalog migration was interrupted.
        let matches: [LibrarySong]
        if normalized.isEmpty {
            matches = orderedSongs
        } else {
            matches = orderedSongs.filter { song in
                song.title.localizedCaseInsensitiveContains(normalized)
                || (song.artist?.localizedCaseInsensitiveContains(normalized) ?? false)
                || (song.code?.localizedCaseInsensitiveContains(normalized) ?? false)
            }
        }
        return Array(matches.dropFirst(start).prefix(count))
    }

    private func withArtistOverride(_ song: LibrarySong) -> LibrarySong {
        guard let artist = artistOverrides[song.id.rawValue] else {
            return song
        }
        var updated = song
        updated.artist = artist
        return updated
    }

    /// Artist names are not present in every imported index. Owners can
    /// optionally supply the missing metadata for their local songbook.
    /// Store only a SongID -> artist mapping, never modify source indexes.
    public func setArtist(
        _ name: String, for songID: SongID
    ) throws {
        guard let song = orderedSongs.first(where: { $0.id == songID }) else {
            throw BookmarkedKaraokeLibraryError.songNotFound(songID)
        }
        _ = song
        let trimmed = String(name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).prefix(200))
        var changes = artistOverrides
        if trimmed.isEmpty {
            changes.removeValue(forKey: songID.rawValue)
        } else {
            changes[songID.rawValue] = trimmed
        }
        try FileManager.default.createDirectory(
            at: artistOverridesURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(changes).write(
            to: artistOverridesURL, options: .atomic
        )
        artistOverrides = changes
        orderedSongs = orderedSongs.map { song in
            if song.id == songID {
                var updated = song
                updated.artist = trimmed.isEmpty ? nil : trimmed
                return updated
            }
            return song
        }
        do {
            try catalogIndex?.replaceIfChanged(orderedSongs)
        } catch {
            catalogIndex = nil
        }
    }

    public func song(
        id: SongID
    ) async throws -> LibrarySong? {
        guard let stored = starterSongs.first(where: { $0.id == id })
            ?? looseEntriesByID[id]?.song
            ?? containerEntriesByID[id]?.song
            ?? catalogOnlySongsByID[id] else { return nil }
        return withArtistOverride(stored)
    }

    public func playbackAsset(
        for songID: SongID
    ) async throws -> AudioPlaybackAsset {
        if let url = starterURLs[songID] {
            try validateRegularFile(url)
            let selection = try firstSoundFontSelection()
            return AudioPlaybackAsset(songID: songID, url: url, mediaKind: .kar,
                soundFontURL: selection?.primaryURL ?? starterSoundFontURL,
                fallbackSoundFontURLs: (selection?.fallbackURLs ?? []) +
                    (selection == nil ? [] : starterSoundFontURL.map { [$0] } ?? []))
        }
        if let entry = looseEntriesByID[songID] {
            return try playbackAsset(for: entry)
        }

        if let entry = containerEntriesByID[songID] {
            return try playbackAsset(for: entry)
        }

        if catalogOnlySongsByID[songID] != nil {
            throw BookmarkedKaraokeLibraryError.catalogOnlySong(songID)
        }
        throw BookmarkedKaraokeLibraryError.songNotFound(songID)
    }

    public func backgroundAsset(
        for songID: SongID
    ) async throws -> KaraokeBackgroundAsset? {
        if starterURLs[songID] != nil { return nil }
        guard let entry = looseEntriesByID[songID] else {
            if containerEntriesByID[songID] != nil
                || catalogOnlySongsByID[songID] != nil {
                return nil
            }
            throw BookmarkedKaraokeLibraryError.songNotFound(songID)
        }

        guard let relativePath = entry.backgroundRelativePath,
              let kind = entry.backgroundKind else {
            return nil
        }

        guard let source = activeSources[entry.sourceID] else {
            throw BookmarkedKaraokeLibraryError.sourceUnavailable(
                entry.sourceID
            )
        }

        let url = try resolvedURL(
            relativePath: relativePath,
            under: source.rootURL
        )
        try validateRegularFile(url)

        return KaraokeBackgroundAsset(
            url: url,
            kind: kind
        )
    }

    public func lyricCues(
        for songID: SongID
    ) async throws -> [KaraokeLyricCue] {
        if let url = starterURLs[songID] {
            try validateRegularFile(url)
            return try cacheLyricCues(songID: songID, mediaURL: url)
        }
        if let cached = lyricCache[songID] {
            return cached
        }

        if let entry = looseEntriesByID[songID] {
            guard entry.song.mediaKind == .midi
                    || entry.song.mediaKind == .kar else {
                lyricCache[songID] = []
                return []
            }

            guard let source = activeSources[entry.sourceID] else {
                throw BookmarkedKaraokeLibraryError.sourceUnavailable(
                    entry.sourceID
                )
            }

            let mediaURL = try resolvedURL(
                relativePath: entry.relativePath,
                under: source.rootURL
            )
            try validateRegularFile(mediaURL)
            return try cacheLyricCues(
                songID: songID,
                mediaURL: mediaURL
            )
        }

        if containerEntriesByID[songID] != nil {
            let asset = try await playbackAsset(for: songID)
            guard asset.mediaKind == .midi
                    || asset.mediaKind == .kar else {
                lyricCache[songID] = []
                return []
            }

            return try cacheLyricCues(
                songID: songID,
                mediaURL: asset.url
            )
        }

        throw BookmarkedKaraokeLibraryError.songNotFound(songID)
    }

    public func scoringTarget(
        for songID: SongID
    ) async throws -> MIDIMelodyTargetExtraction? {
        if let cached = scoringTargetCache[songID] {
            return cached
        }

        let asset = try await playbackAsset(for: songID)
        guard asset.mediaKind == .midi
                || asset.mediaKind == .kar else {
            return nil
        }

        let file = try standardMIDIFile(
            songID: songID,
            mediaURL: asset.url
        )
        let extraction = MIDIMelodyTargetExtractor.extract(
            from: file
        )
        scoringTargetCache[songID] = extraction
        return extraction
    }

    public func close() {
        reloadGeneration = UUID()
        initialLoadTask?.cancel()
        initialLoadTask = nil
        lastReloadReport = nil
        releaseActiveSources()
        clearContainerCache()
        looseEntriesByID.removeAll(keepingCapacity: false)
        containerEntriesByID.removeAll(keepingCapacity: false)
        orderedSongs.removeAll(keepingCapacity: false)
        midiFileCache.removeAll(keepingCapacity: false)
        lyricCache.removeAll(keepingCapacity: false)
        scoringTargetCache.removeAll(keepingCapacity: false)
    }


    public func soundFontSelection(
        forSourceID sourceID: UUID
    ) throws -> LibrarySoundFontSelection? {
        guard let source =
                sourceRecordsByID[sourceID],
              let activeSource =
                activeSources[sourceID],
              let primaryRelativePath =
                LooseMediaCatalog.preferredSoundFont(
                    in: source.lastScan?.assets ?? [],
                    preferredRelativePath:
                        source.preferredSoundFontRelativePath
                ) else {
            return nil
        }

        let primaryURL = try resolvedURL(
            relativePath: primaryRelativePath,
            under: activeSource.rootURL
        )

        let fallbacks = try soundFontFallbackURLs(
            sourceID: sourceID,
            primaryRelativePath:
                primaryRelativePath
        )

        return LibrarySoundFontSelection(
            primaryURL: primaryURL,
            fallbackURLs: fallbacks
        )
    }

    public func firstSoundFontSelection()
        throws -> LibrarySoundFontSelection?
    {
        for sourceID in sourceRecordsByID.keys.sorted(
            by: { $0.uuidString < $1.uuidString }
        ) {
            if let selection =
                try soundFontSelection(
                    forSourceID: sourceID
                ) {
                return selection
            }
        }
        return nil
    }

    private func soundFontFallbackURLs(
        sourceID: UUID,
        primaryRelativePath: String?
    ) throws -> [URL] {
        guard let source =
                sourceRecordsByID[sourceID],
              let activeSource =
                activeSources[sourceID] else {
            return []
        }

        let normalizedPrimary =
            primaryRelativePath.flatMap {
                LooseMediaCatalog.normalizedRelativePath(
                    $0
                )
            }

        let candidates =
            (source.lastScan?.assets ?? [])
            .filter {
                $0.kind == .soundFont
                    && $0.relativePath
                        .lowercased()
                        .hasSuffix(".sf2")
            }
            .compactMap {
                asset -> (
                    path: String,
                    size: Int64
                )? in
                guard let normalized =
                        LooseMediaCatalog
                            .normalizedRelativePath(
                                asset.relativePath
                            ),
                      normalized
                        .caseInsensitiveCompare(
                            normalizedPrimary ?? ""
                        ) != .orderedSame else {
                    return nil
                }
                return (
                    path: normalized,
                    size: asset.sizeBytes
                )
            }
            .sorted {
                if $0.size != $1.size {
                    return $0.size < $1.size
                }
                return $0.path.localizedStandardCompare(
                    $1.path
                ) == .orderedAscending
            }

        var urls: [URL] = []
        for candidate in candidates {
            do {
                let url = try resolvedURL(
                    relativePath: candidate.path,
                    under: activeSource.rootURL
                )
                try validateRegularFile(url)
                urls.append(url)
            } catch {
                continue
            }
        }
        return urls
    }

    private func playbackAsset(
        for entry: LooseMediaCatalogEntry
    ) throws -> AudioPlaybackAsset {
        guard let source = activeSources[entry.sourceID] else {
            throw BookmarkedKaraokeLibraryError.sourceUnavailable(
                entry.sourceID
            )
        }

        let mediaURL = try resolvedURL(
            relativePath: entry.relativePath,
            under: source.rootURL
        )
        try validateRegularFile(mediaURL)

        let soundFontURL = try resolvedSoundFont(
            relativePath: entry.soundFontRelativePath,
            source: source
        )

        let fallbackSoundFonts =
            try soundFontFallbackURLs(
                sourceID: entry.sourceID,
                primaryRelativePath:
                    entry.soundFontRelativePath
            )

        return AudioPlaybackAsset(
            songID: entry.song.id,
            url: mediaURL,
            mediaKind: entry.song.mediaKind,
            soundFontURL: soundFontURL,
            fallbackSoundFontURLs:
                fallbackSoundFonts
        )
    }

    private func playbackAsset(
        for entry: IndexedContainerCatalogEntry
    ) throws -> AudioPlaybackAsset {
        guard let source = activeSources[entry.sourceID] else {
            throw BookmarkedKaraokeLibraryError.sourceUnavailable(
                entry.sourceID
            )
        }

        let blobURL = try resolvedURL(
            relativePath: entry.blobRelativePath,
            under: source.rootURL
        )
        try validateRegularFile(blobURL)
        let cacheDirectory = containerCacheRoot
            .appendingPathComponent(
                entry.sourceID.uuidString.lowercased(),
                isDirectory: true
            )

        let resolved = try ContainerPayloadResolver.materialize(
            blobURL: blobURL,
            span: entry.payloadSpan,
            destinationDirectory: cacheDirectory
        )

        let soundFontURL: URL?
        if resolved.payload.mediaKind == .midi
            || resolved.payload.mediaKind == .kar {
            soundFontURL = try resolvedSoundFont(
                relativePath: entry.soundFontRelativePath,
                source: source
            )
        } else {
            soundFontURL = nil
        }

        let fallbackSoundFonts =
            try soundFontFallbackURLs(
                sourceID: entry.sourceID,
                primaryRelativePath:
                    entry.soundFontRelativePath
            )

        return AudioPlaybackAsset(
            songID: entry.song.id,
            url: resolved.url,
            mediaKind: resolved.payload.mediaKind,
            soundFontURL: soundFontURL,
            fallbackSoundFontURLs:
                fallbackSoundFonts
        )
    }

    private func resolvedSoundFont(
        relativePath: String?,
        source: ActiveSource
    ) throws -> URL? {
        guard let relativePath else {
            return nil
        }

        let url = try resolvedURL(
            relativePath: relativePath,
            under: source.rootURL
        )
        // Availability is evaluated by the MIDI engine so fallbacks remain usable.
        return url
    }

    private func cacheLyricCues(
        songID: SongID,
        mediaURL: URL
    ) throws -> [KaraokeLyricCue] {
        let file = try standardMIDIFile(
            songID: songID,
            mediaURL: mediaURL
        )
        let timeline = MIDITimeline(file: file)
        let cues = timeline.lyricCues(in: file)
        lyricCache[songID] = cues
        return cues
    }

    private func standardMIDIFile(
        songID: SongID,
        mediaURL: URL
    ) throws -> StandardMIDIFile {
        if let cached = midiFileCache[songID] {
            return cached
        }

        let data = try Data(
            contentsOf: mediaURL,
            options: [.mappedIfSafe]
        )
        let file = try StandardMIDIParser.parse(data)
        midiFileCache[songID] = file
        return file
    }

    private func releaseActiveSources() {
        for source in activeSources.values
        where source.didStartSecurityScope {
            source.rootURL.stopAccessingSecurityScopedResource()
        }
        activeSources.removeAll(keepingCapacity: false)
        sourceRecordsByID.removeAll(
            keepingCapacity: false
        )
    }

    private func clearContainerCache() {
        try? FileManager.default.removeItem(at: containerCacheRoot)
    }

    private func resolvedURL(
        relativePath: String,
        under rootURL: URL
    ) throws -> URL {
        guard let normalized =
                LooseMediaCatalog.normalizedRelativePath(
                    relativePath
                ) else {
            throw BookmarkedKaraokeLibraryError
                .invalidRelativePath(relativePath)
        }

        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = root
            .appendingPathComponent(normalized)
            .standardizedFileURL.resolvingSymlinksInPath()

        let rootPath = root.path.hasSuffix("/")
            ? root.path
            : root.path + "/"

        guard candidate.path.hasPrefix(rootPath) else {
            throw BookmarkedKaraokeLibraryError
                .invalidRelativePath(relativePath)
        }

        return candidate
    }

    private func validateRegularFile(_ url: URL) throws {
        var freshURL = url
        freshURL.removeAllCachedResourceValues()
        let values = try freshURL.resourceValues(
            forKeys: [.isRegularFileKey]
        )
        guard values.isRegularFile == true else {
            throw BookmarkedKaraokeLibraryError
                .fileUnavailable(url.lastPathComponent)
        }
    }

}


