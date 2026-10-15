import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func localControllerDrivesQueueAndHistory() async throws {
    let first = LibrarySong(
        id: SongID(rawValue: "one"),
        title: "One",
        mediaKind: .wav
    )
    let second = LibrarySong(
        id: SongID(rawValue: "two"),
        title: "Two",
        mediaKind: .mp3
    )

    let library = FakeKaraokeLibrary(songs: [first, second])
    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(
        engine: engine,
        library: library
    )

    try await controller.send(.enqueue(songID: first.id))
    try await controller.send(.enqueue(songID: second.id))
    try await controller.send(.play)

    var snapshot = await controller.snapshot()
    #expect(snapshot.transport == .playing)
    #expect(snapshot.nowPlaying?.id == first.id)
    #expect(snapshot.queue.map(\.song.id) == [second.id])

    try await controller.send(.next)
    snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying?.id == second.id)
    #expect(snapshot.queue.isEmpty)

    try await controller.send(.previous)
    snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying?.id == first.id)
    #expect(snapshot.queue.map(\.song.id) == [second.id])
}

@Test func localControllerDoesNotDiscardCurrentSongWhenNextQueueIsEmpty() async throws {
    let song = LibrarySong(
        id: SongID(rawValue: "one"),
        title: "One",
        mediaKind: .wav
    )

    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(),
        library: FakeKaraokeLibrary(songs: [song])
    )

    try await controller.send(.enqueue(songID: song.id))
    try await controller.send(.play)

    await #expect(throws: LocalKaraokeControllerError.queueEmpty) {
        try await controller.send(.next)
    }

    let snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying?.id == song.id)
}


@Test func localControllerAutoAdvancesReservedSongAfterNaturalCompletion() async throws {
    let first = LibrarySong(
        id: SongID(rawValue: "first"),
        title: "First",
        mediaKind: .wav
    )
    let second = LibrarySong(
        id: SongID(rawValue: "second"),
        title: "Second",
        mediaKind: .mp3
    )

    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(
        engine: engine,
        library: FakeKaraokeLibrary(songs: [first, second])
    )

    try await controller.send(.enqueue(songID: first.id))
    try await controller.send(.enqueue(songID: second.id))
    try await controller.send(.play)

    await engine.finishCurrentNaturally()

    let snapshot = await controller.snapshot()
    #expect(snapshot.transport == .playing)
    #expect(snapshot.nowPlaying?.id == second.id)
    #expect(snapshot.queue.isEmpty)
}

@Test func localControllerPropagatesPlaybackControls() async throws {
    let song = LibrarySong(
        id: SongID(rawValue: "song"),
        title: "Song",
        mediaKind: .wav
    )

    let library = FakeKaraokeLibrary(songs: [song])
    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(
        engine: engine,
        library: library
    )

    try await controller.send(.enqueue(songID: song.id))
    try await controller.send(.play)
    try await controller.send(.seek(milliseconds: 12_345))
    try await controller.send(.setVolume(0.25))
    try await controller.send(.setPitch(semitones: -2))
    try await controller.send(.setTempo(ratio: 1.1))

    let snapshot = await controller.snapshot()
    #expect(snapshot.positionMilliseconds == 12_345)
    #expect(snapshot.volume == 0.25)
    #expect(snapshot.pitchSemitones == -2)
    #expect(snapshot.tempoRatio == 1.1)
}

@Test func localControllerRejectsUnknownSong() async {
    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(),
        library: FakeKaraokeLibrary(songs: [])
    )

    let missing = SongID(rawValue: "missing")
    await #expect(
        throws: LocalKaraokeControllerError.songNotFound(missing)
    ) {
        try await controller.send(.enqueue(songID: missing))
    }
}


@Test func localControllerKeepsQueuedSongWhenInitialPlayFails() async throws {
    let song = LibrarySong(
        id: SongID(rawValue: "broken-play"),
        title: "Broken Play",
        mediaKind: .wav
    )

    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(
            failingPlaySongIDs: [song.id]
        ),
        library: FakeKaraokeLibrary(songs: [song])
    )

    try await controller.send(.enqueue(songID: song.id))

    await #expect(
        throws: TestPlaybackError.forcedPlay(song.id)
    ) {
        try await controller.send(.play)
    }

    let snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying == nil)
    #expect(snapshot.queue.map(\.song.id) == [song.id])
}

