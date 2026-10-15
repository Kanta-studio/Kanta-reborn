#if targetEnvironment(simulator)
import Foundation
import GeloKaraokeCore
import LibraryStorage

/// Explicit CI-only simulator acceptance. Never compiled into a device build.
/// Uses the actual composition root, catalog, controller, sampler and persistence.
extension AppServices {
    func runStarterSmokeIfRequested() async {
        guard let phase = ProcessInfo.processInfo.environment["KANTA_STARTER_SMOKE"] else { return }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("starter-smoke-\(phase).json")
        var evidence: [String: Any] = ["phase": phase, "passed": false]
        do {
            guard let library, let controller else { throw SmokeError.failed("services unavailable") }
            func check(_ condition: Bool, _ message: String) throws {
                if !condition { throw SmokeError.failed(message) }
            }
            let initial = await library.searchSongs(matching: "")
            if phase == "restart" {
                try check(initial.count == 2, "removal did not persist across process restart")
                let removed = try await library.song(id: StarterKaraokeStore.song("morning-light").id)
                try check(removed == nil, "removed starter reappeared")
                try await library.changeStarterSong(nil, restore: true)
                try await library.changeStarterSong(nil, restore: true)
                let restored = await library.searchSongs(matching: "")
                try check(restored.count == 3 && Set(restored.map(\.id)).count == 3, "restore duplicated catalog")
            } else {
                try check(initial.count == 3, "fresh-install catalog must have all three starters")
                var played: [String] = []
                for identifier in StarterKaraokeStore.identifiers {
                    let song = StarterKaraokeStore.song(identifier)
                    let cues = try await library.lyricCues(for: song.id)
                    let pages = KaraokeLyricPageSequence(cues: cues)
                    try check(pages.lines.count == 4, "lyric line extraction")
                    try await controller.playNow(songID: song.id)
                    try await Task.sleep(for: .milliseconds(350))
                    let playing = await controller.snapshot()
                    try check(playing.transport == .playing && playing.nowPlaying?.id == song.id &&
                        playing.positionMilliseconds > 0, "real engine failed to advance")
                    try await controller.send(.pause)
                    let seek = pages.lines[2].milliseconds
                    try await controller.send(.seek(milliseconds: seek))
                    let paused = await controller.snapshot()
                    try check(paused.transport == .paused && paused.positionMilliseconds == seek, "pause/seek")
                    let current = KaraokeLyricSequence(cues: cues).window(atMilliseconds: paused.positionMilliseconds)
                    try check(current.current?.milliseconds == seek, "lyrics did not follow seek")
                    try await controller.send(.play)
                    played.append(identifier)
                }
                let queued = StarterKaraokeStore.song("sing-together")
                try await controller.send(.enqueue(songID: queued.id))
                try await controller.send(.next)
                let next = await controller.snapshot()
                try check(next.nowPlaying?.id == queued.id && next.queue.isEmpty, "FIFO queue integration")
                try await controller.send(.stop)
                try await library.changeStarterSong("morning-light", restore: false)
                let remaining = await library.searchSongs(matching: "")
                try check(remaining.count == 2, "individual removal")
                evidence["played"] = played
                evidence["checks"] = ["fresh install", "real MIDI sampler", "play/pause/seek", "timed lyrics", "FIFO queue", "remove"]
            }
            evidence["passed"] = true
        } catch {
            evidence["error"] = error.localizedDescription
        }
        do {
            try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
                .write(to: output, options: .atomic)
        } catch {
            // CI requires this file and times out/fails if it cannot be written.
            NSLog("Starter simulator evidence could not be written: %@", error.localizedDescription)
        }
    }
}

private enum SmokeError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case let .failed(message) = self { return message }; return nil }
}
#endif
