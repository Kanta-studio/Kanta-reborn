import Foundation
import Testing
@testable import GeloKaraokeCore

private func completionSong() -> LibrarySong {
    LibrarySong(id: SongID(rawValue: "song"), title: "Song", mediaKind: .kar)
}

@Test func scoringCompletionUsesExplicitEventEvenAfterDelayedPoll() {
    let song = completionSong()
    let run = UUID()
    let previous = KaraokeSnapshot(transport: .playing, nowPlaying: song,
        positionMilliseconds: 10_000, durationMilliseconds: 60_000, playbackID: run)
    let latest = KaraokeSnapshot(lastCompletion: KaraokeCompletion(playbackID: run, song: song))
    #expect(KaraokeScoreCompletionDetector.completedSong(previous: previous, latest: latest) == song)
}

@Test func scoringCompletionRejectsManualSkipEvenOneMillisecondBeforeEnd() {
    let song = completionSong()
    let previous = KaraokeSnapshot(transport: .playing, nowPlaying: song,
        positionMilliseconds: 59_999, durationMilliseconds: 60_000, playbackID: UUID())
    let latest = KaraokeSnapshot(transport: .playing, nowPlaying: song, playbackID: UUID())
    #expect(KaraokeScoreCompletionDetector.completedSong(previous: previous, latest: latest) == nil)
}

@Test func scoringCompletionDoesNotInferSeekOrPauseAsCompletion() {
    let song = completionSong()
    let previous = KaraokeSnapshot(transport: .playing, nowPlaying: song, playbackID: UUID())
    for transport in [TransportState.stopped, .paused] {
        var latest = previous
        latest.transport = transport
        latest.positionMilliseconds = 60_000
        latest.durationMilliseconds = 60_000
        #expect(KaraokeScoreCompletionDetector.completedSong(previous: previous, latest: latest) == nil)
    }
}

@Test func scoringCompletionIsConsumedOnceAndSupportsRepeatedSong() {
    let song = completionSong()
    let first = UUID()
    let second = UUID()
    let completion = KaraokeCompletion(playbackID: first, song: song)
    let previous = KaraokeSnapshot(transport: .playing, nowPlaying: song, playbackID: first)
    let latest = KaraokeSnapshot(transport: .playing, nowPlaying: song,
        playbackID: second, lastCompletion: completion)
    #expect(KaraokeScoreCompletionDetector.completedSong(previous: previous, latest: latest) == song)
    #expect(KaraokeScoreCompletionDetector.completedSong(previous: latest, latest: latest) == nil)
    var unrelated = previous
    unrelated.playbackID = UUID()
    #expect(KaraokeScoreCompletionDetector.completedSong(previous: unrelated, latest: latest) == nil)
}

@Test func snapshotDecodesOlderRemoteWithoutCompletionMetadata() throws {
    let data = Data(#"{"transport":"stopped","queue":[],"positionMilliseconds":0,"volume":1,"pitchSemitones":0,"tempoRatio":1}"#.utf8)
    let snapshot = try JSONDecoder().decode(KaraokeSnapshot.self, from: data)
    #expect(snapshot.playbackID == nil)
    #expect(snapshot.lastCompletion == nil)
}

