import Foundation

/// A fixed, privacy-reviewed vocabulary. Diagnostics must never accept
/// arbitrary strings, file paths, song titles, network identifiers, user
/// names, microphone samples, pairing codes or secret material.
public enum KantaDiagnosticCode: String, Codable, CaseIterable, Sendable {
    case diagnosticsEnabled
    case appSessionStarted
    case appEnteredBackground
    case appBecameActive
    case previousForegroundSessionInterrupted
    case hostOpened
    case hostClosed
    case microphonePermissionRequested
    case microphoneRunning
    case microphoneDenied
    case microphoneFailed
    case microphoneStopped
    case monitorWiredHeadphones
    case monitorUSBAudio
    case monitorLineOut
    case monitorUnsupportedOutput
    case monitorAudible
    case monitorMuted
    case dspSoundpipeSelected
    case dspAppleSelected
    case dspCorrectionDisabled
    case scoringEnabled
    case scoringDisabled
    case libraryPreparationSucceeded
    case libraryPreparationFailed
}

public struct KantaDiagnosticEntry: Codable, Equatable, Sendable {
    public let date: Date
    public let code: KantaDiagnosticCode

    public init(date: Date, code: KantaDiagnosticCode) {
        self.date = date
        self.code = code
    }
}

/// Small bounded time-ordered timeline; event-only, no free text.
/// The app stores this privately only when users opt in.
public struct KantaDiagnosticTimeline: Codable, Equatable, Sendable {
    public static let maximumEntries = 200
    public static let retentionSeconds: TimeInterval = 7 * 24 * 60 * 60
    public private(set) var entries: [KantaDiagnosticEntry]

    public init(entries: [KantaDiagnosticEntry] = []) {
        self.entries = entries
    }

    public mutating func record(
        _ code: KantaDiagnosticCode,
        at now: Date = Date()
    ) {
        entries.append(KantaDiagnosticEntry(date: now, code: code))
        prune(at: now)
    }

    public mutating func prune(at now: Date = Date()) {
        let earliest = now.addingTimeInterval(-Self.retentionSeconds)
        // Discard invalid/future wall-clock entries (including time changes).
        entries = Array(
            entries.filter {
                $0.date >= earliest && $0.date <= now
            }.suffix(Self.maximumEntries)
        )
    }

    public mutating func clear() {
        entries.removeAll()
    }
}

