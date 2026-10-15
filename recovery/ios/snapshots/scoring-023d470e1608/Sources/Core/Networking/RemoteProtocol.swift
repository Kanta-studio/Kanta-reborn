import Foundation

public enum GeloRemoteProtocol {
    public static let currentVersion: UInt16 = 2
}

public enum RemoteRole: String, Codable, Sendable {
    case host
    case controller
    case guest
}

public struct RemoteHello: Equatable, Codable, Sendable {
    public var appVersion: String
    public var role: RemoteRole

    public init(appVersion: String, role: RemoteRole) {
        self.appVersion = appVersion
        self.role = role
    }
}

public enum RemoteCommandAction: String, Codable, Sendable {
    case play
    case pause
    case stop
    case next
    case previous
    case seek
    case setVolume
    case setPitch
    case setTempo
    case enqueue
    case removeQueueItem
}

public struct RemoteCommand: Equatable, Codable, Sendable {
    public var action: RemoteCommandAction
    public var milliseconds: Int64?
    public var floatValue: Float?
    public var intValue: Int?
    public var doubleValue: Double?
    public var songID: SongID?
    public var queueItemID: UUID?

    public init(
        action: RemoteCommandAction,
        milliseconds: Int64? = nil,
        floatValue: Float? = nil,
        intValue: Int? = nil,
        doubleValue: Double? = nil,
        songID: SongID? = nil,
        queueItemID: UUID? = nil
    ) {
        self.action = action
        self.milliseconds = milliseconds
        self.floatValue = floatValue
        self.intValue = intValue
        self.doubleValue = doubleValue
        self.songID = songID
        self.queueItemID = queueItemID
    }

    public init(command: KaraokeCommand) {
        switch command {
        case .play: self.init(action: .play)
        case .pause: self.init(action: .pause)
        case .stop: self.init(action: .stop)
        case .next: self.init(action: .next)
        case .previous: self.init(action: .previous)
        case let .seek(milliseconds): self.init(action: .seek, milliseconds: milliseconds)
        case let .setVolume(value): self.init(action: .setVolume, floatValue: value)
        case let .setPitch(semitones): self.init(action: .setPitch, intValue: semitones)
        case let .setTempo(ratio): self.init(action: .setTempo, doubleValue: ratio)
        case let .enqueue(songID): self.init(action: .enqueue, songID: songID)
        case let .removeQueueItem(id): self.init(action: .removeQueueItem, queueItemID: id)
        }
    }

    public func domainCommand() throws -> KaraokeCommand {
        switch action {
        case .play: return .play
        case .pause: return .pause
        case .stop: return .stop
        case .next: return .next
        case .previous: return .previous
        case .seek:
            guard let milliseconds else { throw RemoteProtocolError.missingField("milliseconds") }
            guard milliseconds >= 0 else { throw RemoteProtocolError.invalidField("milliseconds") }
            return .seek(milliseconds: milliseconds)
        case .setVolume:
            guard let floatValue else { throw RemoteProtocolError.missingField("floatValue") }
            guard floatValue.isFinite, (0...1).contains(floatValue) else { throw RemoteProtocolError.invalidField("floatValue") }
            return .setVolume(floatValue)
        case .setPitch:
            guard let intValue else { throw RemoteProtocolError.missingField("intValue") }
            guard (-12...12).contains(intValue) else { throw RemoteProtocolError.invalidField("intValue") }
            return .setPitch(semitones: intValue)
        case .setTempo:
            guard let doubleValue else { throw RemoteProtocolError.missingField("doubleValue") }
            guard doubleValue.isFinite, (0.5...2.0).contains(doubleValue) else { throw RemoteProtocolError.invalidField("doubleValue") }
            return .setTempo(ratio: doubleValue)
        case .enqueue:
            guard let songID else { throw RemoteProtocolError.missingField("songID") }
            return .enqueue(songID: songID)
        case .removeQueueItem:
            guard let queueItemID else { throw RemoteProtocolError.missingField("queueItemID") }
            return .removeQueueItem(queueItemID)
        }
    }
}

public struct RemotePairingRequest: Equatable, Codable, Sendable {
    public var code: String

    public init(code: String) {
        self.code = code
    }
}

public struct RemotePairingAccepted: Equatable, Codable, Sendable {
    public var sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}

public struct RemoteSongSearchRequest:
    Equatable,
    Codable,
    Sendable
{
    public var requestID: UUID
    public var query: String
    public var limit: Int

    public init(
        requestID: UUID = UUID(),
        query: String,
        limit: Int = 100
    ) {
        self.requestID = requestID
        self.query = query
        self.limit = limit
    }
}

public struct RemoteSongSearchResults:
    Equatable,
    Codable,
    Sendable
{
    public var requestID: UUID
    public var songs: [LibrarySong]

    public init(
        requestID: UUID,
        songs: [LibrarySong]
    ) {
        self.requestID = requestID
        self.songs = songs
    }
}

public struct RemoteFailure: Equatable, Codable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum RemoteBody: Equatable, Sendable {
    case hello(RemoteHello)
    case pair(RemotePairingRequest)
    case paired(RemotePairingAccepted)
    case command(RemoteCommand)
    case search(RemoteSongSearchRequest)
    case searchResults(RemoteSongSearchResults)
    case snapshot(KaraokeSnapshot)
    case failure(RemoteFailure)
    case ping
    case pong
}

extension RemoteBody: Codable {
    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum Kind: String, Codable { case hello, pair, paired, command, search, searchResults, snapshot, failure, ping, pong }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .hello: self = .hello(try container.decode(RemoteHello.self, forKey: .payload))
        case .pair: self = .pair(try container.decode(RemotePairingRequest.self, forKey: .payload))
        case .paired: self = .paired(try container.decode(RemotePairingAccepted.self, forKey: .payload))
        case .command: self = .command(try container.decode(RemoteCommand.self, forKey: .payload))
        case .search: self = .search(try container.decode(RemoteSongSearchRequest.self, forKey: .payload))
        case .searchResults: self = .searchResults(try container.decode(RemoteSongSearchResults.self, forKey: .payload))
        case .snapshot: self = .snapshot(try container.decode(KaraokeSnapshot.self, forKey: .payload))
        case .failure: self = .failure(try container.decode(RemoteFailure.self, forKey: .payload))
        case .ping: self = .ping
        case .pong: self = .pong
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .hello(value):
            try container.encode(Kind.hello, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .pair(value):
            try container.encode(Kind.pair, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .paired(value):
            try container.encode(Kind.paired, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .command(value):
            try container.encode(Kind.command, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .search(value):
            try container.encode(Kind.search, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .searchResults(value):
            try container.encode(Kind.searchResults, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .snapshot(value):
            try container.encode(Kind.snapshot, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .failure(value):
            try container.encode(Kind.failure, forKey: .type)
            try container.encode(value, forKey: .payload)
        case .ping:
            try container.encode(Kind.ping, forKey: .type)
        case .pong:
            try container.encode(Kind.pong, forKey: .type)
        }
    }
}

public struct RemoteEnvelope: Equatable, Codable, Sendable {
    public var protocolVersion: UInt16
    public var id: UUID
    public var body: RemoteBody

    public init(
        protocolVersion: UInt16 = GeloRemoteProtocol.currentVersion,
        id: UUID = UUID(),
        body: RemoteBody
    ) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.body = body
    }
}

public enum RemoteProtocolError: Error, Equatable, Sendable {
    case missingField(String)
    case invalidField(String)
    case unsupportedVersion(UInt16)
}

