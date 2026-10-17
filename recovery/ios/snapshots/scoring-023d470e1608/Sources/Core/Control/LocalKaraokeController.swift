import Foundation

public protocol KaraokeLibraryAccess: Sendable {
    func song(id: SongID) async throws -> LibrarySong?
    func playbackAsset(for songID: SongID) async throws -> AudioPlaybackAsset
}

public enum LocalKaraokeControllerError: Error, Equatable, Sendable {
    case songNotFound(SongID)
    case queueEmpty
    case historyEmpty
}

extension LocalKaraokeControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .songNotFound(songID):
            return "The selected song is no longer available (\(songID.rawValue))."
        case .queueEmpty:
            return "There are no songs waiting in the queue."
        case .historyEmpty:
            return "There is no previous song to return to."
        }
    }
}

public actor LocalKaraokeController: KaraokeController {
    private let engine: any AudioPlaybackEngine
    private let library: any KaraokeLibraryAccess

    private var queue = PlaybackQueue()
    private var currentItem: QueueItem?
    private var history: [QueueItem] = []
    private var playbackID: UUID?
    private var lastCompletion: KaraokeCompletion?
    private var failedAutoAdvanceItemID: UUID?
    private var playbackError: String?
    private var needsPlaybackReload = false

    // Actor isolation alone does not make an async load/play transaction atomic.
    // Serialize commands and snapshots across suspension points without blocking a thread.
    private var operationInProgress = false
    private var operationWaiters: [CheckedContinuation<Void, Never>] = []

    private func acquireOperation() async {
        if !operationInProgress {
            operationInProgress = true
            return
        }
        await withCheckedContinuation { operationWaiters.append($0) }
    }

    private func releaseOperation() {
        if operationWaiters.isEmpty {
            operationInProgress = false
        } else {
            operationWaiters.removeFirst().resume()
        }
    }

    public init(
        engine: any AudioPlaybackEngine,
        library: any KaraokeLibraryAccess
    ) {
        self.engine = engine
        self.library = library
    }

    public func snapshot() async -> KaraokeSnapshot {
        await acquireOperation()
        defer { releaseOperation() }
        var audio = await engine.snapshot()

        if !needsPlaybackReload, audio.didFinishNaturally,
           let currentItem, let playbackID,
           audio.songID == currentItem.song.id,
           lastCompletion?.playbackID != playbackID {
            lastCompletion = KaraokeCompletion(playbackID: playbackID, song: currentItem.song)
        }

        if shouldAutoAdvance(audio),
           let next = queue.items.first,
           failedAutoAdvanceItemID != next.id {
            do {
                try await startFollowingQueueItem()
                audio = await engine.snapshot()
            } catch {
                // Keep the reservation, surface the failure, and avoid retrying
                // expensive/broken media on every Host/Remote snapshot poll.
                failedAutoAdvanceItemID = next.id
                playbackError = error.localizedDescription
                audio = await engine.snapshot()
            }
        }

        // A failed adapter load/play may already have replaced its internal asset.
        // Never project that partially loaded song as the committed current song.
        if needsPlaybackReload {
            audio = AudioPlaybackSnapshot(songID: currentItem?.song.id,
                volume: audio.volume, pitchSemitones: audio.pitchSemitones,
                tempoRatio: audio.tempoRatio)
        }
        return KaraokeSnapshot(
            transport: audio.transport,
            nowPlaying: currentItem?.song,
            queue: queue.items,
            positionMilliseconds: audio.positionMilliseconds,
            durationMilliseconds: audio.durationMilliseconds,
            volume: audio.volume,
            pitchSemitones: audio.pitchSemitones,
            tempoRatio: audio.tempoRatio,
            playbackID: playbackID,
            lastCompletion: lastCompletion,
            playbackError: playbackError
        )
    }

    private func shouldAutoAdvance(
        _ audio: AudioPlaybackSnapshot
    ) -> Bool {
        !needsPlaybackReload && currentItem != nil && audio.didFinishNaturally
            && audio.songID == currentItem?.song.id
    }

    public func send(_ command: KaraokeCommand) async throws {
        await acquireOperation()
        defer { releaseOperation() }
        try Task.checkCancellation()
        switch command {
        case .play:
            if currentItem == nil {
                try await startNext(shouldPlay: true)
            } else {
                let before = await engine.snapshot()
                if needsPlaybackReload, let currentItem {
                    let asset = try await library.playbackAsset(for: currentItem.song.id)
                    try await prepareAsset(asset, shouldPlay: true)
                } else {
                    try await engine.play()
                }
                if before.transport == .stopped {
                    playbackID = UUID()
                }
                playbackError = nil
                failedAutoAdvanceItemID = nil
            }

        case .pause:
            await engine.pause()

        case .stop:
            await engine.stop()

        case .next:
            try await startFollowingQueueItem()

        case .previous:
            try await startPrevious()

        case let .seek(milliseconds):
            try await engine.seek(toMilliseconds: milliseconds)

        case let .setVolume(value):
            await engine.setVolume(value)

        case let .setPitch(semitones):
            await engine.setPitch(semitones: semitones)

        case let .setTempo(ratio):
            await engine.setTempo(ratio: ratio)

        case let .enqueue(songID):
            guard let song = try await library.song(id: songID) else {
                throw LocalKaraokeControllerError.songNotFound(songID)
            }
            queue.enqueue(song)

        case let .removeQueueItem(id):
            _ = queue.remove(id: id)
        }
    }

    private func startFollowingQueueItem() async throws {
        try await startNext(shouldPlay: true)
    }

    private func startNext(shouldPlay: Bool) async throws {
        guard let next = queue.items.first else {
            throw LocalKaraokeControllerError.queueEmpty
        }

        let asset = try await library.playbackAsset(for: next.song.id)
        try await prepareAsset(asset, shouldPlay: shouldPlay)

        // Commit queue state only after preparation/play succeeds.
        // Failed or malformed media therefore remains visible and
        // retryable/removable instead of being silently discarded.
        if let currentItem { history.append(currentItem) }
        _ = queue.remove(id: next.id)
        currentItem = next
        playbackID = UUID()
        playbackError = nil
        failedAutoAdvanceItemID = nil
    }

    private func prepareAsset(_ asset: AudioPlaybackAsset, shouldPlay: Bool) async throws {
        do {
            try await engine.load(asset)
            if shouldPlay { try await engine.play() }
            needsPlaybackReload = false
        } catch {
            await engine.stop()
            needsPlaybackReload = true
            throw error
        }
    }

    private func startPrevious() async throws {
        guard let previous = history.last else {
            throw LocalKaraokeControllerError.historyEmpty
        }

        let asset = try await library.playbackAsset(for: previous.song.id)
        try await prepareAsset(asset, shouldPlay: true)

        history.removeLast()
        if let currentItem {
            queue.prepend(currentItem)
        }
        currentItem = previous
        playbackID = UUID()
        playbackError = nil
        failedAutoAdvanceItemID = nil
    }
}


