import Foundation

public struct KaraokePlaybackClockAnchor: Equatable, Sendable {
    public var captureTimestampMilliseconds: Int64
    public var playbackPositionMilliseconds: Int64
    public var transport: TransportState
    public var tempoRatio: Double
    public var durationMilliseconds: Int64?

    public init(
        captureTimestampMilliseconds: Int64,
        playbackPositionMilliseconds: Int64,
        transport: TransportState,
        tempoRatio: Double,
        durationMilliseconds: Int64?
    ) {
        self.captureTimestampMilliseconds = max(
            0,
            captureTimestampMilliseconds
        )
        self.playbackPositionMilliseconds = max(
            0,
            playbackPositionMilliseconds
        )
        self.transport = transport
        self.tempoRatio = min(max(tempoRatio, 0.5), 2.0)
        self.durationMilliseconds = durationMilliseconds.map {
            max(0, $0)
        }
    }

    public func playbackPosition(
        atCaptureTimestampMilliseconds timestamp: Int64
    ) -> Int64 {
        guard transport == .playing else {
            return playbackPositionMilliseconds
        }

        let elapsed = max(
            0,
            timestamp - captureTimestampMilliseconds
        )
        let timeline = PlaybackTimeline(
            anchorMilliseconds: playbackPositionMilliseconds,
            durationMilliseconds: durationMilliseconds,
            rate: tempoRatio
        )
        return timeline.position(
            afterElapsedMilliseconds: elapsed
        )
    }
}

public struct LiveKaraokeScoringSession: Sendable {
    public let target: MIDIMelodyTarget
    public private(set) var latencyMilliseconds: Int64
    public private(set) var pitchSemitones: Int
    public private(set) var observationCount: Int = 0

    private let maximumObservationCount: Int
    private let discontinuityToleranceMilliseconds: Int64
    private var anchor: KaraokePlaybackClockAnchor?
    private var alignedObservations: [PitchObservation] = []
    private var latestPlaybackPositionMilliseconds: Int64 = 0

    public init(
        target: MIDIMelodyTarget,
        latencyMilliseconds: Int64 = 0,
        pitchSemitones: Int = 0,
        maximumObservationCount: Int = 30_000,
        discontinuityToleranceMilliseconds: Int64 = 750
    ) {
        self.target = target
        self.latencyMilliseconds = min(
            max(latencyMilliseconds, -500),
            1_500
        )
        self.pitchSemitones = min(
            max(pitchSemitones, -12),
            12
        )
        self.maximumObservationCount = max(
            100,
            maximumObservationCount
        )
        self.discontinuityToleranceMilliseconds = max(
            100,
            discontinuityToleranceMilliseconds
        )
    }

    public mutating func setLatencyMilliseconds(
        _ value: Int64
    ) {
        let clamped = min(max(value, -500), 1_500)
        if clamped != latencyMilliseconds { resetObservations() }
        latencyMilliseconds = clamped
    }

    public mutating func updatePlaybackAnchor(
        snapshot: KaraokeSnapshot,
        captureTimestampMilliseconds: Int64
    ) {
        let timestamp = max(
            0,
            captureTimestampMilliseconds
        )

        if let anchor {
            let expected = anchor.playbackPosition(
                atCaptureTimestampMilliseconds: timestamp
            )
            let drift = abs(
                expected - snapshot.positionMilliseconds
            )

            if drift > discontinuityToleranceMilliseconds {
                resetObservations()
            }
        }

        if snapshot.pitchSemitones != pitchSemitones {
            pitchSemitones = snapshot.pitchSemitones
            resetObservations()
        }

        self.anchor = KaraokePlaybackClockAnchor(
            captureTimestampMilliseconds: timestamp,
            playbackPositionMilliseconds:
                snapshot.positionMilliseconds,
            transport: snapshot.transport,
            tempoRatio: snapshot.tempoRatio,
            durationMilliseconds: snapshot.durationMilliseconds
        )
        latestPlaybackPositionMilliseconds =
            snapshot.positionMilliseconds
    }

    @discardableResult
    public mutating func ingest(
        _ observation: PitchObservation
    ) -> PitchObservation? {
        guard let anchor,
              anchor.transport == .playing else {
            return nil
        }

        let playbackPosition = anchor.playbackPosition(
            atCaptureTimestampMilliseconds:
                observation.timestampMilliseconds
        )

        latestPlaybackPositionMilliseconds = max(
            latestPlaybackPositionMilliseconds,
            playbackPosition
        )

        let aligned = PitchObservation(
            timestampMilliseconds: playbackPosition,
            frequencyHz: observation.frequencyHz,
            confidence: observation.confidence,
            rms: observation.rms
        )

        alignedObservations.append(aligned)
        if alignedObservations.count > maximumObservationCount {
            alignedObservations.removeFirst(
                alignedObservations.count
                    - maximumObservationCount
            )
        }
        observationCount = alignedObservations.count
        return aligned
    }

    public mutating func resetObservations() {
        alignedObservations.removeAll(
            keepingCapacity: true
        )
        observationCount = 0
    }

    public var score: KaraokeScoreBreakdown? { makeScore(completed: false) }

    public var completedScore: KaraokeScoreBreakdown? { makeScore(completed: true) }

    private func makeScore(completed: Bool) -> KaraokeScoreBreakdown? {
        guard !alignedObservations.isEmpty else {
            return nil
        }

        let position = completed ? Int64.max : latestPlaybackPositionMilliseconds
        let elapsedTargets = target.windows.compactMap {
            window -> TargetPitchWindow? in
            guard window.startMilliseconds
                    <= position else {
                return nil
            }

            let end = min(
                window.endMilliseconds,
                position
            )
            guard end > window.startMilliseconds else {
                return nil
            }

            return TargetPitchWindow(
                startMilliseconds: window.startMilliseconds,
                endMilliseconds: end,
                midiNote: min(
                    127,
                    max(
                        0,
                        window.midiNote + pitchSemitones
                    )
                )
            )
        }

        guard !elapsedTargets.isEmpty else {
            return nil
        }

        return KaraokePitchScorer.score(
            observations: alignedObservations,
            targets: elapsedTargets,
            latencyMilliseconds: latencyMilliseconds
        )
    }
}

