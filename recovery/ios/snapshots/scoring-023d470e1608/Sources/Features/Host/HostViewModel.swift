import Dispatch
import Combine
import Foundation
import GeloKaraokeCore
import LibraryStorage

struct CompletedKaraokeScore: Identifiable, Equatable {
    let id = UUID()
    let song: LibrarySong
    let score: KaraokeScoreBreakdown
    let observationCount: Int
}

@MainActor
final class HostViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var songs: [LibrarySong] = []
    @Published private(set) var snapshot = KaraokeSnapshot()
    @Published private(set) var lyricWindow = KaraokeLyricWindow()
    @Published private(set) var hasLyrics = false
    @Published private(set) var backgroundAsset: KaraokeBackgroundAsset?
    @Published private(set) var scoringTargetExtraction:
        MIDIMelodyTargetExtraction?
    @Published private(set) var liveScore:
        KaraokeScoreBreakdown?
    @Published private(set) var scoringObservationCount = 0
    @Published private(set) var scoringLatencyMilliseconds: Int64 = 0
    @Published private(set) var scoringEnabled = false
    @Published private(set) var scoringMessage: String?
    @Published var completedScore: CompletedKaraokeScore?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let controller: LocalKaraokeController?
    private let library: BookmarkedKaraokeLibrary?
    private let demoMode: Bool
    private var demoCatalog: [LibrarySong] = []

    private var presentationSongID: SongID?
    private var presentationPlaybackID: UUID?
    private var isRefreshingSnapshot = false
    private var lyricSequence = KaraokeLyricSequence(cues: [])
    private var scoringSession: LiveKaraokeScoringSession?

    init(
        controller: LocalKaraokeController?,
        library: BookmarkedKaraokeLibrary?
    ) {
        self.controller = controller
        self.library = library
        self.demoMode =
            ProcessInfo.processInfo.environment[
                "KANTA_DEMO_MODE"
            ] == "1"

        if demoMode {
            seedDemoState()
        }
    }

    var isAvailable: Bool {
        demoMode || (controller != nil && library != nil)
    }

    func run() async {
        if demoMode {
            return
        }

        guard let library else {
            errorMessage = "Playback services are unavailable."
            return
        }

        isLoading = true
        let report = await library.loadIfNeeded()
        if !report.issues.isEmpty {
            errorMessage =
                "Some library folders need permission again."
        }
        await search()
        await refreshSnapshot()
        isLoading = false

        while !Task.isCancelled {
            do {
                try await Task.sleep(
                    nanoseconds: 250_000_000
                )
            } catch {
                break
            }
            await refreshSnapshot()
        }
    }

    func search() async {
        if demoMode {
            let trimmed = query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmed.isEmpty {
                songs = demoCatalog
            } else {
                songs = demoCatalog.filter { song in
                    song.title.localizedCaseInsensitiveContains(
                        trimmed
                    )
                    || (song.artist?
                        .localizedCaseInsensitiveContains(
                            trimmed
                        ) ?? false)
                    || (song.code?
                        .localizedCaseInsensitiveContains(
                            trimmed
                        ) ?? false)
                }
            }
            return
        }

        guard let library else {
            songs = []
            return
        }
        songs = await library.searchSongs(
            matching: query,
            limit: 250
        )
    }

    func enqueue(_ song: LibrarySong) async {
        await perform(
            .enqueue(songID: song.id)
        )
    }

    func removeQueueItem(_ id: UUID) async {
        await perform(.removeQueueItem(id))
    }

    func togglePlayPause() async {
        switch snapshot.transport {
        case .playing:
            await perform(.pause)
        case .paused, .stopped:
            await perform(.play)
        }
    }

    func next() async {
        await perform(.next)
    }

    func previous() async {
        await perform(.previous)
    }

    func setVolume(_ value: Float) async {
        await perform(.setVolume(value))
    }

    func seek(toMilliseconds value: Int64) async {
        await perform(
            .seek(milliseconds: max(0, value))
        )
    }

    func changePitch(by delta: Int) async {
        await perform(
            .setPitch(
                semitones: snapshot.pitchSemitones + delta
            )
        )
    }

    func changeTempo(by delta: Double) async {
        await perform(
            .setTempo(
                ratio: snapshot.tempoRatio + delta
            )
        )
    }

    func setScoringEnabled(_ enabled: Bool) {
        scoringEnabled = enabled

        guard enabled else {
            scoringSession = nil
            liveScore = nil
            scoringObservationCount = 0
            return
        }

        rebuildScoringSessionIfPossible()
    }

    func ingestPitchObservation(
        _ observation: PitchObservation
    ) {
        guard scoringEnabled,
              var scoringSession else { return }
        _ = scoringSession.ingest(observation)
        self.scoringSession = scoringSession
        // The snapshot refresh publishes live scores at 250 ms intervals.
    }

    func setScoringLatencyMilliseconds(
        _ value: Int64
    ) {
        scoringLatencyMilliseconds = min(
            max(value, -500),
            1_500
        )
        guard var scoringSession else { return }
        scoringSession.setLatencyMilliseconds(
            scoringLatencyMilliseconds
        )
        self.scoringSession = scoringSession
        updateLiveScore()
    }

    func resetLiveScore() {
        scoringMessage = nil
        guard var scoringSession else { return }
        scoringSession.resetObservations()
        self.scoringSession = scoringSession
        updateLiveScore()
    }

    private func perform(_ command: KaraokeCommand) async {
        if demoMode {
            applyDemo(command)
            return
        }

        guard let controller else {
            errorMessage = "Playback services are unavailable."
            return
        }

        do {
            try await controller.send(command)
            await refreshSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func seedDemoState() {
        let now = LibrarySong(
            id: SongID(rawValue: "demo:hiling"),
            code: "001",
            title: "Hiling",
            artist: "KANTA Demo",
            mediaKind: .mp3
        )
        let second = LibrarySong(
            id: SongID(rawValue: "demo:paraluman"),
            code: "002",
            title: "Paraluman",
            artist: "KANTA Demo",
            mediaKind: .kar
        )
        let third = LibrarySong(
            id: SongID(rawValue: "demo:tadhana"),
            code: "003",
            title: "Tadhana",
            artist: "KANTA Demo",
            mediaKind: .midi
        )
        let fourth = LibrarySong(
            id: SongID(rawValue: "demo:ulan"),
            code: "004",
            title: "Ulan",
            artist: "KANTA Demo",
            mediaKind: .mp3
        )

        demoCatalog = [now, second, third, fourth]
        songs = demoCatalog
        snapshot = KaraokeSnapshot(
            transport: .playing,
            nowPlaying: now,
            queue: [
                QueueItem(song: second),
                QueueItem(song: third)
            ],
            positionMilliseconds: 84_000,
            durationMilliseconds: 248_000,
            volume: 0.82,
            pitchSemitones: 0,
            tempoRatio: 1.0
        )
        lyricWindow = KaraokeLyricWindow(
            previous: KaraokeLyricItem(
                milliseconds: 80_000,
                text: "Sa bawat awit"
            ),
            current: KaraokeLyricItem(
                milliseconds: 84_000,
                text: "Ikaw ang aking hiling"
            ),
            next: KaraokeLyricItem(
                milliseconds: 89_000,
                text: "Hanggang sa dulo"
            )
        )
        hasLyrics = true
    }

    private func applyDemo(_ command: KaraokeCommand) {
        switch command {
        case .play:
            snapshot.transport = .playing

        case .pause:
            snapshot.transport = .paused

        case .stop:
            snapshot.transport = .stopped
            snapshot.positionMilliseconds = 0

        case .next:
            guard let next = snapshot.queue.first else {
                return
            }
            snapshot.nowPlaying = next.song
            snapshot.queue.removeFirst()
            snapshot.positionMilliseconds = 0
            snapshot.durationMilliseconds = 238_000
            snapshot.transport = .playing

        case .previous:
            snapshot.positionMilliseconds = 0

        case let .seek(milliseconds):
            let maximum =
                snapshot.durationMilliseconds ?? Int64.max
            snapshot.positionMilliseconds = min(
                max(0, milliseconds),
                maximum
            )

        case let .setVolume(value):
            snapshot.volume = min(max(value, 0), 1)

        case let .setPitch(semitones):
            snapshot.pitchSemitones = min(
                max(semitones, -12),
                12
            )

        case let .setTempo(ratio):
            snapshot.tempoRatio = min(
                max(ratio, 0.5),
                2
            )

        case let .enqueue(songID):
            guard let song = demoCatalog.first(
                where: { $0.id == songID }
            ) else {
                return
            }
            snapshot.queue.append(
                QueueItem(song: song)
            )

        case let .removeQueueItem(id):
            snapshot.queue.removeAll { $0.id == id }
        }
    }

    private func refreshSnapshot() async {
        guard let controller, !isRefreshingSnapshot else { return }
        isRefreshingSnapshot = true
        defer { isRefreshingSnapshot = false }
        let previous = snapshot
        let latest = await controller.snapshot()
        let capturedAt = monotonicMilliseconds()

        captureCompletedScoreIfNeeded(
            previous: previous,
            latest: latest
        )

        if latest.playbackError != previous.playbackError,
           let playbackError = latest.playbackError {
            errorMessage = playbackError
        }
        snapshot = latest
        await refreshPresentation(for: latest)

        if var scoringSession {
            scoringSession.updatePlaybackAnchor(
                snapshot: latest,
                captureTimestampMilliseconds: capturedAt
            )
            self.scoringSession = scoringSession
            updateLiveScore()
        }
    }

    private func refreshPresentation(
        for snapshot: KaraokeSnapshot
    ) async {
        guard let song = snapshot.nowPlaying else {
            resetPresentation()
            return
        }

        if presentationSongID != song.id || presentationPlaybackID != snapshot.playbackID {
            presentationSongID = song.id
            presentationPlaybackID = snapshot.playbackID
            // Stop accepting observations for the previous run during async metadata reads.
            scoringSession = nil
            updateLiveScore()

            do {
                let cues = try await library?.lyricCues(
                    for: song.id
                ) ?? []
                lyricSequence = KaraokeLyricSequence(
                    cues: cues
                )
            } catch {
                lyricSequence = KaraokeLyricSequence(
                    cues: []
                )
            }
            hasLyrics = !lyricSequence.isEmpty

            if let library {
                do {
                    backgroundAsset = try await library
                        .backgroundAsset(for: song.id)
                } catch {
                    backgroundAsset = nil
                }

                do {
                    scoringTargetExtraction = try await library
                        .scoringTarget(for: song.id)
                } catch {
                    scoringTargetExtraction = nil
                }
            } else {
                backgroundAsset = nil
                scoringTargetExtraction = nil
            }

            rebuildScoringSessionIfPossible()
            updateLiveScore()
        }

        lyricWindow = lyricSequence.window(
            atMilliseconds: snapshot.positionMilliseconds
        )
    }


    private func rebuildScoringSessionIfPossible() {
        guard scoringEnabled,
              case let .resolved(target) =
                scoringTargetExtraction else {
            scoringSession = nil
            liveScore = nil
            scoringObservationCount = 0
            return
        }

        scoringSession = LiveKaraokeScoringSession(
            target: target,
            latencyMilliseconds:
                scoringLatencyMilliseconds,
            pitchSemitones:
                snapshot.pitchSemitones
        )
        updateLiveScore()
    }

    private func captureCompletedScoreIfNeeded(
        previous: KaraokeSnapshot,
        latest: KaraokeSnapshot
    ) {
        guard scoringEnabled,
              let previousSong = previous.nowPlaying,
              let observationCount =
                scoringSession?.observationCount,
              observationCount >= 0 else {
            return
        }

        guard let completedSong =
            KaraokeScoreCompletionDetector.completedSong(
                previous: previous,
                latest: latest
            ),
            completedSong.id == previousSong.id else {
            return
        }

        guard let score = RoomScoreReliability.reportable(scoringSession?.completedScore) else {
            completedScore = nil
            scoringMessage = "No reliable room score for this song. Move closer to the singer and lower the backing volume."
            return
        }
        scoringMessage = nil
        completedScore = CompletedKaraokeScore(
            song: completedSong,
            score: score,
            observationCount: observationCount
        )
    }

    private func resetPresentation() {
        presentationSongID = nil
        presentationPlaybackID = nil
        lyricSequence = KaraokeLyricSequence(cues: [])
        lyricWindow = KaraokeLyricWindow()
        hasLyrics = false
        backgroundAsset = nil
        scoringTargetExtraction = nil
        scoringSession = nil
        updateLiveScore()
    }

    private func updateLiveScore() {
        liveScore = RoomScoreReliability.reportable(scoringSession?.score)
        scoringObservationCount =
            scoringSession?.observationCount ?? 0
    }

    private func monotonicMilliseconds() -> Int64 {
        Int64(
            DispatchTime.now().uptimeNanoseconds
                / 1_000_000
        )
    }
}


