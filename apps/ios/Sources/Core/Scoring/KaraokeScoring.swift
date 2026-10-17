import Foundation

public struct PitchObservation:
    Equatable,
    Codable,
    Sendable
{
    public var timestampMilliseconds: Int64
    public var frequencyHz: Double
    public var confidence: Double
    public var rms: Double

    public init(
        timestampMilliseconds: Int64,
        frequencyHz: Double,
        confidence: Double,
        rms: Double
    ) {
        self.timestampMilliseconds = max(
            0,
            timestampMilliseconds
        )
        self.frequencyHz = max(0, frequencyHz)
        self.confidence = min(max(confidence, 0), 1)
        self.rms = max(0, rms)
    }

    public var midiNote: Double? {
        guard frequencyHz.isFinite, frequencyHz > 0 else { return nil }
        let note = 69 + 12 * (log2(frequencyHz) - log2(440.0))
        return note.isFinite ? note : nil
    }

    public var nearestMIDINote: Int? {
        midiNote.map { Int($0.rounded()) }
    }

    public var centsFromNearestNote: Double? {
        guard let midiNote else { return nil }
        return (midiNote - midiNote.rounded()) * 100
    }
}

public struct TargetPitchWindow:
    Equatable,
    Codable,
    Sendable
{
    public var startMilliseconds: Int64
    public var endMilliseconds: Int64
    public var midiNote: Int

    public init(
        startMilliseconds: Int64,
        endMilliseconds: Int64,
        midiNote: Int
    ) {
        let normalizedStart = max(0, startMilliseconds)
        self.startMilliseconds = normalizedStart
        self.endMilliseconds = max(
            normalizedStart,
            endMilliseconds
        )
        self.midiNote = midiNote
    }

    public var frequencyHz: Double {
        440 * pow(
            2,
            (Double(midiNote) - 69) / 12
        )
    }
}

public struct KaraokeScoreBreakdown:
    Equatable,
    Codable,
    Sendable
{
    public var overall: Double
    public var pitchAccuracy: Double
    public var timingCoverage: Double
    public var matchedObservationCount: Int
    public var targetWindowCount: Int

    public init(
        overall: Double,
        pitchAccuracy: Double,
        timingCoverage: Double,
        matchedObservationCount: Int,
        targetWindowCount: Int
    ) {
        self.overall = min(max(overall, 0), 100)
        self.pitchAccuracy = min(
            max(pitchAccuracy, 0),
            100
        )
        self.timingCoverage = min(
            max(timingCoverage, 0),
            100
        )
        self.matchedObservationCount =
            max(0, matchedObservationCount)
        self.targetWindowCount = max(0, targetWindowCount)
    }
}

public enum KaraokePitchScorer {
    public static func score(
        observations: [PitchObservation],
        targets: [TargetPitchWindow],
        latencyMilliseconds: Int64 = 0,
        minimumConfidence: Double = 0.55,
        expectedObservationIntervalMilliseconds: Int64 = 50
    ) -> KaraokeScoreBreakdown {
        guard !targets.isEmpty else {
            return KaraokeScoreBreakdown(
                overall: 0,
                pitchAccuracy: 0,
                timingCoverage: 0,
                matchedObservationCount: 0,
                targetWindowCount: 0
            )
        }

        let confidenceThreshold = min(
            max(minimumConfidence, 0),
            1
        )
        let interval = max(
            1,
            expectedObservationIntervalMilliseconds
        )

        let usable = observations.filter {
            $0.frequencyHz.isFinite && $0.frequencyHz > 0
                && $0.confidence.isFinite
                && $0.confidence >= confidenceThreshold
        }

        var pitchScores: [Double] = []
        var observedSlots = 0
        var expectedSlots = 0.0

        for target in targets {
            guard target.startMilliseconds >= 0,
                  target.endMilliseconds > target.startMilliseconds,
                  target.frequencyHz.isFinite, target.frequencyHz > 0 else { continue }
            let duration = target.endMilliseconds - target.startMilliseconds
            let expected = (duration - 1) / interval + 1
            expectedSlots += Double(expected)

            // One observation per time slot: bursts cannot impersonate sustained singing.
            // Half-open windows also prevent counting a boundary in two adjacent notes.
            var slots: [Int64: PitchObservation] = [:]
            for observation in usable {
                let (corrected, overflow) = observation.timestampMilliseconds
                    .subtractingReportingOverflow(latencyMilliseconds)
                guard !overflow, corrected >= target.startMilliseconds,
                      corrected < target.endMilliseconds else { continue }
                let slot = (corrected - target.startMilliseconds) / interval
                if slots[slot] == nil || observation.confidence > slots[slot]!.confidence {
                    slots[slot] = observation
                }
            }
            observedSlots += slots.count

            for slot in slots.keys.sorted() {
                guard let observation = slots[slot] else { continue }
                let cents = 1_200 * log2(
                    observation.frequencyHz
                        / target.frequencyHz
                )
                let accuracy = max(
                    0,
                    1 - abs(cents) / 100
                )
                pitchScores.append(accuracy)
            }
        }

        let pitchAccuracy: Double
        if pitchScores.isEmpty {
            pitchAccuracy = 0
        } else {
            pitchAccuracy =
                pitchScores.reduce(0, +)
                / Double(pitchScores.count)
                * 100
        }

        let timingCoverage =
            expectedSlots == 0
            ? 0
            : Double(observedSlots)
                / Double(expectedSlots)
                * 100

        let overall =
            pitchAccuracy * 0.85
            + timingCoverage * 0.15

        return KaraokeScoreBreakdown(
            overall: overall,
            pitchAccuracy: pitchAccuracy,
            timingCoverage: timingCoverage,
            matchedObservationCount: pitchScores.count,
            targetWindowCount: targets.count
        )
    }
}


