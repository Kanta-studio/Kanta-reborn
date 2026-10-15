import Combine
import Foundation
import GeloKaraokeCore
import LibraryStorage

struct SoundFontImportSummary: Identifiable {
    struct Item: Identifiable {
        let id = UUID()
        let fileName: String
        let imported: Bool
        let detail: String
    }

    let id = UUID()
    let items: [Item]

    var importedCount: Int {
        items.count { $0.imported }
    }

    var skippedCount: Int {
        items.count { !$0.imported }
    }
}

struct BackgroundImportSummary: Identifiable {
    struct Item: Identifiable {
        let id = UUID()
        let fileName: String
        let imported: Bool
        let detail: String
    }

    let id = UUID()
    let items: [Item]

    var importedCount: Int {
        items.count { $0.imported }
    }

    var skippedCount: Int {
        items.count { !$0.imported }
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var sources: [LibrarySourceRecord] = []
    @Published private(set) var songCounts: [UUID: LibraryCatalogSummary] = [:]
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var importSummary: BackgroundImportSummary?
    @Published var soundFontImportSummary:
        SoundFontImportSummary?

    @Published private(set) var availableStarters: Set<String> = []
    @Published private(set) var starterFeedback: String?
    private let controller: LocalKaraokeController?

    private let scanner = DirectoryLibraryScanner()
    private let compatibilityInspector =
        BackgroundMediaCompatibilityInspector()
    private let registry: LibrarySourceRegistry?
    private let library: BookmarkedKaraokeLibrary?
    private let prewarmSoundFont:
        ((LibrarySoundFontSelection) async -> Void)?

    init(
        registry: LibrarySourceRegistry?,
        library: BookmarkedKaraokeLibrary?,
        controller: LocalKaraokeController? = nil,
        prewarmSoundFont:
            ((LibrarySoundFontSelection) async -> Void)? = nil
    ) {
        self.controller = controller
        self.registry = registry
        self.library = library
        self.prewarmSoundFont = prewarmSoundFont

        if registry == nil {
            errorMessage = "Library services are unavailable."
        }
    }

    func load() async {
        guard let registry else { return }
        sources = await registry.all()
        if let library {
            let report = await library.loadIfNeeded()
            availableStarters = await library.starterSongAvailability()
            if let issue = report.issues.first { errorMessage = issue.message }
            songCounts = await library.sourceSongCounts()
        } else {
            songCounts = [:]
        }
    }

    func changeStarter(_ identifier: String?, restore: Bool) async {
        guard !isWorking, let library else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.changeStarterSong(identifier, restore: restore)
            starterFeedback = identifier.map {
                StarterKaraokeStore.song($0).title + (restore ? " restored." : " removed. Restore it here anytime.")
            } ?? "All starter songs restored."
        } catch { errorMessage = error.localizedDescription }
        availableStarters = await library.starterSongAvailability()
    }

    func playStarter(_ identifier: String, queueOnly: Bool) async {
        guard !isWorking, let controller else { return }
        isWorking = true
        defer { isWorking = false }
        let song = StarterKaraokeStore.song(identifier)
        do {
            if queueOnly { try await controller.send(.enqueue(songID: song.id)) }
            else { try await controller.playNow(songID: song.id) }
            starterFeedback = song.title + (queueOnly ? " added to Up Next." : " is playing. Open Host for lyrics and controls.")
        } catch { errorMessage = error.localizedDescription }
    }

