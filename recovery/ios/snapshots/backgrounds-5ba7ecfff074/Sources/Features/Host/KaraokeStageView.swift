import AVFoundation
import LibraryStorage
import GeloKaraokeCore
import SwiftUI
import UIKit

@MainActor
struct KaraokeStageView: View {
    let asset: KaraokeBackgroundAsset?
    let builtInPreset: KantaBuiltInVisualPreset?
    let isPlaying: Bool
    var lyricPage = KaraokeLyricPage()
    var showsWatermark = true

    var body: some View {
        ZStack {
            background
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            KaraokeLyricBlock(page: lyricPage)
                .padding(.horizontal, 22)
                .padding(.vertical, 42)
        }
        .overlay(alignment: .bottomTrailing) {
            if showsWatermark {
                KantaStageWatermark().padding(14)
            }
        }
        .background(.black)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var background: some View {
        if let builtInPreset {
            KantaBuiltInVisualView(preset: builtInPreset)
        } else {
            switch asset?.kind {
        case .some(.image):
            if let url = asset?.url {
                LocalBackgroundImage(url: url)
            }
        case .some(.video):
            if let url = asset?.url {
                LoopingVideoBackground(
                    url: url,
                    isPlaying: isPlaying
                )
            }
        case .none:
            Color.black
                .overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@MainActor
struct LocalBackgroundImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: url) {
            image = nil

            let sourceURL = url
            let data = await Task.detached(
                priority: .utility
            ) {
                try? Data(
                    contentsOf: sourceURL,
                    options: [.mappedIfSafe]
                )
            }.value

            guard !Task.isCancelled,
                  let data else {
                return
            }

            image = UIImage(data: data)
        }
    }
}

@MainActor
private struct LoopingVideoBackground: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.configure(
            url: url,
            isPlaying: isPlaying
        )
        return view
    }

    func updateUIView(
        _ uiView: LoopingPlayerView,
        context: Context
    ) {
        uiView.configure(
            url: url,
            isPlaying: isPlaying
        )
    }

    static func dismantleUIView(
        _ uiView: LoopingPlayerView,
        coordinator: ()
    ) {
        uiView.stop()
    }
}

@MainActor
private final class LoopingPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspectFill
    }

    func configure(
        url: URL,
        isPlaying: Bool
    ) {
        if currentURL != url {
            stop()

            let player = AVQueuePlayer()
            player.isMuted = true
            playerLayer.player = player

            looper = AVPlayerLooper(
                player: player,
                templateItem: AVPlayerItem(url: url)
            )
            self.player = player
            currentURL = url
        }

        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func stop() {
        player?.pause()
        player?.removeAllItems()
        playerLayer.player = nil
        looper = nil
        player = nil
        currentURL = nil
    }
}
