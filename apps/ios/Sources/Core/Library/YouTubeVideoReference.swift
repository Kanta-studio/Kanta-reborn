import Foundation

/// Link-only metadata. No media is downloaded or made playable by this type.
public struct YouTubeVideoReference: Hashable, Codable, Sendable {
    public let videoID: String

    public init?(url text: String) {
        guard let url = URLComponents(string: text),
              url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let host = url.host?.lowercased(),
              !url.percentEncodedPath.contains("%") else { return nil }
        let path = url.path
        let candidate: String?
        if host == "youtu.be" {
            guard url.query == nil else { return nil }
            candidate = path.range(of: "^/[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
                ? String(path.dropFirst()) : nil
        } else if ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(host) {
            if path == "/watch" {
                let videos = (url.queryItems ?? []).filter { $0.name == "v" }
                candidate = videos.count == 1 ? videos[0].value : nil
            } else {
                candidate = path.range(of: "^/(embed|shorts)/[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
                    ? String(path.split(separator: "/").last ?? "") : nil
            }
        } else { return nil }
        guard let candidate, candidate.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        videoID = candidate
    }
}
