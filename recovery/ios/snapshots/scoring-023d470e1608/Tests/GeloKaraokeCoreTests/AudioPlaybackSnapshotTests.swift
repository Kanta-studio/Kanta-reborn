import Testing
@testable import GeloKaraokeCore

@Test func audioPlaybackSnapshotClampsControlValues() {
    let snapshot = AudioPlaybackSnapshot(
        positionMilliseconds: -1,
        durationMilliseconds: -10,
        volume: 5,
        pitchSemitones: 20,
        tempoRatio: 0.1
    )

    #expect(snapshot.positionMilliseconds == 0)
    #expect(snapshot.durationMilliseconds == 0)
    #expect(snapshot.volume == 1)
    #expect(snapshot.pitchSemitones == 12)
    #expect(snapshot.tempoRatio == 0.5)
}

