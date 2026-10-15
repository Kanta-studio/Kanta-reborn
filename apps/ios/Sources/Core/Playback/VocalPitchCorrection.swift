import Foundation

/// KANTA's built-in monophonic note snapping. This is an adaptive
/// time/pitch-shift effect, not a licensed Auto-Tune plugin or
/// formant-preserving studio pitch-correction engine.
public enum VocalPitchScale: String, CaseIterable, Codable, Sendable, Identifiable {
    case chromatic, major, minor, majorPentatonic, minorPentatonic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chromatic: "Chromatic"
        case .major: "Major"
        case .minor: "Minor"
        case .majorPentatonic: "Major Pentatonic"
        case .minorPentatonic: "Minor Pentatonic"
        }
    }

    public var intervals: [Int] {
        switch self {
        case .chromatic: Array(0...11)
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .majorPentatonic: [0, 2, 4, 7, 9]
        case .minorPentatonic: [0, 3, 5, 7, 10]
        }
    }
}

/// SoundpipeAudioKit is MIT licensed (with permissive transitive notices).
/// Native mode remains available for comparison and hardware fallbacks.
public enum VocalPitchBackend: String, CaseIterable, Codable, Sendable, Identifiable {
    case soundpipe, native
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .soundpipe: "Soundpipe · PitchCorrect"
        case .native: "Apple · Native"
        }
    }
}

public struct VocalPitchCorrection: Codable, Equatable, Sendable {
    /// Optional for Codable migration: legacy settings without backend
    /// resolve to Soundpipe, while disabled correction remains disabled.
    public var backend: VocalPitchBackend?
    public var selectedBackend: VocalPitchBackend { backend ?? .soundpipe }

    public var enabled: Bool
    /// 0 = C, 1 = C#, ... 11 = B.
    public var root: Int
    public var scale: VocalPitchScale
    /// Percentage of the correction: 0 = natural, 1 = hard snap.
    public var amount: Float
    /// 0 = gradual, 1 = fast/robotic response.
    public var speed: Float

    public init(
        enabled: Bool = false,
        root: Int = 0,
        scale: VocalPitchScale = .chromatic,
        amount: Float = 0.7,
        speed: Float = 0.4,
        backend: VocalPitchBackend? = .soundpipe
    ) {
        self.backend = backend
        self.enabled = enabled
        self.root = min(max(root, 0), 11)
        self.scale = scale
        self.amount = amount.isFinite ? min(max(amount, 0), 1) : 0
        self.speed = speed.isFinite ? min(max(speed, 0), 1) : 0
    }

    public var clamped: VocalPitchCorrection {
        VocalPitchCorrection(
            enabled: enabled, root: root, scale: scale,
            amount: amount, speed: speed, backend: backend
        )
    }

    public static let pitchClassNames = [
        "C", "C♯", "D", "D♯", "E", "F",
        "F♯", "G", "G♯", "A", "A♯", "B"
    ]
}

/// Pure pitch-to-target mapping. Does not modify the dry scoring signal.
/// No adjustment on silence, unreliable pitch, or disabling the effect.
public enum VocalPitchQuantizer {
    // Shared target resolution for the stateless quantizer and the hysteresis
    // follower. Kept platform-neutral; no DSP node or third-party code here.
    static func nearestNote(
        frequencyHz: Double,
        confidence: Double,
        settings: VocalPitchCorrection
    ) -> (detectedMidi: Double, targetMidi: Int)? {
        guard settings.enabled,
              frequencyHz.isFinite, frequencyHz >= 70,
              frequencyHz <= 1_000,
              confidence.isFinite, confidence >= 0.76 else {
            return nil
        }
        let midi = 69 + 12 * log2(frequencyHz / 440)
        guard midi.isFinite else { return nil }
        let config = settings.clamped
        let intervals = Set(config.scale.intervals.map {
            ($0 + config.root) % 12
        })
        let center = Int(midi.rounded())
        var nearest = center
        var distance = Double.greatestFiniteMagnitude
        for candidate in (center - 12)...(center + 12) {
            guard candidate >= 0, candidate <= 127,
                  intervals.contains((candidate % 12 + 12) % 12) else {
                continue
            }
            let delta = abs(Double(candidate) - midi)
            if delta < distance {
                distance = delta
                nearest = candidate
            }
        }
        guard distance.isFinite else { return nil }
        return (midi, nearest)
    }

    public static func correctionCents(
        frequencyHz: Double,
        confidence: Double,
        settings: VocalPitchCorrection
    ) -> Float? {
        guard let target = nearestNote(
            frequencyHz: frequencyHz,
            confidence: confidence,
            settings: settings
        ) else {
            return nil
        }
        let cents = (Double(target.targetMidi) - target.detectedMidi)
            * 100 * Double(settings.clamped.amount)
        return Float(min(max(cents, -200), 200))
    }

    /// Smooth changes between tap detections, with bounded output in cents.
    public static func smooth(
        previous: Float, target: Float, speed: Float
    ) -> Float {
        let response = speed.isFinite ? min(max(speed, 0), 1) : 0
        let prior: Float = previous.isFinite ? min(max(previous, -200), 200) : 0
        let wanted: Float = target.isFinite ? min(max(target, -200), 200) : 0
        let coefficient: Float = 0.10 + 0.85 * response
        return min(max(prior + (wanted - prior) * coefficient, -200), 200)
    }
}

