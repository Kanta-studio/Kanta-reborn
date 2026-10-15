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
    @Published private(set) var hasMoreSongs = false
    private let searchPageSize = 24
    @Published private(set) var snapshot = KaraokeSnapshot()
    @Published private(set) var lyricWindow = KaraokeLyricWindow()
    @Published private(set) var lyricPage = KaraokeLyricPage()
    @Published private(set) var hasLyrics = false
    @Published private(set) var backgroundAsset: KaraokeBackgroundAsset?
    @Published private(set) var scoringTargetExtraction:
        MIDIMelodyTargetExtraction?
    @Published private(set) var liveScore:
        KaraokeScoreBreakdown?
    @Published private(set) var scoringObservationCount = 0
    @Published private(set) var scoringLatencyMilliseconds: Int64 = 0
    @Published private(set) var scoringEnabled = false
    @Published var completedScore: CompletedKaraokeScore?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSessionSavePrompt = false
    @Published private(set) var pendingSessionSongs: [LibrarySong] = []
    @Published private(set) var isSavingFinishedSession = false
    @Published private(set) var currentSessionSongCount = 0
    @Published private(set) var savedFavorites: [SavedKaraokeSet] = []
    @Published var sessionNotice: String?


    private let controller: LocalKaraokeController?
    private let library: BookmarkedKaraokeLibrary?
    private let savedSets: SavedKaraokeSetStore?
    private var sessionHistory = KaraokeSessionHistory()
    private var pendingSessionSaveID: UUID?
    private var isLoadingFavoritesQueue = false
    private let demoMode: Bool
    private var demoCatalog: [LibrarySong] = []

    private var presentationSongID: SongID?
    private var presentationPlaybackID: UUID?
    private var isRefreshingSnapshot = false
    private var lyricSequence = KaraokeLyricSequence(cues: [])
    private var lyricPageSequence = KaraokeLyricPageSequence(cues: [])
    private var scoringSession: LiveKaraokeScoringSession?

    init(
        controller: LocalKaraokeController?,
        library: BookmarkedKaraokeLibrary?,
        savedSets: SavedKaraokeSetStore? = nil
    ) {
        self.controller = controller
        self.library = library
        self.savedSets = savedSets
        self.demoMode =
            ProcessInfo.processInfo.environment[
                "KANTA_DEMO_MODE"
            ] == "1"

        if demoMode {
            seedDemoState()
            recordSessionSnapshot(snapshot)
        }
    }

    var isAvailable: Bool {
        demoMode || (controller != nil && library != nil)
    }

    var songbookLibrary: BookmarkedKaraokeLibrary? { library }

    func run() async {
        if demoMode {
            return
        }

        guard let library else {
            errorMessage = "Playback services are unavailable."
            return
        }

        isLoading = true
        await refreshSavedFavorites()
        let report = await library.loadIfNeeded()
        if let issue = report.issues.first {
            errorMessage = issue.message
        }
        await search()
        await refreshSnapshot()
        isLoading = false

        while !Task.isCancelled {
            do {
                try await Task.sleep(
                    nanoseconds: 100_000_000
                )
            } catch {
                break
            }
            await refreshSnapshot()
        }
    }

    func search() async {
        let submitted = query
        let results: [LibrarySong]
        if demoMode {
            let normalized = submitted.trimmingCharacters(in: .whitespacesAndNewlines)
            let matches = normalized.isEmpty ? demoCatalog : demoCatalog.filter {
                $0.title.localizedCaseInsensitiveContains(normalized)
                || ($0.artist?.localizedCaseInsensitiveContains(normalized) ?? false)
                || ($0.code?.localizedCaseInsensitiveContains(normalized) ?? false)
            }
            results = Array(matches.prefix(searchPageSize + 1))
        } else {
            guard let library else {
                songs = []
                hasMoreSongs = false
                return
            }
            results = await library.searchSongs(
                matching: submitted, limit: searchPageSize + 1, offset: 0
            )
        }
        guard query == submitted else { return }
        songs = Array(results.prefix(searchPageSize))
        hasMoreSongs = results.count > searchPageSize
    }

    func loadMoreSongs() async {
        guard hasMoreSongs else { return }
        let submitted = query
        let offset = songs.count
        let batch: [LibrarySong]
        if demoMode {
            let normalized = submitted.trimmingCharacters(in: .whitespacesAndNewlines)
            let matches = normalized.isEmpty ? demoCatalog : demoCatalog.filter {
                $0.title.localizedCaseInsensitiveContains(normalized)
                || ($0.artist?.localizedCaseInsensitiveContains(normalized) ?? false)
                || ($0.code?.localizedCaseInsensitiveContains(normalized) ?? false)
            }
            batch = Array(matches.dropFirst(offset).prefix(searchPageSize + 1))
        } else {
            guard let library else { return }
            batch = await library.searchSongs(
                matching: submitted, limit: searchPageSize + 1,
                offset: offset
            )
        }
        guard query == submitted, songs.count == offset else { return }
        songs.append(contentsOf: batch.prefix(searchPageSize))
        hasMoreSongs = batch.count > searchPageSize
    }

    func enqueue(_ song: LibrarySong, singer: String = "") async {
        let trimmed = String(singer.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).prefix(60))
        await perform(
            trimmed.isEmpty
                ? .enqueue(songID: song.id)
                : .enqueueForSinger(songID: song.id, singer: trimmed)
        )
    }

    func moveQueueItem(_ id: UUID, up: Bool) async {
        guard let position = snapshot.queue.firstIndex(where: { $0.id == id })
        else { return }
        if up {
            guard position > 0 else { return }
            await perform(.moveQueueItem(
                id: id, before: snapshot.queue[position - 1].id
            ))
        } else {
            guard position + 1 < snapshot.queue.count else { return }
            let afterNext = position + 2
            await perform(.moveQueueItem(
                id: id,
                before: afterNext < snapshot.queue.count
                    ? snapshot.queue[afterNext].id : nil
            ))
        }
    }

    func triggerPartySFX(_ sound: PartySFX) async {
        await perform(.triggerSFX(sound))
    }

    func stopPartySFX() async {
        await perform(.stopSFX)
    }

    func setPartySFXVolume(_ value: Float) async {
        await perform(.setSFXVolume(value))
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
        // The snapshot refresh publishes live scores at 100 ms intervals.
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
        guard var scoringSession else { return }
        scoringSession.resetObservations()
        self.scoringSession = scoringSession
        updateLiveScore()
    }

    var canSaveFavorites: Bool { savedSets != nil }

    var suggestedFavoritesName: String {
        "Karaoke Session " + Date.now.formatted(
            .dateTime.month(.abbreviated).day().year()
        )
    }

    func refreshSavedFavorites() async {
        savedFavorites = await savedSets?.all() ?? []
    }

    func browseSongsForPlaylist(
        query: String, offset: Int
    ) async -> [LibrarySong] {
        guard let library else { return [] }
        return await library.searchSongs(
            matching: query,
            limit: 50,
            offset: offset
        )
    }

    @discardableResult
    func createPlaylist(
        name: String, firstSong: LibrarySong
    ) async -> UUID? {
        guard let savedSets else {
            errorMessage = "Saved playlists storage is not available."
            return nil
        }
        do {
            let item = try await savedSets.save(
                name: name,
                songs: [firstSong],
                kind: .playlist
            )
            await refreshSavedFavorites()
            return item.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func appendToPlaylist(song: LibrarySong, collectionID: UUID) async {
        guard let savedSets else { return }
        do {
            try await savedSets.append(song: song, to: collectionID)
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePlaylistSong(at position: Int, collectionID: UUID) async {
        guard let savedSets else { return }
        do {
            try await savedSets.removeSong(at: position, from: collectionID)
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorderPlaylistSong(
        from position: Int, to destination: Int, collectionID: UUID
    ) async {
        guard let savedSets else { return }
        do {
            try await savedSets.moveSong(
                in: collectionID, from: position, to: destination
            )
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Explicit session boundary; prompts even when a song was manually
    /// skipped or the last performance did not finish naturally.
    func endSession() async {
        await perform(.stop)
        presentFinishedSessionIfNeeded()
    }

    func saveFinishedSession(named name: String) async {
        guard !isSavingFinishedSession, !pendingSessionSongs.isEmpty else { return }
        guard let savedSets else {
            errorMessage = "Favorites storage is unavailable on this device."
            return
        }
        let key = pendingSessionSaveID ?? UUID()
        pendingSessionSaveID = key
        isSavingFinishedSession = true
        defer { isSavingFinishedSession = false }
        do {
            _ = try await savedSets.save(
                name: name, songs: pendingSessionSongs, idempotencyKey: key
            )
            pendingSessionSongs = []
            pendingSessionSaveID = nil
            showingSessionSavePrompt = false
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardFinishedSession() {
        guard !isSavingFinishedSession else { return }
        pendingSessionSongs = []
        pendingSessionSaveID = nil
        showingSessionSavePrompt = false
    }

    func renameFavorites(_ id: UUID, to name: String) async {
        guard let savedSets else { return }
        do {
            try await savedSets.rename(id: id, to: name)
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFavorites(_ id: UUID) async {
        guard let savedSets else { return }
        do {
            try await savedSets.delete(id: id)
            await refreshSavedFavorites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Always resolve against the *current* authorized library. A saved
    /// metadata snapshot is never evidence that source media still exists.
    /// Keep the existing queue; append playable entries in recorded order.
    func loadFavoritesIntoQueue(_ set: SavedKaraokeSet) async {
        // A second tap cannot interleave another multi-command append.
        guard !isLoadingFavoritesQueue else { return }
        isLoadingFavoritesQueue = true
        defer { isLoadingFavoritesQueue = false }
        var added = 0
        var skipped = 0
        for saved in set.songs {
            if demoMode {
                guard let item = demoCatalog.first(where: { $0.id == saved.id }),
                      item.isPlayable else {
                    skipped += 1
                    continue
                }
                applyDemo(.enqueue(songID: item.id))
                added += 1
                continue
            }
            guard let controller, let library,
                  let live = try? await library.song(id: saved.id),
                  live.isPlayable else {
                skipped += 1
                continue
            }
            do {
                try await controller.send(.enqueue(songID: live.id))
                added += 1
            } catch {
                skipped += 1
            }
        }
        if !demoMode { await refreshSnapshot() }
        sessionNotice = "Added \(added) song(s) to Up Next."
            + (skipped > 0
               ? " \(skipped) unavailable song(s) skipped." : "")
            + (added > 0 ? " Use Next to start the collection." : "")
    }

    private func recordSessionSnapshot(_ current: KaraokeSnapshot) {
        guard !showingSessionSavePrompt else { return }
        sessionHistory.observe(current)
        currentSessionSongCount = sessionHistory.playedSongs.count
    }

    private func presentFinishedSessionIfNeeded() {
        guard !showingSessionSavePrompt,
              !sessionHistory.playedSongs.isEmpty else { return }
        pendingSessionSongs = sessionHistory.finish()
        pendingSessionSaveID = UUID()
        currentSessionSongCount = 0
        showingSessionSavePrompt = true
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
        // Synthetic source-timed demo fragments also exercise partial highlighting.
        lyricPageSequence = KaraokeLyricPageSequence(cues: [
            KaraokeLyricCue(trackIndex: 0, eventIndex: 0, absoluteTicks: 0,
                           milliseconds: 83_000, text: "/Ikaw ang "),
            KaraokeLyricCue(trackIndex: 0, eventIndex: 1, absoluteTicks: 1,
                           milliseconds: 85_000, text: "aking hiling"),
            KaraokeLyricCue(trackIndex: 0, eventIndex: 2, absoluteTicks: 2,
                           milliseconds: 89_000, text: "/Sa bawat bagong awit"),
            KaraokeLyricCue(trackIndex: 0, eventIndex: 3, absoluteTicks: 3,
                           milliseconds: 93_000, text: "/Sabay nating abutin")
        ])
        lyricPage = lyricPageSequence.page(atMilliseconds: snapshot.positionMilliseconds)
        hasLyrics = true
    }

    private func applyDemo(_ command: KaraokeCommand) {
        switch command {
        case .play:
            snapshot.transport = .playing
            recordSessionSnapshot(snapshot)

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
            snapshot.nowSinging = next.requestedBy
            snapshot.queue.removeFirst()
            snapshot.positionMilliseconds = 0
            snapshot.durationMilliseconds = 238_000
            snapshot.transport = .playing
            recordSessionSnapshot(snapshot)

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

        case let .enqueueForSinger(songID, singer):
            guard let song = demoCatalog.first(
                where: { $0.id == songID }
            ) else { return }
            let trimmed = String(singer.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).prefix(60))
            snapshot.queue.append(QueueItem(
                song: song,
                requestedBy: trimmed.isEmpty ? nil : trimmed
            ))

        case let .moveQueueItem(id, destination):
            var list = PlaybackQueue(items: snapshot.queue)
            _ = list.move(id: id, before: destination)
            snapshot.queue = list.items

        case let .removeQueueItem(id):
            snapshot.queue.removeAll { $0.id == id }
        case .triggerSFX, .stopSFX, .setSFXVolume:
            break // UI demo mode deliberately never plays system audio.
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
        recordSessionSnapshot(latest)
        // Natural completion with an empty queue, or Stop sent by a paired
        // controller, ends the current session and offers an optional save.
        if previous.transport != .stopped,
           latest.transport == .stopped,
           latest.queue.isEmpty {
            presentFinishedSessionIfNeeded()
        }
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
            lyricPage = KaraokeLyricPage()
            // Stop accepting observations for the previous run during async metadata reads.
            scoringSession = nil
            updateLiveScore()

            do {
                let cues = try await library?.lyricCues(
                    for: song.id
                ) ?? []
                lyricSequence = KaraokeLyricSequence(cues: cues)
                lyricPageSequence = KaraokeLyricPageSequence(cues: cues)
            } catch {
                lyricSequence = KaraokeLyricSequence(cues: [])
                lyricPageSequence = KaraokeLyricPageSequence(cues: [])
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
        lyricPage = lyricPageSequence.page(
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
              let score = scoringSession?.score,
              let observationCount =
                scoringSession?.observationCount,
              observationCount > 0 else {
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
        lyricPageSequence = KaraokeLyricPageSequence(cues: [])
        lyricPage = KaraokeLyricPage()
        hasLyrics = false
        backgroundAsset = nil
        scoringTargetExtraction = nil
        scoringSession = nil
        updateLiveScore()
    }

    private func updateLiveScore() {
        liveScore = scoringSession?.score
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
