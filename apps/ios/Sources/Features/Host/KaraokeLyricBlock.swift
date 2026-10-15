import GeloKaraokeCore
import SwiftUI

/// The same playback-synchronized lyric surface is used inline and fullscreen.
struct KaraokeLyricBlock: View {
    let page: KaraokeLyricPage

    var body: some View {
        GeometryReader { proxy in
            let fontSize = min(64, max(28, min(proxy.size.width * 0.085, proxy.size.height * 0.19)))
            VStack(spacing: max(8, fontSize * 0.22)) {
                ForEach(Array(page.lines.enumerated()), id: \.offset) { _, line in
                    lyricText(line)
                        .font(.system(size: fontSize, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black, radius: 0, x: -1.5, y: -1.5)
                        .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                        .accessibilityLabel(line.text)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }

    private func lyricText(_ line: KaraokeLyricLine) -> Text {
        line.fragments.reduce(Text("")) { result, fragment in
            result + Text(fragment.text).foregroundColor(
                fragment.milliseconds <= page.positionMilliseconds
                    ? Color.yellow
                    : .white
            )
        }
    }
}

struct KantaStageWatermark: View {
    var body: some View {
        Text("KANTA")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 1, y: 1)
            .opacity(0.75)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

