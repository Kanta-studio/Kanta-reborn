import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func sessionTracksPlayedSongsButNotReservationsOrPausedSnapshots() {
    let songA = LibrarySong(
        id: SongID(rawValue: "a"), title: "A", mediaKind: .kar
    )
    let songB = LibrarySong(
        id: SongID(rawValue: "b"), title: "B", mediaKind: .midi
    )
    let firstRun = UUID()
    var session = KaraokeSessionHistory()

    session.observe(KaraokeSnapshot(
        transport: .stopped, queue: [QueueItem(song: songA)]
    ))
    session.observe(KaraokeSnapshot(
        transport: .paused, nowPlaying: songA, playbackID: firstRun
    ))
    #expect(session.playedSongs.isEmpty)

    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: songA, playbackID: firstRun
    ))
    session.observe(KaraokeSnapshot(
        transport: .paused, nowPlaying: songA, playbackID: firstRun
    ))
    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: songA, playbackID: firstRun
    ))
    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: songB, playbackID: UUID()
    ))
    #expect(session.playedSongs.map(\.id) == [songA.id, songB.id])

    let completed = session.finish()
    #expect(completed.map(\.id) == [songA.id, songB.id])
    #expect(session.playedSongs.isEmpty)

    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: songA, playbackID: UUID()
    ))
    #expect(session.playedSongs.count == 1)
}

@Test func sessionRetainsRepeatPerformancesWithDistinctPlaybackRunIDs() {
    let song = LibrarySong(
        id: SongID(rawValue: "repeat"), title: "Repeat", mediaKind: .mp3
    )
    var session = KaraokeSessionHistory()
    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: song, playbackID: UUID()
    ))
    session.observe(KaraokeSnapshot(
        transport: .playing, nowPlaying: song, playbackID: UUID()
    ))
    let completed = session.finish()
    #expect(completed.count == 2)
}
