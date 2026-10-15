import Foundation

public enum TransportState: String, Codable, Sendable {
    case stopped
    case playing
    case paused
}

public struct KaraokeCompletion: Equatable, Codable, Sendable {
    public let playbackID: UUID
    public let song: LibrarySong

    public init(playbackID: UUID, song: LibrarySong) {
        self.playbackID = playbackID
        self.song = song
    }
}

public struct KaraokeSnapshot: Equatable, Codable, Sendable {
    public var transport: TransportState
    public var nowPlaying: LibrarySong?
    public var nowSinging: String?
    public var queue: [QueueItem]
    public var positionMilliseconds: Int64
    public var durationMilliseconds: Int64?
    public var volume: Float
    public var pitchSemitones: Int
    public var tempoRatio: Double
    public var playbackID: UUID?
    public var lastCompletion: KaraokeCompletion?
    public var playbackError: String?

    public init(
        transport: TransportState = .stopped,
        nowPlaying: LibrarySong? = nil,
        nowSinging: String? = nil,
        queue: [QueueItem] = [],
        positionMilliseconds: Int64 = 0,
        durationMilliseconds: Int64? = nil,
        volume: Float = 1.0,
        pitchSemitones: Int = 0,
        tempoRatio: Double = 1.0,
        playbackID: UUID? = nil,
        lastCompletion: KaraokeCompletion? = nil,
        playbackError: String? = nil
    ) {
        self.transport = transport
        self.nowPlaying = nowPlaying
        self.nowSinging = nowSinging
        self.queue = queue
        self.positionMilliseconds = max(0, positionMilliseconds)
        self.durationMilliseconds = durationMilliseconds.map { max(0, $0) }
        self.volume = min(max(volume, 0), 1)
        self.pitchSemitones = min(max(pitchSemitones, -12), 12)
        self.tempoRatio = min(max(tempoRatio, 0.5), 2.0)
        self.playbackID = playbackID
        self.lastCompletion = lastCompletion
        self.playbackError = playbackError
    }
}

public enum KaraokeCommand: Equatable, Sendable {
    case play
    case pause
    case stop
    case next
    case previous
    case seek(milliseconds: Int64)
    case setVolume(Float)
    case setPitch(semitones: Int)
    case setTempo(ratio: Double)
    case enqueue(songID: SongID)
    case enqueueForSinger(songID: SongID, singer: String)
    case moveQueueItem(id: UUID, before: UUID?)
    case removeQueueItem(UUID)
    case triggerSFX(PartySFX)
    case stopSFX
    case setSFXVolume(Float)
}

public protocol KaraokeController: Sendable {
    func snapshot() async -> KaraokeSnapshot
    func send(_ command: KaraokeCommand) async throws
}


