import SwiftUI

@MainActor
struct FullscreenKaraokePlayerView: View {
    @ObservedObject var model: HostViewModel
    let backgroundsEnabled: Bool
    let selectedPreset: KantaBuiltInVisualPreset

    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = false
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
                showsWatermark: false
            )
            .clipShape(Rectangle())
            .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { controlsVisible.toggle() }
                    KaraokeLyricBlock(page: model.lyricPage)
                        .padding(.horizontal, 24)
                        .padding(.vertical, proxy.size.height < 500 ? 60 : 150)

                    VStack {
                        if controlsVisible {
                            topBar
                            Spacer(minLength: 8)
                            playbackOverlay
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
                .overlay(alignment: .bottomTrailing) {
                    KantaStageWatermark()
                        .padding(.trailing, 18)
                        .padding(.bottom, 12)
                }
                .overlay(alignment: .topTrailing) {
                    if !controlsVisible {
                        Button {
                            controlsVisible = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Show playback controls")
                        .padding(12)
                    }
                }
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
