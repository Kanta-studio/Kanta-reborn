import AVFoundationMIDIPlayback
import AVFoundationPlayback
import Foundation
import GeloKaraokeCore
import LibraryStorage
import LocalNetworkControl
import MicrophoneScoring
import SwiftUI

@MainActor
final class AppServices: ObservableObject {
    let registry: LibrarySourceRegistry?
    let library: BookmarkedKaraokeLibrary?
    let controller: LocalKaraokeController?
    let midiPlaybackEngine:
        AVFoundationMIDIPlaybackEngine?
    let networkHost: BonjourHostAdvertiser
    let microphonePitchMonitor = MicrophonePitchMonitor()
    let settings: KantaUserSettings
    let cloudSync: ICloudSyncCoordinator

    @Published private(set) var startupMessage: String?

    private var didPrepare = false

    init() {
        let settings = KantaUserSettings()
        self.settings = settings
        self.cloudSync = ICloudSyncCoordinator(
            settings: settings
        )

        do {
            let applicationSupport = try Self.applicationSupportURL()
            let registry = try LibrarySourceRegistry(
                fileURL: applicationSupport
                    .appendingPathComponent(
                        "library-sources.json"
                    )
            )
            let library = BookmarkedKaraokeLibrary(
                registry: registry
            )
            let midiPlaybackEngine =
                AVFoundationMIDIPlaybackEngine()
            let routedEngine = RoutedAudioPlaybackEngine(
                fileEngine: AVFoundationAudioPlaybackEngine(),
                midiEngine: midiPlaybackEngine
            )

            let controller = LocalKaraokeController(
                engine: routedEngine,
                library: library
            )

            self.registry = registry
            self.library = library
            self.controller = controller
            self.midiPlaybackEngine =
                midiPlaybackEngine
            self.networkHost = BonjourHostAdvertiser(
                controller: controller,
                catalogSearch: { query, limit in
                    await library.searchSongs(
                        matching: query,
                        limit: limit
                    )
                }
            )

            if let recovery = registry.recoveryNotice {
                startupMessage =
                    "The saved library list was unreadable and was "
                    + "reset safely. A backup was preserved as "
                    + recovery.backupFileName
                    + ". Re-add your folders from Files or iCloud Drive."
            }
        } catch {
            registry = nil
            library = nil
            controller = nil
            midiPlaybackEngine = nil
            networkHost = BonjourHostAdvertiser()
            startupMessage =
                "Library services could not start: "
                + error.localizedDescription
        }
    }

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true

        guard let library else {
            await cloudSync.refresh(sources: [])
            return
        }
        let report = await library.loadIfNeeded()

        Task { [weak self] in
            guard let self else { return }
            await self.prewarmFirstSoundFont()
        }

        let cloudSources =
            await registry?.all() ?? []
        await cloudSync.refresh(
            sources: cloudSources
        )

        if !report.issues.isEmpty {
            let permissionMessage =
                "Some saved library folders need permission again."

            if let startupMessage {
                self.startupMessage =
                    startupMessage + " " + permissionMessage
            } else {
                startupMessage = permissionMessage
            }
        }
    }


    func prewarmSoundFont(
        _ selection: LibrarySoundFontSelection
    ) async {
        guard let midiPlaybackEngine else {
            return
        }

        do {
            try await midiPlaybackEngine.prepareSoundFont(
                at: selection.primaryURL,
                fallbackURLs:
                    selection.fallbackURLs
            )
        } catch {
            // Prewarming is opportunistic. Playback will retry the
            // preferred/fallback chain and surface a real playback
            // error only if every candidate fails.
        }
    }

    func prewarmFirstSoundFont() async {
        guard let library else { return }

        do {
            guard let selection =
                try await library
                    .firstSoundFontSelection()
            else {
                return
            }
            await prewarmSoundFont(selection)
        } catch {
            // Library access remains usable even if prewarming fails.
        }
    }

    private static func applicationSupportURL() throws -> URL {
        let fileManager = FileManager.default
        guard let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppServicesError.applicationSupportUnavailable
        }

        let appURL = root.appendingPathComponent(
            "GeloKaraoke",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        return appURL
    }
}

enum AppServicesError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            "Application Support storage is unavailable."
        }
    }
}


