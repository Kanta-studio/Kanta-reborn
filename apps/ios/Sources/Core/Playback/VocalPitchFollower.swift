import Foundation

/// Debounces neighboring musical-note decisions before driving the existing
/// AVAudioUnitTimePitch. This holds no audio buffers and never touches scoring.
/// Its caller owns actor isolation and resets it when monitoring becomes unsafe.
public struct VocalPitchFollower: Sendable {
    public private(set) var targetNote: Int?
    public private(set) var appliedCents: Float = 0

    private var pendingNote: Int?
    private var pendingCount = 0
    private var missingCount = 0
    private var lastRoot: Int?
    private var lastScale: VocalPitchScale?

    public init() {}

    public mutating func reset() {
        targetNote = nil
        pendingNote = nil
        pendingCount = 0
        missingCount = 0
        lastRoot = nil
        lastScale = nil
        appliedCents = 0
    }

    /// A bounded response for one dry microphone observation. Repeated
    /// confidence failures release correction instead of latching a note.
    /// Two consecutive observations of a neighboring target are needed to
    /// switch; jumps exceeding two semitones switch immediately.
    @discardableResult
    public mutating func update(
        frequencyHz: Double?,
        confidence: Double,
        settings: VocalPitchCorrection
    ) -> Float {
        let config = settings.clamped
        guard config.enabled else {
            reset()
            return 0
        }

        // Changing key/scale never reuses a lock from the prior key.
        if lastRoot != config.root || lastScale != config.scale {
            reset()
            lastRoot = config.root
            lastScale = config.scale
        }

        guard let frequencyHz,
              let resolved = VocalPitchQuantizer.nearestNote(
                frequencyHz: frequencyHz,
                confidence: confidence,
                settings: config
              ) else {
            missingCount += 1
            if missingCount >= 2 {
                reset()
                return 0
            }
            appliedCents = VocalPitchQuantizer.smooth(
                previous: appliedCents, target: 0, speed: config.speed
            )
            return appliedCents
        }
        missingCount = 0

        let newNote = resolved.targetMidi
        if let current = targetNote, current != newNote {
            if abs(Double(current) - resolved.detectedMidi) > 2 {
                // A genuine large melodic jump should not remain tuned to
                // the previous note while awaiting a second observation.
                targetNote = newNote
                pendingNote = nil
                pendingCount = 0
            } else {
                if pendingNote == newNote {
                    pendingCount += 1
                } else {
                    pendingNote = newNote
                    pendingCount = 1
                }
                if pendingCount >= 2 {
                    targetNote = newNote
                    pendingNote = nil
                    pendingCount = 0
                }
            }
        } else {
            targetNote = newNote
            pendingNote = nil
            pendingCount = 0
        }

        let cents = (Double(targetNote ?? newNote) - resolved.detectedMidi)
            * 100 * Double(config.amount)
        let bounded = Float(min(max(cents, -200), 200))
        appliedCents = VocalPitchQuantizer.smooth(
            previous: appliedCents, target: bounded, speed: config.speed
        )
        return appliedCents
    }
}

