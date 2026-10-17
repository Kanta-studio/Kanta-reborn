import Foundation

/// Captures performances (not queue entries) in play order. A playback UUID
/// identifies each run, so pause/resume is not recorded twice, while a replay
/// of the same title with a new run ID is retained in the session.
public struct KaraokeSessionHistory: Sendable {
    public private(set) var playedSongs: [LibrarySong] = []
    private var capturedPlaybackIDs: Set<UUID> = []
    private var fallbackSongID: SongID?

    public init() {}

    public mutating func observe(_ snapshot: KaraokeSnapshot) {
        guard snapshot.transport == .playing,
              let song = snapshot.nowPlaying else { return }

        if let id = snapshot.playbackID {
            guard capturedPlaybackIDs.insert(id).inserted else { return }
        } else {
            // Older synthetic/demo players have no playback ID.
            guard fallbackSongID != song.id else { return }
            fallbackSongID = song.id
        }
        playedSongs.append(song)
    }

    @discardableResult
    public mutating func finish() -> [LibrarySong] {
        let completed = playedSongs
        playedSongs = []
        capturedPlaybackIDs.removeAll()
        fallbackSongID = nil
        return completed
    }
}