@Test func localControllerKeepsQueuedSongWhenAssetResolutionFails() async throws {
    let song = LibrarySong(
        id: SongID(rawValue: "broken-asset"),
        title: "Broken Asset",
        mediaKind: .midi
    )

    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(),
        library: FakeKaraokeLibrary(
            songs: [song],
            failingAssetSongIDs: [song.id]
        )
    )

    try await controller.send(.enqueue(songID: song.id))

    await #expect(
        throws: TestPlaybackError.forcedAsset(song.id)
    ) {
        try await controller.send(.play)
    }

    let snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying == nil)
    #expect(snapshot.queue.map(\.song.id) == [song.id])
}

@Test func localControllerKeepsCurrentAndNextSongWhenNextLoadFails() async throws {
    let first = LibrarySong(
        id: SongID(rawValue: "current"),
        title: "Current",
        mediaKind: .wav
    )
    let second = LibrarySong(
        id: SongID(rawValue: "broken-next"),
        title: "Broken Next",
        mediaKind: .mp3
    )

    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(
            failingLoadSongIDs: [second.id]
        ),
        library: FakeKaraokeLibrary(songs: [first, second])
    )

    try await controller.send(.enqueue(songID: first.id))
    try await controller.send(.enqueue(songID: second.id))
    try await controller.send(.play)

    await #expect(
        throws: TestPlaybackError.forcedLoad(second.id)
    ) {
        try await controller.send(.next)
    }

    let snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying?.id == first.id)
    #expect(snapshot.queue.map(\.song.id) == [second.id])
}

private enum TestPlaybackError: Error, Equatable, Sendable {
    case forcedAsset(SongID)
    case forcedLoad(SongID)
    case forcedPlay(SongID)
}

private actor FakeAudioPlaybackEngine: AudioPlaybackEngine {
    private var state = AudioPlaybackSnapshot()
    private let failingLoadSongIDs: Set<SongID>
    private let failingPlaySongIDs: Set<SongID>

    init(
        failingLoadSongIDs: Set<SongID> = [],
        failingPlaySongIDs: Set<SongID> = []
    ) {
        self.failingLoadSongIDs = failingLoadSongIDs
        self.failingPlaySongIDs = failingPlaySongIDs
    }

    private var loadCount = 0
    private var blockSnapshot = false
    private var snapshotWaiter: CheckedContinuation<Void, Never>?
    func numberOfLoads() -> Int { loadCount }
    func blockNextSnapshot() { blockSnapshot = true }
    func isSnapshotBlocked() -> Bool { snapshotWaiter != nil }
    func releaseSnapshot() {
        snapshotWaiter?.resume()
        snapshotWaiter = nil
    }

    func load(_ asset: AudioPlaybackAsset) async throws {
        loadCount += 1
        await Task.yield()
        if failingLoadSongIDs.contains(asset.songID) {
            throw TestPlaybackError.forcedLoad(asset.songID)
        }

        state = AudioPlaybackSnapshot(
            transport: .stopped,
            songID: asset.songID,
            positionMilliseconds: 0,
            durationMilliseconds: 60_000,
            volume: state.volume,
            pitchSemitones: state.pitchSemitones,
            tempoRatio: state.tempoRatio
        )
    }

    func play() async throws {
        guard let songID = state.songID else {
            throw AudioPlaybackEngineError.noAssetLoaded
        }
        if failingPlaySongIDs.contains(songID) {
            throw TestPlaybackError.forcedPlay(songID)
        }
        state.didFinishNaturally = false
        state.transport = .playing
    }

    func pause() async {
        state.transport = .paused
    }

    func stop() async {
        state.transport = .stopped
        state.positionMilliseconds = 0
    }

    func seek(toMilliseconds milliseconds: Int64) async throws {
        guard state.songID != nil else {
            throw AudioPlaybackEngineError.noAssetLoaded
        }
        state.positionMilliseconds = max(0, milliseconds)
    }

    func setVolume(_ value: Float) async {
        state.volume = min(max(value, 0), 1)
    }

    func setPitch(semitones: Int) async {
        state.pitchSemitones = min(max(semitones, -12), 12)
    }

    func setTempo(ratio: Double) async {
        state.tempoRatio = min(max(ratio, 0.5), 2)
    }

    func finishCurrentNaturally() {
        guard let duration = state.durationMilliseconds else { return }
        state.didFinishNaturally = true
        state.positionMilliseconds = duration
        state.transport = .stopped
    }

    func snapshot() async -> AudioPlaybackSnapshot {
        if blockSnapshot {
            blockSnapshot = false
            await withCheckedContinuation {
                (continuation: CheckedContinuation<Void, Never>) in
                snapshotWaiter = continuation
            }
        }
        return state
    }
}

