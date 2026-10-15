import SwiftUI

@MainActor
struct FullscreenKaraokePlayerView: View {
    @ObservedObject var model: HostViewModel
    let backgroundsEnabled: Bool
    let selectedPreset: KantaBuiltInVisualPreset

    @Environment(\.dismiss) private var dismiss
    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            KaraokeStageView(
                asset:
                    backgroundsEnabled
                    ? model.backgroundAsset
                    : nil,
                builtInPreset:
                    backgroundsEnabled
                    ? selectedPreset
                    : nil,
                isPlaying:
                    model.snapshot.transport == .playing,
                currentLyric: nil
            )
            .clipShape(Rectangle())
            .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 16) {
                    topBar

                    Spacer(minLength: 24)

                    fullscreenLyrics(
                        availableWidth: proxy.size.width
                    )

                    playbackOverlay
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            scrubPosition = Double(
                model.snapshot.positionMilliseconds
            )
        }
        .onChange(of: model.snapshot.positionMilliseconds) {
            guard !isScrubbing else { return }
            scrubPosition = Double(
                model.snapshot.positionMilliseconds
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    GeloVisualStyle.accent.opacity(0.92),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("NOW SINGING")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(
                        Color.white.opacity(0.72)
                    )

                Text(
                    model.snapshot.nowPlaying?.title
                        ?? "KANTA"
                )
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                if let artist =
                    model.snapshot.nowPlaying?.artist,
                   !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(
                    systemName:
                        "arrow.down.right.and.arrow.up.left"
                )
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(
                    .ultraThinMaterial,
                    in: Circle()
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Exit fullscreen player")
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.48),
                    .black.opacity(0.24)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func fullscreenLyrics(
        availableWidth: CGFloat
    ) -> some View {
        let currentSize =
            min(max(availableWidth * 0.092, 40), 66)
        let nextSize =
            min(max(availableWidth * 0.044, 19), 30)

        if model.hasLyrics {
            VStack(spacing: 12) {
                if let current =
                    model.lyricWindow.current?.text,
                   !current.isEmpty {
                    Text(current)
                        .font(
                            .system(
                                size: currentSize,
                                weight: .heavy,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.62)
                        .shadow(
                            color: .black.opacity(0.95),
                            radius: 3,
                            y: 2
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(
                            "Current lyric: " + current
                        )
                }

                if let next =
                    model.lyricWindow.next?.text,
                   !next.isEmpty {
                    Text(next)
                        .font(
                            .system(
                                size: nextSize,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.58)
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(
                            "Next lyric: " + next
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.22),
                        .black.opacity(0.52)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
            )
        }
    }

    private var playbackOverlay: some View {
        VStack(spacing: 14) {
            if let duration =
                model.snapshot.durationMilliseconds,
               duration > 0 {
                Slider(
                    value: $scrubPosition,
                    in: 0...Double(duration),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            Task {
                                await model.seek(
                                    toMilliseconds:
                                        Int64(scrubPosition)
                                )
                            }
                        }
                    }
                )
                .tint(.white)

                HStack {
                    Text(
                        timeText(
                            Int64(scrubPosition)
                        )
                    )
                    Spacer()
                    Text(timeText(duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
            }

            HStack(spacing: 34) {
                Button {
                    Task { await model.previous() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                }

                Button {
                    Task { await model.togglePlayPause() }
                } label: {
                    Image(
                        systemName:
                            model.snapshot.transport == .playing
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .font(.system(size: 30, weight: .bold))
                    .frame(width: 64, height: 64)
                    .background(.white, in: Circle())
                    .foregroundStyle(.black)
                }

                Button {
                    Task { await model.next() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(16)
        .background(
            .black.opacity(0.42),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }

    private func timeText(_ milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        return String(
            format: "%d:%02d",
            totalSeconds / 60,
            totalSeconds % 60
        )
    }
}

