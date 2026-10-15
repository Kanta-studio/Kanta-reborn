import Foundation

public struct SongID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case midi
    case kar
    case mp3
    case wav
    case legacyContainer
    case unknown
}

public struct LibrarySong: Identifiable, Hashable, Codable, Sendable {
    public let id: SongID
    public var code: String?
    public var title: String
    public var artist: String?
    public var mediaKind: MediaKind

    public init(
        id: SongID,
        code: String? = nil,
        title: String,
        artist: String? = nil,
        mediaKind: MediaKind
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.artist = artist
        self.mediaKind = mediaKind
    }
}

public struct QueueItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let song: LibrarySong
    public let requestedBy: String?

    public init(id: UUID = UUID(), song: LibrarySong, requestedBy: String? = nil) {
        self.id = id
        self.song = song
        self.requestedBy = requestedBy
    }
}