private struct FakeKaraokeLibrary: KaraokeLibraryAccess {
    private let songsByID: [SongID: LibrarySong]
    private let failingAssetSongIDs: Set<SongID>

    init(
        songs: [LibrarySong],
        failingAssetSongIDs: Set<SongID> = []
    ) {
        songsByID = Dictionary(
            uniqueKeysWithValues: songs.map { ($0.id, $0) }
        )
        self.failingAssetSongIDs = failingAssetSongIDs
    }

    func song(id: SongID) async throws -> LibrarySong? {
        songsByID[id]
    }

    func playbackAsset(for songID: SongID) async throws -> AudioPlaybackAsset {
        if failingAssetSongIDs.contains(songID) {
            throw TestPlaybackError.forcedAsset(songID)
        }

        guard let song = songsByID[songID] else {
            throw LocalKaraokeControllerError.songNotFound(songID)
        }

        return AudioPlaybackAsset(
            songID: songID,
            url: URL(fileURLWithPath: "/tmp/\(songID.rawValue)"),
            mediaKind: song.mediaKind
        )
    }
}


@Test func concurrentSnapshotsAdvanceExactlyOneReservation() async throws {
    let song = LibrarySong(id: SongID(rawValue: "repeat"), title: "Repeat", mediaKind: .wav)
    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(engine: engine, library: FakeKaraokeLibrary(songs: [song]))
    for _ in 0..<3 { try await controller.send(.enqueue(songID: song.id)) }
    try await controller.send(.play)
    let initial = await controller.snapshot()
    await engine.finishCurrentNaturally()
    await withTaskGroup(of: KaraokeSnapshot.self) { group in
        for _ in 0..<20 { group.addTask { await controller.snapshot() } }
        for await snapshot in group {
            #expect(snapshot.queue.count == 1)
            #expect(snapshot.playbackID != initial.playbackID)
            #expect(snapshot.lastCompletion?.playbackID == initial.playbackID)
        }
    }
    #expect(await engine.numberOfLoads() == 2)
}

@Test func failedAutomaticHandoffDoesNotRetryEveryPoll() async throws {
    let first = LibrarySong(id: SongID(rawValue: "first"), title: "First", mediaKind: .wav)
    let broken = LibrarySong(id: SongID(rawValue: "broken"), title: "Broken", mediaKind: .wav)
    let engine = FakeAudioPlaybackEngine(failingLoadSongIDs: [broken.id])
    let controller = LocalKaraokeController(engine: engine, library: FakeKaraokeLibrary(songs: [first, broken]))
    try await controller.send(.enqueue(songID: first.id))
    try await controller.send(.enqueue(songID: broken.id))
    try await controller.send(.play)
    await engine.finishCurrentNaturally()
    for _ in 0..<10 {
        let snapshot = await controller.snapshot()
        #expect(snapshot.queue.map(\.song.id) == [broken.id])
        #expect(snapshot.playbackError != nil)
        #expect(snapshot.lastCompletion?.song == first)
    }
    #expect(await engine.numberOfLoads() == 2)
    await #expect(throws: TestPlaybackError.forcedLoad(broken.id)) {
        try await controller.send(.next)
    }
    #expect(await engine.numberOfLoads() == 3)
}

@Test func manualNextNearEndDoesNotPublishCompletion() async throws {
    let song = LibrarySong(id: SongID(rawValue: "skip"), title: "Skip", mediaKind: .wav)
    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(engine: engine, library: FakeKaraokeLibrary(songs: [song]))
    for _ in 0..<2 { try await controller.send(.enqueue(songID: song.id)) }
    try await controller.send(.play)
    try await controller.send(.seek(milliseconds: 59_999))
    try await controller.send(.next)
    #expect(await controller.snapshot().lastCompletion == nil)
}

