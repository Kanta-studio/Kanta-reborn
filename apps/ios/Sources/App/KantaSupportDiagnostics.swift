import AVFoundation
import Combine
import Foundation
import GeloKaraokeCore
import MicrophoneScoring
import UIKit

/// Explicitly opt-in, local-only, redacted event capture.
/// No raw messages, song metadata, network identity or audio are accepted.
/// Always called on the main actor, never on the audio render callback.
@MainActor
final class KantaSupportDiagnostics: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var count: Int
    @Published private(set) var shareURL: URL?
    @Published private(set) var statusMessage: String?

    private enum Key {
        static let enabled = "kanta.supportDiagnostics.enabled.v1"
        static let foreground = "kanta.supportDiagnostics.foreground.v1"
    }
    private let defaults: UserDefaults
    private let timelineURL: URL
    private let exportURL: URL
    private var timeline: KantaDiagnosticTimeline
    private var didBeginSession = false

    init(defaults: UserDefaults = .standard) {
        // Resolve persisted state locally before assigning stored properties
        // to satisfy Swift two-phase initialization.
        let isEnabled = defaults.bool(forKey: Key.enabled)
        let root = (FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("KANTA/SupportDiagnostics", isDirectory: true)
        let eventFile = root.appendingPathComponent("events.json")
        let exportFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("KANTA-Support-Report.json")

        var restored = KantaDiagnosticTimeline()
        if isEnabled,
           let bytes = try? Data(contentsOf: eventFile),
           let previous = try? JSONDecoder().decode(
               KantaDiagnosticTimeline.self, from: bytes
           ) {
            restored = previous
            restored.prune()
        }
        self.defaults = defaults
        self.timelineURL = eventFile
        self.exportURL = exportFile
        self.enabled = isEnabled
        self.timeline = restored
        self.count = restored.entries.count
        if !isEnabled {
            // No retained diagnostics after the user opts out.
            try? FileManager.default.removeItem(at: eventFile)
            defaults.set(false, forKey: Key.foreground)
        }
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        defaults.set(value, forKey: Key.enabled)
        statusMessage = nil
        if value {
            didBeginSession = false
            defaults.set(false, forKey: Key.foreground)
            record(.diagnosticsEnabled)
            beginSession()
        } else {
            didBeginSession = false
            clear()
        }
    }

    func record(_ code: KantaDiagnosticCode) {
        guard enabled else { return }
        timeline.record(code)
        count = timeline.entries.count
        persist()
    }

    func beginSession() {
        guard enabled, !didBeginSession else { return }
        didBeginSession = true
        if defaults.bool(forKey: Key.foreground) {
            // iOS can terminate an app without crashing; this marker
            // deliberately does NOT claim a crash occurred.
            record(.previousForegroundSessionInterrupted)
        }
        defaults.set(true, forKey: Key.foreground)
        record(.appSessionStarted)
    }

    func setForeground(_ foreground: Bool) {
        guard enabled else { return }
        let wasForeground = defaults.bool(forKey: Key.foreground)
        guard wasForeground != foreground else { return }
        defaults.set(foreground, forKey: Key.foreground)
        record(foreground ? .appBecameActive : .appEnteredBackground)
    }

    func clear() {
        timeline.clear()
        count = 0
        defaults.set(false, forKey: Key.foreground)
        shareURL = nil
        try? FileManager.default.removeItem(at: timelineURL)
        try? FileManager.default.removeItem(at: exportURL)
        statusMessage = "Local diagnostic history cleared."
    }

    func prepareSupportReport(
        microphone: MicrophonePitchMonitor,
        settings: VocalFXSettings
    ) {
        guard enabled else {
            statusMessage = "Turn on local diagnostics before preparing a report."
            return
        }
        timeline.prune()
        count = timeline.entries.count

        let status: String
        switch microphone.status {
        case .idle: status = "idle"
        case .requestingPermission: status = "requestingPermission"
        case .running: status = "running"
        case .denied: status = "denied"
        case .failed: status = "failed" // Never serialize the underlying error text.
        }
        let route = microphone.monitoringRoute.rawValue
        let backend = settings.pitchCorrection?.selectedBackend.rawValue ?? "none"
        let audioSession = AVAudioSession.sharedInstance()
        let os = UIDevice.current.systemVersion
        let appInfo = Bundle.main.infoDictionary ?? [:]
        let report = KantaSupportReport(
            createdAt: Date(),
            appVersion: appInfo["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: appInfo["CFBundleVersion"] as? String ?? "unknown",
            platform: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
            osVersion: os,
            microphoneStatus: status,
            monitorRoute: route,
            monitorAudible: microphone.isMonitorAudible,
            correctionEnabled: settings.pitchCorrection?.enabled == true,
            backend: backend,
            scale: settings.pitchCorrection?.scale.rawValue ?? "none",
            sampleRateHz: audioSession.sampleRate.isFinite
                ? Int(audioSession.sampleRate) : 0,
            ioBufferMilliseconds: audioSession.ioBufferDuration.isFinite
                ? (audioSession.ioBufferDuration * 1_000).rounded() : 0,
            events: timeline.entries
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: exportURL, options: [.atomic, .completeFileProtection])
            shareURL = exportURL
            statusMessage = "Report prepared on device. Review before sharing."
        } catch {
            shareURL = nil
            statusMessage = "Unable to prepare the local support report."
        }
    }

    private func persist() {
        do {
            let directory = timelineURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            var directoryURL = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directoryURL.setResourceValues(values)

            let encoder = JSONEncoder()
            let bytes = try encoder.encode(timeline)
            try bytes.write(
                to: timelineURL, options: [.atomic, .completeFileProtection]
            )
        } catch {
            statusMessage = "Unable to store local diagnostics."
        }
    }
}

/// Typed export schema: only reviewable values, never arbitrary error text,
/// audio, file paths, singer names, PINs, UDIDs, IPs or library metadata.
private struct KantaSupportReport: Encodable {
    let schemaVersion = 1
    let privacyNotice = "Local-only opt-in report. No audio or song/user identifiers. Sharing is user-initiated."
    let createdAt: Date
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let microphoneStatus: String
    let monitorRoute: String
    let monitorAudible: Bool
    let correctionEnabled: Bool
    let backend: String
    let scale: String
    let sampleRateHz: Int
    let ioBufferMilliseconds: Double
    let events: [KantaDiagnosticEntry]
}

