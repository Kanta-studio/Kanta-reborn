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

public enum BookmarkedKaraokeLibraryError:
    Error,
    Equatable,
    Sendable
{
    case songNotFound(SongID)
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
    private var orderedSongs: [LibrarySong] = []
    private var midiFileCache: [SongID: StandardMIDIFile] = [:]
    private var lyricCache: [SongID: [KaraokeLyricCue]] = [:]
    private var scoringTargetCache:
        [SongID: MIDIMelodyTargetExtraction] = [:]

    public init(registry: LibrarySourceRegistry) {
        self.registry = registry
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
        var issues: [LibraryLoadIssue] = []
        var newLooseEntries: [LooseMediaCatalogEntry] = []
        var newContainerEntries: [IndexedContainerCatalogEntry] = []

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

                if let files = IndexedContainerCatalog.sourceFiles(
                    for: updatedSource
                ) {
                    do {
                        let indexURL = try resolvedURL(
                            relativePath: files.indexRelativePath,
                            under: rootURL
                        )
                        let blobURL = try resolvedURL(
                            relativePath: files.blobRelativePath,
                            under: rootURL
                        )
                        try validateRegularFile(indexURL)
                        try validateRegularFile(blobURL)

                        let indexData = try Data(
                            contentsOf: indexURL,
                            options: [.mappedIfSafe]
                        )
                        newContainerEntries.append(
                            contentsOf: try IndexedContainerCatalog.entries(
                                for: updatedSource,
                                indexData: indexData,
                                containerURL: blobURL
                            )
                        )
                    } catch {
                        issues.append(
                            LibraryLoadIssue(
                                sourceID: source.id,
                                sourceName: source.displayName,
                                message:
                                    "Compatible indexed library unavailable: " +
                                    error.localizedDescription
                            )
                        )
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

        orderedSongs = (
            looseEntriesByID.values.map(\.song)
            + containerEntriesByID.values.map(\.song)
        )
        .sorted {
            let order = $0.title.localizedStandardCompare($1.title)
            if order != .orderedSame {
                return order == .orderedAscending
            }
            return $0.id.rawValue < $1.id.rawValue
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

    public func searchSongs(
        matching query: String,
        limit: Int = 200
    ) -> [LibrarySong] {
        let boundedLimit = min(max(limit, 1), 500)
        let normalized = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let matches: [LibrarySong]
        if normalized.isEmpty {
            matches = orderedSongs
        } else {
            matches = orderedSongs.filter { song in
                song.title.localizedCaseInsensitiveContains(
                    normalized
                )
                || (
                    song.artist?
                        .localizedCaseInsensitiveContains(normalized)
                    ?? false
                )
                || (
                    song.code?
                        .localizedCaseInsensitiveContains(normalized)
                    ?? false
                )
            }
        }

        return Array(matches.prefix(boundedLimit))
    }

    public func song(
        id: SongID
    ) async throws -> LibrarySong? {
        looseEntriesByID[id]?.song
            ?? containerEntriesByID[id]?.song
    }

    public func playbackAsset(
        for songID: SongID
    ) async throws -> AudioPlaybackAsset {
        if let entry = looseEntriesByID[songID] {
            return try playbackAsset(for: entry)
        }

        if let entry = containerEntriesByID[songID] {
            return try playbackAsset(for: entry)
        }

        throw BookmarkedKaraokeLibraryError.songNotFound(songID)
    }

    public func backgroundAsset(
        for songID: SongID
    ) async throws -> KaraokeBackgroundAsset? {
        guard let entry = looseEntriesByID[songID] else {
            if containerEntriesByID[songID] != nil {
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