@Test func failedNextPlayDoesNotExposeOrResumeUncommittedAsset() async throws {
    let first = LibrarySong(id: SongID(rawValue: "good"), title: "Good", mediaKind: .wav)
    let broken = LibrarySong(id: SongID(rawValue: "bad-play"), title: "Bad", mediaKind: .wav)
    let engine = FakeAudioPlaybackEngine(failingPlaySongIDs: [broken.id])
    let controller = LocalKaraokeController(engine: engine, library: FakeKaraokeLibrary(songs: [first, broken]))
    try await controller.send(.enqueue(songID: first.id))
    try await controller.send(.enqueue(songID: broken.id))
    try await controller.send(.play)
    await #expect(throws: TestPlaybackError.forcedPlay(broken.id)) {
        try await controller.send(.next)
    }
    let stopped = await controller.snapshot()
    #expect(stopped.nowPlaying == first)
    #expect(stopped.transport == .stopped)
    #expect(stopped.lastCompletion == nil)
    try await controller.send(.play)
    #expect(await engine.snapshot().songID == first.id)
    #expect(await controller.snapshot().queue.map(\.song.id) == [broken.id])
}


@Test func catalogOnlyTitlesCannotBeEnqueuedEvenByPairedRemoteCommands() async throws {
    let title = LibrarySong(
        id: SongID(rawValue: "indexed:catalog:7"),
        title: "Browse Only", mediaKind: .legacyContainer,
        isPlayable: false
    )
    let controller = LocalKaraokeController(
        engine: FakeAudioPlaybackEngine(),
        library: FakeKaraokeLibrary(songs: [title])
    )
    await #expect(throws: LocalKaraokeControllerError.catalogOnlySong(title.id)) {
        try await controller.send(.enqueue(songID: title.id))
    }
    #expect(await controller.snapshot().queue.isEmpty)
}

@Test func librarySongLegacyJSONDefaultsToPlayableAndNewJSONPreservesStatus() throws {
    let song = LibrarySong(
        id: SongID(rawValue: "catalog:1"), title: "Title",
        mediaKind: .legacyContainer, isPlayable: false
    )
    let encoded = try JSONEncoder().encode(song)
    #expect(try JSONDecoder().decode(LibrarySong.self, from: encoded)
            .isPlayable == false)

    var dictionary = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    dictionary.removeValue(forKey: "isPlayable")
    let oldJSON = try JSONSerialization.data(withJSONObject: dictionary)
    #expect(try JSONDecoder().decode(LibrarySong.self, from: oldJSON)
            .isPlayable)
}

@Test func canceledPlaybackWaiterDoesNotBlockFutureCommands() async throws {
    let song = LibrarySong(
        id: SongID(rawValue: "gate-test"), title: "Gate", mediaKind: .wav
    )
    let engine = FakeAudioPlaybackEngine()
    let controller = LocalKaraokeController(
        engine: engine, library: FakeKaraokeLibrary(songs: [song])
    )
    await engine.blockNextSnapshot()
    let holding = Task { await controller.snapshot() }
    for _ in 0..<1_000 {
        if await engine.isSnapshotBlocked() { break }
        await Task.yield()
    }
    #expect(await engine.isSnapshotBlocked())

    let waiting = Task { try await controller.send(.setVolume(0.3)) }
    await Task.yield()
    waiting.cancel()
    await engine.releaseSnapshot()
    _ = await holding.value
    await #expect(throws: CancellationError.self) { try await waiting.value }

    try await controller.send(.setVolume(0.7))
    #expect(await controller.snapshot().volume == 0.7)
}


@Test func playNowPreservesReservationsAndDoesNotCommitFailedSong() async throws {
    let first = LibrarySong(id: SongID(rawValue: "first"), title: "First", mediaKind: .kar)
    let second = LibrarySong(id: SongID(rawValue: "second"), title: "Second", mediaKind: .kar)
    let controller = LocalKaraokeController(engine: FakeAudioPlaybackEngine(),
        library: FakeKaraokeLibrary(songs: [first, second]))
    try await controller.send(.enqueue(songID: second.id))
    try await controller.playNow(songID: first.id)
    let snapshot = await controller.snapshot()
    #expect(snapshot.nowPlaying?.id == first.id)
    #expect(snapshot.queue.map(\.song.id) == [second.id])
    await #expect(throws: (any Error).self) { try await controller.playNow(songID: SongID(rawValue: "missing")) }
    let after = await controller.snapshot()
    #expect(after.nowPlaying?.id == first.id)
    #expect(after.queue == snapshot.queue)
}
