import AVFoundation
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
    let audioOwnership: KaraokeAudioOwnership
    let intermission: KantaIntermissionMusic
    let registry: LibrarySourceRegistry?
    let library: BookmarkedKaraokeLibrary?
    let controller: LocalKaraokeController?
    let savedSets: SavedKaraokeSetStore?
    let partySFX: KantaPartySFXEngine
    let midiPlaybackEngine:
        AVFoundationMIDIPlaybackEngine?
    let networkHost: BonjourHostAdvertiser
    let microphonePitchMonitor = MicrophonePitchMonitor()
    let diagnostics = KantaSupportDiagnostics()
    let settings: KantaUserSettings
    let cloudSync: ICloudSyncCoordinator

    @Published private(set) var startupMessage: String?

    private var didPrepare = false

    init() {
        let audioOwnership = KaraokeAudioOwnership()
        self.audioOwnership = audioOwnership
        let intermission = KantaIntermissionMusic(audioOwnership: audioOwnership)
        self.intermission = intermission
        audioOwnership.stopAuxiliaryAudio = { [weak intermission] in
            intermission?.stopForOnlinePlayback()
        }
        audioOwnership.configurePlaybackSession = {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playback || session.mode != .default {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)
        }
        let settings = KantaUserSettings()
        let sfxRoot = (FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("KANTA/PartySFX", isDirectory: true)
        self.partySFX = KantaPartySFXEngine(storageDirectory: sfxRoot)
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
            let starterStore: StarterKaraokeStore?
            let starterRoot = Bundle.main.url(forResource: "StarterKaraoke", withExtension: nil)
            do {
                guard let starterRoot else { throw StarterKaraokeStore.StoreError.invalidBundledFile }
                starterStore = try StarterKaraokeStore(originals: starterRoot,
                    managed: applicationSupport.appendingPathComponent("StarterSongs", isDirectory: true))
            } catch {
                starterStore = nil
                startupMessage = "Starter Songs could not be opened: " + error.localizedDescription
            }
            let library = BookmarkedKaraokeLibrary(registry: registry,
                starterStore: starterStore,
                starterSoundFontURL: starterRoot?.appendingPathComponent("kanta-tone.sf2"))
            let savedSets: SavedKaraokeSetStore?
            do {
                savedSets = try SavedKaraokeSetStore(
                    fileURL: applicationSupport.appendingPathComponent(
                        "saved-favorites.json"
                    )
                )
            } catch {
                // A damaged optional favorites file must not disable
                // the user's library, audio engine or LAN Host.
                savedSets = nil
                startupMessage = "Saved Favorites could not be opened: "
                    + error.localizedDescription
            }
            let midiPlaybackEngine =
                AVFoundationMIDIPlaybackEngine()
            let routedEngine = RoutedAudioPlaybackEngine(
                fileEngine: AVFoundationAudioPlaybackEngine(),
                midiEngine: midiPlaybackEngine
            )

            let controller = LocalKaraokeController(
                engine: routedEngine,
                library: library,
                partySFX: partySFX,
                audioOwnership: audioOwnership
            )

            self.registry = registry
            self.library = library
            self.savedSets = savedSets
            self.controller = controller
            self.midiPlaybackEngine =
                midiPlaybackEngine
            self.networkHost = BonjourHostAdvertiser(
                controller: controller,
                catalogSearch: { query, limit, offset in
                    await library.searchSongs(
                        matching: query,
                        limit: limit,
                        offset: offset
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
            savedSets = nil
            controller = nil
            midiPlaybackEngine = nil
            networkHost = BonjourHostAdvertiser()
            startupMessage =
                "Library services could not start: "
                + error.localizedDescription
        }

        audioOwnership.onlineEntryAllowed = { [weak settings] in
            settings?.vocalEffects.monitorEnabled != true
        }
        microphonePitchMonitor.onCaptureActivityChanged = { [weak audioOwnership] busy in
            audioOwnership?.setMicrophoneBusy(busy)
        }
        microphonePitchMonitor.onDiagnosticEvent = { [weak self] event in
            self?.recordMicrophoneSignal(event)
        }
    }

    private func recordMicrophoneSignal(_ event: MicrophoneDiagnosticSignal) {
        let code: KantaDiagnosticCode
        switch event {
        case .permissionRequested: code = .microphonePermissionRequested
        case .running: code = .microphoneRunning
        case .denied: code = .microphoneDenied
        case .failed: code = .microphoneFailed
        case .stopped: code = .microphoneStopped
        case .wiredHeadphones: code = .monitorWiredHeadphones
        case .usbAudio: code = .monitorUSBAudio
        case .lineOut: code = .monitorLineOut
        case .unsupportedOutput: code = .monitorUnsupportedOutput
        case .monitorAudible: code = .monitorAudible
        case .monitorMuted: code = .monitorMuted
        case .dspSoundpipeSelected: code = .dspSoundpipeSelected
        case .dspAppleSelected: code = .dspAppleSelected
        case .dspDisabled: code = .dspCorrectionDisabled
        }
        diagnostics.record(code)
    }

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true

        guard let library else {
            diagnostics.record(.libraryPreparationFailed)
            await cloudSync.refresh(sources: [])
            return
        }
        let report = await library.loadIfNeeded()
        diagnostics.record(
            report.issues.isEmpty
                ? .libraryPreparationSucceeded
                : .libraryPreparationFailed
        )
        #if targetEnvironment(simulator)
        await runStarterSmokeIfRequested()
        #endif

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
                "Some library items could not load. " + report.issues.map(\.message).joined(separator: " ")

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



