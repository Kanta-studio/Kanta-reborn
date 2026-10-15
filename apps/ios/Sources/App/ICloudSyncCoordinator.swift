import Foundation
import LibraryStorage
import SwiftUI

enum ICloudBackupCategory:
    String,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable
{
    case settings
    case mySet
    case songs
    case soundFonts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings:
            "Settings"
        case .mySet:
            KantaTerminology.mySet
        case .songs:
            "Songs"
        case .soundFonts:
            "SoundFonts"
        }
    }

    var subtitle: String {
        switch self {
        case .settings:
            "Small preferences such as stage visuals and selected preset."
        case .mySet:
            "Only your own imported images and videos."
        case .songs:
            "Your user-supplied karaoke song files and supported containers."
        case .soundFonts:
            "User-supplied SF2/SFZ files used by MIDI playback."
        }
    }

    var systemImage: String {
        switch self {
        case .settings:
            "gearshape"
        case .mySet:
            "photo.stack"
        case .songs:
            "music.note.list"
        case .soundFonts:
            "waveform"
        }
    }
}

enum ICloudAccountState: Equatable {
    case available
    case unavailable
    case checking

    var title: String {
        switch self {
        case .available:
            "iCloud available"
        case .unavailable:
            "iCloud unavailable"
        case .checking:
            "Checking iCloud…"
        }
    }
}

struct ICloudBackupEstimate: Equatable {
    var bytesByCategory: [ICloudBackupCategory: Int64]

    func bytes(for category: ICloudBackupCategory) -> Int64 {
        bytesByCategory[category] ?? 0
    }

    func totalBytes(
        for categories: Set<ICloudBackupCategory>
    ) -> Int64 {
        categories.reduce(0) {
            $0 + bytes(for: $1)
        }
    }
}

struct ICloudBackupResult: Equatable {
    let copiedFileCount: Int
    let copiedBytes: Int64
    let settingsSaved: Bool
}

@MainActor
final class ICloudSyncCoordinator: ObservableObject {
    @Published private(set) var accountState:
        ICloudAccountState = .checking
    @Published private(set) var estimate =
        ICloudBackupEstimate(bytesByCategory: [:])
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var lastResult: ICloudBackupResult?
    @Published private(set) var deletionMessage: String?

    private let settings: KantaUserSettings
    // Never initialize iCloud KVS during routine offline app/Host startup.
    // Access the OS service only when the owner explicitly starts iCloud
    // Save/Restore/Delete; unsigned simulators lack KVS signing entitlement.
    private var keyValueStore: NSUbiquitousKeyValueStore {
        NSUbiquitousKeyValueStore.default
    }
    private let containerIdentifier =
        "iCloud.com.gelo.karaoke"
    private let settingsKey =
        "kanta.settings.snapshot.v1"

    init(settings: KantaUserSettings) {
        self.settings = settings
    }

    func refresh(sources: [LibrarySourceRecord]) async {
        accountState =
            FileManager.default.ubiquityIdentityToken == nil
            ? .unavailable
            : .available
        estimate = Self.estimateBackup(sources: sources)
    }

    func restoreSettingsFromICloud() {
        guard accountState == .available else {
            errorMessage =
                "Sign in to iCloud in iOS Settings to restore KANTA settings."
            return
        }

        _ = keyValueStore.synchronize()

        guard let data = keyValueStore.data(
            forKey: settingsKey
        ) else {
            errorMessage =
                "No KANTA settings backup was found in this iCloud account."
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(
                KantaSettingsSnapshot.self,
                from: data
            )
            settings.apply(snapshot)
        } catch {
            errorMessage =
                "The iCloud settings backup could not be read: " +
                error.localizedDescription
        }
    }

