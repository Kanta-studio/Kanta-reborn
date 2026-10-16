import Foundation
import SwiftUI

enum KantaYouTubeVideoLink {
    static func canonical(_ candidate: String) -> URL? {
        guard candidate.utf8.count <= 2048,
              let components = URLComponents(
                string: candidate.trimmingCharacters(in: .whitespacesAndNewlines)
              ),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil else { return nil }

        let path = components.percentEncodedPath
        guard path.utf8.count <= 128 else { return nil }
        let id: String
        if ["youtu.be", "www.youtu.be"].contains(host) {
            guard path.hasPrefix("/") else { return nil }
            id = String(path.dropFirst())
        } else if [
            "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
            "youtube-nocookie.com", "www.youtube-nocookie.com"
        ].contains(host) {
            if path == "/watch" {
                guard let query = components.percentEncodedQuery, query.utf8.count <= 2048
                else { return nil }
                let ids = query.split(separator: "&", omittingEmptySubsequences: false)
                    .filter { $0.hasPrefix("v=") }
                guard ids.count == 1 else { return nil }
                id = String(ids[0].dropFirst(2))
            } else if let prefix = ["/shorts/", "/live/", "/embed/"]
                .first(where: path.hasPrefix) {
                id = String(path.dropFirst(prefix.count))
            } else { return nil }
        } else { return nil }

        guard id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
        else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=" + id)
    }
}

@MainActor
struct KantaYouTubeLinkView: View {
    @State private var videoLink = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("Watch on YouTube") {
                TextField("Paste a YouTube video link", text: $videoLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("youtube.link")

                Button("Open YouTube") {
                    guard let url = KantaYouTubeVideoLink.canonical(videoLink) else { return }
                    openURL(url)
                }
                .accessibilityIdentifier("youtube.open")
                .disabled(KantaYouTubeVideoLink.canonical(videoLink) == nil)
            }

            Section("YouTube playback notice") {
                Text("YouTube may show ads before or during videos, interrupting your karaoke. YouTube Premium can provide ad-free playback when supported and signed in. Ads and Premium benefits are controlled by YouTube, not KANTA.")
                    .accessibilityIdentifier("youtube.adNotice")
                Text("Videos open in the official YouTube app or browser outside KANTA. This feature does not download media or add YouTube videos to the karaoke reservation queue.")
                Link("YouTube Premium information",
                     destination: URL(string: "https://support.google.com/youtube/answer/6308116")!)
            }
        }
        .navigationTitle("YouTube (online)")
    }
}
