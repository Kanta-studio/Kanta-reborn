import Foundation

public enum KaraokeBackgroundKind: String, Hashable, Sendable {
    case image
    case video
}

public struct KaraokeBackgroundAsset: Hashable, Sendable {
    public let url: URL
    public let kind: KaraokeBackgroundKind

    public init(
        url: URL,
        kind: KaraokeBackgroundKind
    ) {
        self.url = url
        self.kind = kind
    }
}