    func backupSelected(
        _ categories: Set<ICloudBackupCategory>,
        sources: [LibrarySourceRecord]
    ) async {
        guard !isWorking else { return }
        guard !categories.isEmpty else {
            errorMessage =
                "Choose at least one category to save."
            return
        }

        guard FileManager.default.ubiquityIdentityToken != nil else {
            accountState = .unavailable
            errorMessage =
                "iCloud is not available. Sign in to iCloud in iOS Settings and try again."
            return
        }

        isWorking = true
        errorMessage = nil
        lastResult = nil
        deletionMessage = nil
        defer { isWorking = false }

        var settingsSaved = false

        if categories.contains(.settings) {
            do {
                let data = try JSONEncoder().encode(
                    settings.snapshot()
                )
                keyValueStore.set(
                    data,
                    forKey: settingsKey
                )
                settingsSaved = keyValueStore.synchronize()
            } catch {
                errorMessage =
                    "Settings could not be prepared for iCloud: " +
                    error.localizedDescription
                return
            }
        }

        let fileCategories =
            categories.subtracting([.settings])

        if fileCategories.isEmpty {
            lastResult = ICloudBackupResult(
                copiedFileCount: 0,
                copiedBytes: 0,
                settingsSaved: settingsSaved
            )
            return
        }

        let containerIdentifier = self.containerIdentifier

        do {
            let result = try await Task.detached(
                priority: .utility
            ) {
                try Self.copyFilesToICloud(
                    categories: fileCategories,
                    sources: sources,
                    containerIdentifier:
                        containerIdentifier
                )
            }.value

            lastResult = ICloudBackupResult(
                copiedFileCount: result.fileCount,
                copiedBytes: result.bytes,
                settingsSaved: settingsSaved
            )
        } catch {
            errorMessage =
                "iCloud backup failed: " +
                error.localizedDescription
        }
    }

    func deleteKantaICloudBackup() async {
        guard !isWorking else { return }

        guard FileManager.default.ubiquityIdentityToken != nil else {
            accountState = .unavailable
            errorMessage =
                "iCloud is not available. Sign in to iCloud in iOS Settings and try again."
            return
        }

        isWorking = true
        errorMessage = nil
        lastResult = nil
        deletionMessage = nil
        defer { isWorking = false }

        let containerIdentifier = self.containerIdentifier

        do {
            let removedFileBackup = try await Task.detached(
                priority: .utility
            ) {
                try Self.deleteFilesFromICloud(
                    containerIdentifier: containerIdentifier
                )
            }.value

            keyValueStore.removeObject(forKey: settingsKey)
            _ = keyValueStore.synchronize()

            if removedFileBackup {
                deletionMessage =
                    "KANTA iCloud Save data was removed and the deletion was submitted to iCloud. Other devices may take time to reflect the change."
            } else {
                deletionMessage =
                    "No KANTA iCloud file backup was found. Saved KANTA settings were cleared from iCloud."
            }
        } catch {
            errorMessage =
                "KANTA could not delete its iCloud backup: " +
                error.localizedDescription
        }
    }

    private static func estimateBackup(
        sources: [LibrarySourceRecord]
    ) -> ICloudBackupEstimate {
        var totals: [ICloudBackupCategory: Int64] = [
            .settings: 1_024
        ]

        for source in sources {
            for asset in source.lastScan?.assets ?? [] {
                guard let category = backupCategory(
                    for: asset
                ) else {
                    continue
                }
                totals[category, default: 0] +=
                    max(0, asset.sizeBytes)
            }
        }

        return ICloudBackupEstimate(
            bytesByCategory: totals
        )
    }

    nonisolated private static func backupCategory(
        for asset: DiscoveredLibraryAsset
    ) -> ICloudBackupCategory? {
        let normalized =
            asset.relativePath.lowercased()

        if normalized.hasPrefix("bgv/user/")
            || normalized.hasPrefix("bg/user/")
            || normalized.hasPrefix("bgphoto/user/") {
            return .mySet
        }

        switch asset.kind {
        case .soundFont:
            return .soundFonts

        case .midi, .kar, .mp3, .wav,
             .libraryIndex, .libraryContainer:
            return .songs

        case .backgroundVideo, .backgroundImage:
            return nil

        case .other:
            return nil
        }
    }