    func importFolder(_ url: URL) async {
        guard let registry else { return }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let scan = try await Self.coordinatedScan(
                url: url,
                scanner: scanner
            )
            let record = LibrarySourceRecord(
                displayName: url.lastPathComponent,
                bookmarkData: bookmark,
                lastScan: scan
            )
            try await registry.upsert(record)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            await prewarmPreferredSoundFont(
                forSourceID: record.id
            )
            sources = await registry.all()
        } catch {
            errorMessage =
                "Import failed: " + error.localizedDescription
        }
    }

    func importBackgroundFiles(
        _ urls: [URL],
        to source: LibrarySourceRecord
    ) async {
        guard let registry else { return }
        guard !urls.isEmpty else { return }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            var stale = false
            let root = try URL(
                resolvingBookmarkData: source.bookmarkData,
                bookmarkDataIsStale: &stale
            )
            let rootAccessed =
                root.startAccessingSecurityScopedResource()
            defer {
                if rootAccessed {
                    root.stopAccessingSecurityScopedResource()
                }
            }

            var items: [BackgroundImportSummary.Item] = []

            for inputURL in urls {
                let inputAccessed =
                    inputURL.startAccessingSecurityScopedResource()
                defer {
                    if inputAccessed {
                        inputURL.stopAccessingSecurityScopedResource()
                    }
                }

                let report = await compatibilityInspector.inspect(
                    inputURL
                )

                guard report.isCompatible,
                      let kind = report.kind else {
                    items.append(
                        BackgroundImportSummary.Item(
                            fileName: inputURL.lastPathComponent,
                            imported: false,
                            detail: report.detail
                        )
                    )
                    continue
                }

                let folderComponents: [String]
                switch kind {
                case .video:
                    folderComponents = ["BGV", "USER"]
                case .image:
                    folderComponents = ["BG", "USER"]
                }

                let destinationDirectory =
                    try VerifiedLibraryBackup.sourceURL(
                        root: root, relativePath: folderComponents.joined(separator: "/")
                    )

                try FileManager.default.createDirectory(
                    at: destinationDirectory,
                    withIntermediateDirectories: true
                )

                let destination = Self.uniqueDestination(
                    for: inputURL.lastPathComponent,
                    in: destinationDirectory
                )

                try await Self.coordinatedCopy(source: inputURL, destination: destination)

                let sourceSize = try Self.fileSize(inputURL)
                let destinationSize = try Self.fileSize(destination)
                guard sourceSize == destinationSize else {
                    try? FileManager.default.removeItem(
                        at: destination
                    )
                    items.append(
                        BackgroundImportSummary.Item(
                            fileName: inputURL.lastPathComponent,
                            imported: false,
                            detail:
                                "Copy verification failed. The destination " +
                                "was removed and the original was unchanged."
                        )
                    )
                    continue
                }

                items.append(
                    BackgroundImportSummary.Item(
                        fileName: destination.lastPathComponent,
                        imported: true,
                        detail:
                            report.detail + " Added to " + KantaTerminology.mySet + "."
                    )
                )
            }

            var updated = source
            updated.displayName = root.lastPathComponent
            updated.lastScan = try await Self.coordinatedScan(
                url: root,
                scanner: scanner
            )

            if stale {
                updated.bookmarkData = try root.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }

            try await registry.upsert(updated)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            sources = await registry.all()
            importSummary = BackgroundImportSummary(items: items)
        } catch {
            errorMessage =
                "Background import failed: " +
                error.localizedDescription
        }
    }


    func importSoundFonts(
        _ urls: [URL],
        to source: LibrarySourceRecord
    ) async {
        guard let registry else { return }
        guard !urls.isEmpty else { return }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            var stale = false
            let root = try URL(
                resolvingBookmarkData: source.bookmarkData,
                bookmarkDataIsStale: &stale
            )
            let rootAccessed =
                root.startAccessingSecurityScopedResource()
            defer {
                if rootAccessed {
                    root.stopAccessingSecurityScopedResource()
                }
            }

            let destinationDirectory = try VerifiedLibraryBackup.sourceURL(
                root: root, relativePath: "SoundFonts/USER"
            )

            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )

            var items: [SoundFontImportSummary.Item] = []
            var firstImportedRelativePath: String?

            for inputURL in urls {
                let inputAccessed =
                    inputURL.startAccessingSecurityScopedResource()

                defer {
                    if inputAccessed {
                        inputURL.stopAccessingSecurityScopedResource()
                    }
                }

                guard inputURL.pathExtension
                    .caseInsensitiveCompare("sf2")
                    == .orderedSame,
                      DirectoryLibraryScanner.classify(inputURL)
                        == .soundFont else {
                    items.append(
                        SoundFontImportSummary.Item(
                            fileName: inputURL.lastPathComponent,
                            imported: false,
                            detail:
                                "Unsupported or invalid SF2 file. " +
                                "KANTA accepts any filename when the " +
                                "file has a valid SoundFont structure."
                        )
                    )
                    continue
                }

                let destination = Self.uniqueDestination(
                    for: inputURL.lastPathComponent,
                    in: destinationDirectory
                )

                try await Self.coordinatedCopy(source: inputURL, destination: destination)

                let sourceSize = try Self.fileSize(inputURL)
                let destinationSize =
                    try Self.fileSize(destination)

                guard sourceSize > 0,
                      sourceSize == destinationSize else {
                    try? FileManager.default.removeItem(
                        at: destination
                    )
                    items.append(
                        SoundFontImportSummary.Item(
                            fileName: inputURL.lastPathComponent,
                            imported: false,
                            detail:
                                "Copy verification failed. The copied " +
                                "file was removed and the original " +
                                "was left unchanged."
                        )
                    )
                    continue
                }

                let relativePath =
                    "SoundFonts/USER/" +
                    destination.lastPathComponent

                if firstImportedRelativePath == nil {
                    firstImportedRelativePath = relativePath
                }

                items.append(
                    SoundFontImportSummary.Item(
                        fileName: destination.lastPathComponent,
                        imported: true,
                        detail:
                            "Imported as BYOL at original quality (" +
                            ByteCountFormatter.string(
                                fromByteCount: destinationSize,
                                countStyle: .file
                            ) +
                            ")."
                    )
                )
            }

            var updated = source
            updated.displayName = root.lastPathComponent
            updated.lastScan = try await Self.coordinatedScan(
                url: root,
                scanner: scanner
            )

            if updated.preferredSoundFontRelativePath == nil,
               let firstImportedRelativePath {
                updated.preferredSoundFontRelativePath =
                    firstImportedRelativePath
            }

            if stale {
                updated.bookmarkData = try root.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }

            try await registry.upsert(updated)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            await prewarmPreferredSoundFont(
                forSourceID: updated.id
            )
            sources = await registry.all()
            soundFontImportSummary =
                SoundFontImportSummary(items: items)
        } catch {
            errorMessage =
                "SoundFont import failed: " +
                error.localizedDescription
        }
    }

    func setPreferredSoundFont(
        _ relativePath: String?,
        for source: LibrarySourceRecord
    ) async {
        guard let registry, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            if let relativePath {
                guard source.lastScan?.assets.contains(
                    where: { asset in
                        asset.kind == .soundFont
                        && asset.relativePath
                            .caseInsensitiveCompare(
                                relativePath
                            ) == .orderedSame
                        && asset.relativePath
                            .lowercased()
                            .hasSuffix(".sf2")
                    }
                ) == true else {
                    errorMessage =
                        "The selected SoundFont is no longer " +
                        "available in this library."
                    return
                }
            }

            var updated = source
            updated.preferredSoundFontRelativePath =
                relativePath
            try await registry.upsert(updated)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            await prewarmPreferredSoundFont(
                forSourceID: updated.id
            )
            sources = await registry.all()
        } catch {
            errorMessage =
                "Could not update the preferred SoundFont: " +
                error.localizedDescription
        }
    }

    func rescan(_ source: LibrarySourceRecord) async {
        guard let registry else { return }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: source.bookmarkData,
                bookmarkDataIsStale: &stale
            )
            let accessed =
                url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let scan = try await Self.coordinatedScan(
                url: url,
                scanner: scanner
            )
            var updated = source
            updated.displayName = url.lastPathComponent
            updated.lastScan = scan

            if stale {
                updated.bookmarkData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }

            try await registry.upsert(updated)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            await prewarmPreferredSoundFont(
                forSourceID: updated.id
            )
            sources = await registry.all()
        } catch {
            errorMessage =
                "Rescan failed: " + error.localizedDescription
        }
    }

    func remove(_ source: LibrarySourceRecord) async {
        guard let registry, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await registry.remove(id: source.id)
            if let library {
                _ = await library.reload()
                songCounts = await library.sourceSongCounts()
            }
            sources = await registry.all()
        } catch {
            errorMessage =
                "Could not remove the library source: " +
                error.localizedDescription
        }
    }


    private func prewarmPreferredSoundFont(
        forSourceID sourceID: UUID
    ) async {
        guard let library,
              let prewarmSoundFont else {
            return
        }

        do {
            guard let selection =
                try await library.soundFontSelection(
                    forSourceID: sourceID
                )
            else {
                return
            }

            await prewarmSoundFont(selection)
        } catch {
            // Import/rescan remains successful. Playback can retry
            // SoundFont loading later without blocking this UI flow.
        }
    }

    private static func uniqueDestination(
        for fileName: String,
        in directory: URL
    ) -> URL {
        let fileManager = FileManager.default
        let original = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: original.path) else {
            return original
        }

        let url = URL(fileURLWithPath: fileName)
        let stem = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension

        var index = 2
        while true {
            var candidateName = "\(stem) \(index)"
            if !pathExtension.isEmpty {
                candidateName += ".\(pathExtension)"
            }

            let candidate = directory.appendingPathComponent(
                candidateName
            )
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private static func fileSize(
        _ url: URL
    ) throws -> Int64 {
        var freshURL = url
        freshURL.removeAllCachedResourceValues()
        let values = try freshURL.resourceValues(
            forKeys: [.fileSizeKey]
        )
        return Int64(values.fileSize ?? 0)
    }

    private nonisolated static func coordinatedCopy(source: URL, destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            var coordinationError: NSError?
            var result: Result<Int64, Error>?
            NSFileCoordinator().coordinate(
                readingItemAt: source, options: [],
                writingItemAt: destination, options: [],
                error: &coordinationError
            ) { sourceURL, destinationURL in
                result = Result {
                    try VerifiedLibraryBackup.copy(source: sourceURL, destination: destinationURL)
                }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw LibraryViewModelError.coordinationProducedNoResult }
            _ = try result.get()
        }.value
    }

    private nonisolated static func coordinatedScan(
        url: URL,
        scanner: DirectoryLibraryScanner
    ) async throws -> LibraryScanResult {
        try await Task.detached(priority: .utility) {
            try scanCoordinatedFolder(url: url, scanner: scanner)
        }.value
    }

    private nonisolated static func scanCoordinatedFolder(
        url: URL,
        scanner: DirectoryLibraryScanner
    ) throws -> LibraryScanResult {
        var coordinationError: NSError?
        var scanResult: Result<LibraryScanResult, Error>?

        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            scanResult = Result {
                try scanner.scan(root: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        guard let scanResult else {
            throw LibraryViewModelError
                .coordinationProducedNoResult
        }

        return try scanResult.get()
    }
}

enum LibraryViewModelError: LocalizedError {
    case coordinationProducedNoResult

    var errorDescription: String? {
        switch self {
        case .coordinationProducedNoResult:
            "The selected folder could not be coordinated for reading."
        }
    }
}



