import Testing
@testable import GeloKaraokeCore

private func roomObservation(_ timestamp: Int64, frequency: Double = 440) -> PitchObservation {
    PitchObservation(timestampMilliseconds: timestamp, frequencyHz: frequency, confidence: 1, rms: 0.1)
}
private let roomTarget = TargetPitchWindow(startMilliseconds: 0, endMilliseconds: 1_000, midiNote: 69)

@Test func repeatedBurstCannotCreateSustainedCoverage() {
    let result = KaraokePitchScorer.score(observations: (0..<100).map { _ in roomObservation(10) }, targets: [roomTarget])
    #expect(result.matchedObservationCount == 1)
    #expect(result.timingCoverage == 5)
    #expect(RoomScoreReliability.reportable(result) == nil)
}

@Test func adjacentNotesDoNotDoubleCountBoundary() {
    let second = TargetPitchWindow(startMilliseconds: 1_000, endMilliseconds: 2_000, midiNote: 69)
    let result = KaraokePitchScorer.score(observations: [roomObservation(1_000)], targets: [roomTarget, second])
    #expect(result.matchedObservationCount == 1)
}

@Test func reliableRoomScoreRequiresDistinctTimeCoverage() {
    let observations = (0..<20).map { roomObservation(Int64($0 * 50)) }
    let result = KaraokePitchScorer.score(observations: observations, targets: [roomTarget])
    #expect(result.overall == 100)
    #expect(RoomScoreReliability.reportable(result) != nil)
    let sparse = KaraokePitchScorer.score(observations: observations,
        targets: [TargetPitchWindow(startMilliseconds: 0, endMilliseconds: 20_000, midiNote: 69)])
    #expect(RoomScoreReliability.reportable(sparse) == nil)
    #expect(RoomScoreReliability.reportable(nil) == nil)
}

@Test func scorerRejectsInvalidPitchAndLatencyOverflow() {
    var invalid = roomObservation(10)
    invalid.frequencyHz = .infinity
    let result = KaraokePitchScorer.score(observations: [invalid, roomObservation(10)],
        targets: [roomTarget], latencyMilliseconds: Int64.min)
    #expect(result.matchedObservationCount == 0)
}

@Test func completedRoomScoreIncludesUnheardEndOfSong() {
    let target = MIDIMelodyTarget(trackIndex: 1, channel: 0, evidence: .lyricBearingTrack,
        windows: [TargetPitchWindow(startMilliseconds: 0, endMilliseconds: 20_000, midiNote: 69)])
    var session = LiveKaraokeScoringSession(target: target)
    session.updatePlaybackAnchor(snapshot: KaraokeSnapshot(transport: .playing, positionMilliseconds: 0),
        captureTimestampMilliseconds: 1_000)
    for i in 0..<20 { _ = session.ingest(roomObservation(Int64(1_000 + i * 50))) }
    #expect(session.completedScore?.timingCoverage == 5)
    #expect(RoomScoreReliability.reportable(session.completedScore) == nil)
    session.setLatencyMilliseconds(100)
    #expect(session.observationCount == 0)
    #expect(session.completedScore == nil)
}


@Test func extremeTargetDurationAndInvalidWindowsDoNotOverflowScoring() {
    let longTarget = TargetPitchWindow(startMilliseconds: 0, endMilliseconds: Int64.max, midiNote: 69)
    let result = KaraokePitchScorer.score(observations: [roomObservation(0)],
        targets: [longTarget, longTarget], expectedObservationIntervalMilliseconds: 1)
    #expect(result.overall.isFinite)
    #expect(result.timingCoverage > 0 && result.timingCoverage < 1)
    var invalid = roomTarget
    invalid.startMilliseconds = -1
    let rejected = KaraokePitchScorer.score(observations: [roomObservation(0)], targets: [invalid])
    #expect(rejected.matchedObservationCount == 0)
}