    nonisolated private static func copyFilesToICloud(
        categories: Set<ICloudBackupCategory>,
        sources: [LibrarySourceRecord],
        containerIdentifier: String
    ) throws -> (fileCount: Int, bytes: Int64) {
        let fileManager = FileManager.default

        guard let container = fileManager.url(
            forUbiquityContainerIdentifier:
                containerIdentifier
        ) else {
            throw ICloudSyncError.containerUnavailable
        }

        let backupRoot = backupRoot(in: container)

        try fileManager.createDirectory(
            at: backupRoot,
            withIntermediateDirectories: true
        )

        var copiedFileCount = 0
        var copiedBytes: Int64 = 0

        for source in sources {
            var stale = false
            let sourceRoot = try URL(
                resolvingBookmarkData: source.bookmarkData,
                bookmarkDataIsStale: &stale
            )

            let accessed =
                sourceRoot.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    sourceRoot.stopAccessingSecurityScopedResource()
                }
            }

            // Stable identity prevents collisions between equally named libraries.
            let safeSourceName = source.id.uuidString.lowercased()
            let sourceBackupRoot = backupRoot
                .appendingPathComponent(
                    safeSourceName,
                    isDirectory: true
                )

            for asset in source.lastScan?.assets ?? [] {
                guard let category = backupCategory(
                    for: asset
                ),
                categories.contains(category) else {
                    continue
                }

                guard let normalized =
                    LooseMediaCatalog.normalizedRelativePath(
                        asset.relativePath
                    ) else {
                    continue
                }

                let sourceURL = try VerifiedLibraryBackup.sourceURL(
                    root: sourceRoot, relativePath: normalized
                )

                let categoryRoot = sourceBackupRoot
                    .appendingPathComponent(
                        category.rawValue,
                        isDirectory: true
                    )

                let destination = categoryRoot
                    .appendingPathComponent(normalized)

                try fileManager.createDirectory(
                    at: destination
                        .deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                var coordinationError: NSError?
                var copyResult: Result<Int64, Error>?
                let coordinator = NSFileCoordinator()
                coordinator.coordinate(
                    readingItemAt: sourceURL, options: [],
                    writingItemAt: destination, options: .forReplacing,
                    error: &coordinationError
                ) { coordinatedSource, coordinatedDestination in
                    copyResult = Result {
                        try VerifiedLibraryBackup.copy(
                            source: coordinatedSource, destination: coordinatedDestination
                        )
                    }
                }
                if let coordinationError { throw coordinationError }
                guard let copyResult else { throw ICloudSyncError.copyVerificationFailed(asset.relativePath) }
                copiedBytes += try copyResult.get()
                copiedFileCount += 1
            }
        }

        return (copiedFileCount, copiedBytes)
    }

    nonisolated private static func backupRoot(
        in container: URL
    ) -> URL {
        container
            .appendingPathComponent(
                "Documents",
                isDirectory: true
            )
            .appendingPathComponent(
                "KANTA Backup",
                isDirectory: true
            )
    }

    nonisolated private static func deleteFilesFromICloud(
        containerIdentifier: String
    ) throws -> Bool {
        let fileManager = FileManager.default

        guard let container = fileManager.url(
            forUbiquityContainerIdentifier:
                containerIdentifier
        ) else {
            throw ICloudSyncError.containerUnavailable
        }

        let backupRoot = backupRoot(in: container)
        guard fileManager.fileExists(atPath: backupRoot.path) else {
            return false
        }

        var coordinationError: NSError?
        var removalError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: backupRoot,
            options: .forDeleting,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try fileManager.removeItem(at: coordinatedURL)
            } catch {
                removalError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let removalError { throw removalError }
        return true
    }
}

enum ICloudSyncError: LocalizedError {
    case containerUnavailable
    case copyVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            "KANTA could not open its iCloud Drive container. App Store iCloud entitlements may still need provisioning."
        case let .copyVerificationFailed(path):
            "The copied iCloud file did not match the original size: \(path)"
        }
    }
}


