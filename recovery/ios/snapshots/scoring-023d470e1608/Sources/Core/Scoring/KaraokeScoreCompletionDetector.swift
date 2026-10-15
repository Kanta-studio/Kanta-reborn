import Foundation

public enum KaraokeScoreCompletionDetector {
    public static func completedSong(
        previous: KaraokeSnapshot,
        latest: KaraokeSnapshot
    ) -> LibrarySong? {
        guard let completion = latest.lastCompletion,
              completion.playbackID != previous.lastCompletion?.playbackID,
              completion.playbackID == previous.playbackID,
              completion.song.id == previous.nowPlaying?.id else {
            return nil
        }
        return completion.song
    }
}

