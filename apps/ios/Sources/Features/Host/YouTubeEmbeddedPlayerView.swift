import GeloKaraokeCore
import SwiftUI
import WebKit

/// Visible official YouTube embed. This view never owns KANTA's playback queue.
@MainActor
struct YouTubeEmbeddedPlayerView: UIViewRepresentable {
    let reference: YouTubeVideoReference

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        view.isInspectable = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedID != reference.videoID else { return }
        context.coordinator.loadedID = reference.videoID
        let url = URL(string: "https://www.youtube-nocookie.com/embed/\(reference.videoID)?playsinline=1")!
        view.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)

        view.navigationDelegate = nil
        coordinator.loadedID = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedID: String?
        private let allowedHosts: Set<String> = [
            "www.youtube-nocookie.com", "youtube-nocookie.com",
            "www.youtube.com", "youtube.com"
        ]

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url,
                  url.scheme == "https",
                  let host = url.host?.lowercased(),
                  allowedHosts.contains(host) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
