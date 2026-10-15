import GeloKaraokeCore
import SwiftUI

@MainActor
struct InAppControlCenterView: View {
    @ObservedObject var model: HostViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var backgroundsEnabled: Bool
    @Binding var selectedPreset: KantaBuiltInVisualPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            nowPlaying
            Divider()
            search
            Divider()
            queue
            Divider()
            playback
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nowPlaying: some View {
        Group {
            if let song = model.snapshot.nowPlaying {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                GeloVisualStyle.accent,
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOW SINGING")
                                .font(.caption2.weight(.black))
                                .tracking(1.4)
                                .foregroundStyle(GeloVisualStyle.accent)

                            Text(song.title)
                                .font(
                                    .system(
                                        size: 26,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)

                            if let artist = song.artist,
                               !artist.isEmpty {
                                Text(artist)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    if let duration =
                        model.snapshot.durationMilliseconds,
                       duration > 0 {
                        ProgressView(
                            value: Double(
                                min(
                                    max(
                                        model.snapshot
                                            .positionMilliseconds,
                                        0
                                    ),
                                    duration
                                )
                            ),
                            total: Double(duration)
                        )
                        .tint(GeloVisualStyle.accent)

                        HStack {
                            Text(
                                timeText(
                                    model.snapshot
                                        .positionMilliseconds
                                )
                            )
                            Spacer()
                            Text(timeText(duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 18) {
                        Spacer(minLength: 0)

                        transportButton(
                            systemName: "backward.fill",
                            accessibilityLabel: "Previous song"
                        ) {
                            Task { await model.previous() }
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
                            .font(.system(size: 25, weight: .bold))
                            .frame(width: 62, height: 62)
                            .background(
                                GeloVisualStyle.accent,
                                in: Circle()
                            )
                            .foregroundStyle(.white)
                            .shadow(
                                color: GeloVisualStyle.accent
                                    .opacity(0.30),
                                radius: 12,
                                y: 5
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            model.snapshot.transport == .playing
                                ? "Pause"
                                : "Play"
                        )

                        transportButton(
                            systemName: "forward.fill",
                            accessibilityLabel: "Next song"
                        ) {
                            Task { await model.next() }
                        }

                        Spacer(minLength: 0)
                    }
                    .disabled(!model.isAvailable)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            GeloVisualStyle.accent.opacity(0.14),
                            Color.purple.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        GeloVisualStyle.accent.opacity(0.16),
                        lineWidth: 1
                    )
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "mic")
                        .foregroundStyle(GeloVisualStyle.accent)
                    Text("Choose a song to start the karaoke stage")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .thinMaterial,
                    in: RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
            }
        }
    }

    private func transportButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 46, height: 46)
                .background(
                    .thinMaterial,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func timeText(_ milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        return String(
            format: "%d:%02d",
            totalSeconds / 60,
            totalSeconds % 60
        )
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Find a song", systemImage: "magnifyingglass")
                .font(.headline)

            TextField(
                "Search title, artist, or code",
                text: $model.query
            )
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: model.query) {
                Task { await model.search() }
            }

            if model.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading library…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if model.songs.isEmpty {
                Text(
                    model.query.isEmpty
                        ? "No playable songs in the connected library."
                        : "No songs match this search."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.songs.prefix(8))) { song in
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                            Text(song.mediaKind.rawValue.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .layoutPriority(1)

                        reserveButton(for: song)
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                }

                if model.songs.count > 8 {
                    Text(
                        "Showing 8 of \(model.songs.count) matches. " +
                        "Refine the search to narrow the list."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func reserveButton(
        for song: LibrarySong
    ) -> some View {
        if horizontalSizeClass == .compact {
            Button {
                Task { await model.enqueue(song) }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background(
                        GeloVisualStyle.accent.opacity(0.12),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(GeloVisualStyle.accent)
            .fixedSize()
            .accessibilityLabel("Reserve " + song.title)
        } else {
            Button {
                Task { await model.enqueue(song) }
            } label: {
                Label(
                    "Reserve",
                    systemImage: "plus.circle"
                )
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(GeloVisualStyle.accent)
                .frame(width: 104, height: 38)
                .background(
                    GeloVisualStyle.accent.opacity(0.12),
                    in: Capsule()
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(width: 104, height: 38)
            .accessibilityLabel("Reserve " + song.title)
        }
    }

    private var queue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "Up Next (\(model.snapshot.queue.count))",
                systemImage: "text.line.first.and.arrowtriangle.forward"
            )
            .font(.headline)

            if model.snapshot.queue.isEmpty {
                Text("Queue is empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.snapshot.queue.prefix(6))) { item in
                    HStack(spacing: 10) {
                        Text(item.song.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .layoutPriority(1)

                        Button(role: .destructive) {
                            Task {
                                await model.removeQueueItem(item.id)
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            "Remove " + item.song.title + " from queue"
                        )
                    }
                }

                if model.snapshot.queue.count > 6 {
                    Text(
                        "+\(model.snapshot.queue.count - 6) more queued"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var playback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Playback", systemImage: "waveform")
                .font(.headline)

            Toggle(isOn: $backgroundsEnabled) {
                Label(
                    "Stage visuals",
                    systemImage: "photo.on.rectangle"
                )
            }

            Text(
                "Optional. Turn this off for a clean lyric-only stage. " +
                "Your selected media stays unchanged."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if backgroundsEnabled {
                Menu {
                    Section("Images · 10 backgrounds") {
                        ForEach(
                            KantaBuiltInVisualPreset.stillPresets
                        ) { preset in
                            Button {
                                selectedPreset = preset
                            } label: {
                                if selectedPreset == preset {
                                    Label(
                                        preset.displayName,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(preset.displayName)
                                }
                            }
                        }
                    }

                    Section("Animated · 10 HQ presets") {
                        ForEach(
                            KantaBuiltInVisualPreset.motionPresets
                        ) { preset in
                            Button {
                                selectedPreset = preset
                            } label: {
                                if selectedPreset == preset {
                                    Label(
                                        preset.displayName,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(preset.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label(
                            selectedPreset.displayName,
                            systemImage:
                                selectedPreset.kind == .motion
                                ? "sparkles.tv"
                                : "photo"
                        )
                        .lineLimit(2)
                        .layoutPriority(1)
                        Spacer()
                        Text(selectedPreset.categoryLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Stage visual preset, " +
                    selectedPreset.displayName
                )

                Text(
                    "Ten original background images are included for offline use. " +
                    "Animated presets are generated on device. " +
                    "Your imported media stays unchanged."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(model.snapshot.volume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: {
                            Double(model.snapshot.volume)
                        },
                        set: { value in
                            Task {
                                await model.setVolume(Float(value))
                            }
                        }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Playback volume")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    pitchStepper
                    tempoStepper
                }

                VStack(spacing: 10) {
                    pitchStepper
                    tempoStepper
                }
            }
        }
    }

    private var pitchStepper: some View {
        compactStepper(
            title: "Pitch",
            value: "\(model.snapshot.pitchSemitones) st",
            decrease: {
                Task { await model.changePitch(by: -1) }
            },
            increase: {
                Task { await model.changePitch(by: 1) }
            }
        )
    }

    private var tempoStepper: some View {
        compactStepper(
            title: "Tempo",
            value: String(
                format: "%.2fx",
                model.snapshot.tempoRatio
            ),
            decrease: {
                Task { await model.changeTempo(by: -0.05) }
            },
            increase: {
                Task { await model.changeTempo(by: 0.05) }
            }
        )
    }

    private func compactStepper(
        title: String,
        value: String,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)

                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 48)

                Button(action: increase) {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }
}
