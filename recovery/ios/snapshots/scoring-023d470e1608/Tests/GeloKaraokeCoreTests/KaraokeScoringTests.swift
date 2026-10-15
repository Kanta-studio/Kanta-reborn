import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func pitchObservationMapsA4ToMIDINote69() {
    let observation = PitchObservation(
        timestampMilliseconds: 0,
        frequencyHz: 440,
        confidence: 1,
        rms: 0.5
    )

    #expect(observation.nearestMIDINote == 69)
    #expect(
        abs((observation.centsFromNearestNote ?? 999))
            < 0.001
    )
}

@Test func scorerAwardsPerfectPitchAndCoverage() {
    let target = TargetPitchWindow(
        startMilliseconds: 0,
        endMilliseconds: 200,
        midiNote: 69
    )
    let observations = [0, 50, 100, 150].map {
        PitchObservation(
            timestampMilliseconds: Int64($0),
            frequencyHz: 440,
            confidence: 1,
            rms: 0.2
        )
    }

    let result = KaraokePitchScorer.score(
        observations: observations,
        targets: [target],
        expectedObservationIntervalMilliseconds: 50
    )

    #expect(abs(result.pitchAccuracy - 100) < 0.001)
    #expect(abs(result.timingCoverage - 100) < 0.001)
    #expect(abs(result.overall - 100) < 0.001)
    #expect(result.matchedObservationCount == 4)
}

@Test func scorerAppliesLatencyCorrectionBeforeWindowMatching() {
    let target = TargetPitchWindow(
        startMilliseconds: 0,
        endMilliseconds: 100,
        midiNote: 69
    )
    let observation = PitchObservation(
        timestampMilliseconds: 120,
        frequencyHz: 440,
        confidence: 1,
        rms: 0.2
    )

    let withoutCorrection = KaraokePitchScorer.score(
        observations: [observation],
        targets: [target],
        latencyMilliseconds: 0
    )
    let corrected = KaraokePitchScorer.score(
        observations: [observation],
        targets: [target],
        latencyMilliseconds: 21
    )

    #expect(withoutCorrection.matchedObservationCount == 0)
    #expect(corrected.matchedObservationCount == 1)
    #expect(corrected.pitchAccuracy == 100)
}

@Test func scorerIgnoresLowConfidencePitchObservations() {
    let target = TargetPitchWindow(
        startMilliseconds: 0,
        endMilliseconds: 100,
        midiNote: 69
    )
    let observation = PitchObservation(
        timestampMilliseconds: 50,
        frequencyHz: 440,
        confidence: 0.2,
        rms: 0.1
    )

    let result = KaraokePitchScorer.score(
        observations: [observation],
        targets: [target]
    )

    #expect(result.matchedObservationCount == 0)
    #expect(result.pitchAccuracy == 0)
}


@Test func playbackClockAnchorAdvancesAtKaraokeTempo() {
    let anchor = KaraokePlaybackClockAnchor(
        captureTimestampMilliseconds: 10_000,
        playbackPositionMilliseconds: 2_000,
        transport: .playing,
        tempoRatio: 1.5,
        durationMilliseconds: 10_000
    )

    #expect(
        anchor.playbackPosition(
            atCaptureTimestampMilliseconds: 10_200
        ) == 2_300
    )
}

@Test func liveScoringSessionAlignsMonotonicMicTime() {
    let target = MIDIMelodyTarget(
        trackIndex: 1,
        channel: 0,
        evidence: .lyricBearingTrack,
        windows: [
            TargetPitchWindow(
                startMilliseconds: 1_040,
                endMilliseconds: 1_100,
                midiNote: 69
            )
        ]
    )
    var session = LiveKaraokeScoringSession(
        target: target
    )

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .playing,
            positionMilliseconds: 1_000
        ),
        captureTimestampMilliseconds: 10_000
    )

    let aligned = session.ingest(
        PitchObservation(
            timestampMilliseconds: 10_050,
            frequencyHz: 440,
            confidence: 1,
            rms: 0.2
        )
    )

    #expect(aligned?.timestampMilliseconds == 1_050)
    #expect(session.score?.pitchAccuracy == 100)
}

@Test func liveScoringSessionIgnoresPausedInput() {
    let target = MIDIMelodyTarget(
        trackIndex: 1,
        channel: 0,
        evidence: .lyricBearingTrack,
        windows: [
            TargetPitchWindow(
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                midiNote: 69
            )
        ]
    )
    var session = LiveKaraokeScoringSession(
        target: target
    )

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .paused,
            positionMilliseconds: 500
        ),
        captureTimestampMilliseconds: 5_000
    )

    let aligned = session.ingest(
        PitchObservation(
            timestampMilliseconds: 5_050,
            frequencyHz: 440,
            confidence: 1,
            rms: 0.2
        )
    )

    #expect(aligned == nil)
    #expect(session.observationCount == 0)
    #expect(session.score == nil)
}

@Test func liveScoringSessionResetsAfterSeekDiscontinuity() {
    let target = MIDIMelodyTarget(
        trackIndex: 1,
        channel: 0,
        evidence: .lyricBearingTrack,
        windows: [
            TargetPitchWindow(
                startMilliseconds: 0,
                endMilliseconds: 10_000,
                midiNote: 69
            )
        ]
    )
    var session = LiveKaraokeScoringSession(
        target: target
    )

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .playing,
            positionMilliseconds: 0
        ),
        captureTimestampMilliseconds: 1_000
    )
    _ = session.ingest(
        PitchObservation(
            timestampMilliseconds: 1_100,
            frequencyHz: 440,
            confidence: 1,
            rms: 0.2
        )
    )
    #expect(session.observationCount == 1)

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .playing,
            positionMilliseconds: 5_000
        ),
        captureTimestampMilliseconds: 1_200
    )

    #expect(session.observationCount == 0)
    #expect(session.score == nil)
}

@Test func liveScoringSessionResetsWhenPitchTranspositionChanges() {
    let target = MIDIMelodyTarget(
        trackIndex: 1,
        channel: 0,
        evidence: .lyricBearingTrack,
        windows: [
            TargetPitchWindow(
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                midiNote: 69
            )
        ]
    )
    var session = LiveKaraokeScoringSession(
        target: target
    )

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .playing,
            positionMilliseconds: 0,
            pitchSemitones: 0
        ),
        captureTimestampMilliseconds: 1_000
    )
    _ = session.ingest(
        PitchObservation(
            timestampMilliseconds: 1_100,
            frequencyHz: 440,
            confidence: 1,
            rms: 0.2
        )
    )

    session.updatePlaybackAnchor(
        snapshot: KaraokeSnapshot(
            transport: .playing,
            positionMilliseconds: 100,
            pitchSemitones: 2
        ),
        captureTimestampMilliseconds: 1_100
    )

    #expect(session.observationCount == 0)
    #expect(session.pitchSemitones == 2)
}

@Test func pitchObservationRejectsNonfiniteFrequencyWithoutTrapping() {
    var observation = PitchObservation(timestampMilliseconds: 0, frequencyHz: 440, confidence: 1, rms: 1)
    observation.frequencyHz = .infinity
    #expect(observation.nearestMIDINote == nil)
    observation.frequencyHz = .nan
    #expect(observation.nearestMIDINote == nil)
    observation.frequencyHz = .leastNonzeroMagnitude
    #expect(observation.nearestMIDINote != nil)
}

