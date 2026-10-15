import GeloKaraokeCore
import LocalNetworkControl
import MicrophoneScoring
import SwiftUI

@MainActor
struct HostView: View {
    @StateObject private var model: HostViewModel
    @ObservedObject private var networkHost: BonjourHostAdvertiser
    @ObservedObject private var microphonePitchMonitor:
        MicrophonePitchMonitor
    @ObservedObject private var settings: KantaUserSettings
    @State private var showControlCenter =
        ProcessInfo.processInfo.environment[
            "KANTA_CONTROL_EXPANDED"
        ] == "1"
    @State private var showingFullscreenPlayer =
        ProcessInfo.processInfo.environment[
            "KANTA_FULLSCREEN"
        ] == "1"

    init(services: AppServices) {
        _networkHost = ObservedObject(
            wrappedValue: services.networkHost
        )
        _microphonePitchMonitor = ObservedObject(
            wrappedValue: services.microphonePitchMonitor
        )
        _settings = ObservedObject(
            wrappedValue: services.settings
        )
        _model = StateObject(
            wrappedValue: HostViewModel(
                controller: services.controller,
                library: services.library
            )
        )
    }

    var body: some View {
        List {
            Section {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControlCenter.toggle()
                    }
                } label: {
                    HStack {
                        Label(
                            KantaTerminology.control,
                            systemImage: "slider.horizontal.3"
                        )
                        .font(.headline)

                        Spacer()

                        Image(
                            systemName:
                                showControlCenter
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(
                    showControlCenter ? "Expanded" : "Collapsed"
                )

                if showControlCenter {
                    InAppControlCenterView(
                        model: model,
                        backgroundsEnabled: $settings.stageVisualsEnabled,
                        selectedPreset: $settings.selectedVisualPreset
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: 12,
                            leading: 14,
                            bottom: 12,
                            trailing: 14
                        )
                    )
                }
            } footer: {
                Text(controlFooterText)
            }

            Section(secondDeviceControlTitle) {
                LabeledContent(
                    "Bonjour",
                    value: networkHostStatusText
                )

                LabeledContent("Pairing PIN") {
                    Text(networkHost.pairingCode.value)
                        .font(.title3.monospacedDigit())
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                        .accessibilityLabel("Pairing PIN")
                        .accessibilityValue(
                            networkHost.pairingCode.value
                        )
                }

                LabeledContent(
                    "Paired remotes",
                    value: String(
                        networkHost.pairedControllerCount
                    )
                )

                Button("Rotate Pairing PIN") {
                    networkHost.rotatePairingCode()
                }

                Text(secondDeviceControlHelp)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let completedScore = model.completedScore {
                Section("Last Score") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completedScore.song.title)
                                    .font(.headline)
                                Text(
                                    String(
                                        format: "%.0f / 100",
                                        completedScore.score.overall
                                    )
                                )
                                .font(.largeTitle.bold())
                            }

                            Spacer()

                            Button {
                                model.completedScore = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Dismiss last score")
                        }

                        HStack {
                            LabeledContent(
                                "Pitch",
                                value: String(
                                    format: "%.0f%%",
                                    completedScore.score.pitchAccuracy
                                )
                            )
                            LabeledContent(
                                "Coverage",
                                value: String(
                                    format: "%.0f%%",
                                    completedScore.score.timingCoverage
                                )
                            )
                        }
                        .font(.subheadline)

                        Text(
                            "\(completedScore.observationCount) scored samples"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Now Playing") {
                if let song = model.snapshot.nowPlaying {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.headline)
                        Text(
                            timeText(
                                position:
                                    model.snapshot
                                        .positionMilliseconds,
                                duration:
                                    model.snapshot
                                        .durationMilliseconds
                            )
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Nothing playing")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        Task {
                            await model.previous()
                        }
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .accessibilityLabel("Previous song")

                    Spacer()

                    Button {
                        Task {
                            await model.togglePlayPause()
                        }
                    } label: {
                        Image(
                            systemName:
                                model.snapshot.transport
                                    == .playing
                                ? "pause.fill"
                                : "play.fill"
                        )
                        .font(.title2)
                    }
                    .accessibilityLabel(
                        model.snapshot.transport == .playing
                            ? "Pause"
                            : "Play"
                    )

                    Spacer()

                    Button {
                        Task {
                            await model.next()
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .accessibilityLabel("Next song")
                }
                .buttonStyle(.borderless)
                .disabled(!model.isAvailable)
            }

            if model.snapshot.nowPlaying != nil {
                Section("Stage") {
                    ZStack(alignment: .topTrailing) {
                        KaraokeStageView(
                            asset:
                                settings.stageVisualsEnabled
                                ? model.backgroundAsset
                                : nil,
                            builtInPreset:
                                settings.stageVisualsEnabled
                                ? settings.selectedVisualPreset
                                : nil,
                            isPlaying:
                                model.snapshot.transport == .playing,
                            lyricPage: model.lyricPage
                        )
                        .frame(
                            minHeight: 220,
                            idealHeight: 320,
                            maxHeight: 420
                        )

                        Button {
                            showingFullscreenPlayer = true
                        } label: {
                            Image(
                                systemName:
                                    "arrow.up.left.and.arrow.down.right"
                            )
                            .font(.headline)
                            .padding(11)
                            .background(
                                .ultraThinMaterial,
                                in: Circle()
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .accessibilityLabel("Open fullscreen player")
                    }
                }
            }

            if model.hasLyrics {
                Section("Lyrics") {
                    if let previous =
                        model.lyricWindow.previous {
                        Text(previous.text)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .center
                            )
                            .multilineTextAlignment(.center)
                    }

                    if let current =
                        model.lyricWindow.current {
                        Text(current.text)
                            .font(
                                .system(
                                    size: 34,
                                    weight: .heavy,
                                    design: .rounded
                                )
                            )
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .center
                            )
                            .multilineTextAlignment(.center)
                            .accessibilityLabel(
                                "Current lyric: " + current.text
                            )
                    }

                    if let next = model.lyricWindow.next {
                        Text(next.text)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .center
                            )
                            .multilineTextAlignment(.center)
                    }
                }
            }

            if settings.scoringEnabled {
                Section("Scoring") {
                    LabeledContent(
                        "Microphone",
                        value: microphoneStatusText
                    )

                    LabeledContent(
                        "Song target",
                        value: scoringTargetText
                    )

                    if let score = model.liveScore {
                        LabeledContent(
                            "Live score",
                            value: String(
                                format: "%.0f / 100",
                                score.overall
                            )
                        )
                        LabeledContent(
                            "Pitch accuracy",
                            value: String(
                                format: "%.0f%%",
                                score.pitchAccuracy
                            )
                        )
                        LabeledContent(
                            "Timing coverage",
                            value: String(
                                format: "%.0f%%",
                                score.timingCoverage
                            )
                        )
                        LabeledContent(
                            "Scored samples",
                            value: String(
                                model.scoringObservationCount
                            )
                        )
                    }

                    if let observation =
                        microphonePitchMonitor.observation {
                        LabeledContent(
                            "Detected pitch",
                            value: String(
                                format: "%.1f Hz",
                                observation.frequencyHz
                            )
                        )

                        if let note =
                            observation.nearestMIDINote {
                            LabeledContent(
                                "Nearest MIDI note",
                                value: String(note)
                            )
                        }

                        if let cents =
                            observation.centsFromNearestNote {
                            LabeledContent(
                                "Pitch offset",
                                value: String(
                                    format: "%+.0f cents",
                                    cents
                                )
                            )
                        }

                        LabeledContent(
                            "Confidence",
                            value: String(
                                format: "%.0f%%",
                                observation.confidence * 100
                            )
                        )
                    }

                    Stepper(
                        value: Binding(
                            get: {
                                model.scoringLatencyMilliseconds
                            },
                            set: { value in
                                model.setScoringLatencyMilliseconds(
                                    value
                                )
                                settings.scoringLatencyMilliseconds =
                                    Int(value)
                            }
                        ),
                        in: -500...1_500,
                        step: 10
                    ) {
                        LabeledContent(
                            "Latency compensation",
                            value:
                                "\(model.scoringLatencyMilliseconds) ms"
                        )
                    }

                    if model.scoringObservationCount > 0 {
                        Button("Reset Live Score") {
                            model.resetLiveScore()
                        }
                    }

                    if microphonePitchMonitor.status != .running {
                        Button("Retry Microphone") {
                            Task {
                                await microphonePitchMonitor.start()
                            }
                        }
                        .disabled(
                            microphonePitchMonitor.status
                                == .requestingPermission
                        )
                    }

                    Text(
                        "Pitch detection and scoring run locally; audio " +
                        "is not recorded or uploaded. Live scoring uses " +
                        "validated MIDI melody targets and playback-time " +
                        "alignment. Device-specific latency calibration " +
                        "and performance profiling remain required for " +
                        "release-grade scoring accuracy."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Playback") {
                LabeledContent(
                    "Volume",
                    value:
                        "\(Int(model.snapshot.volume * 100))%"
                )
                Slider(
                    value: Binding(
                        get: {
                            Double(model.snapshot.volume)
                        },
                        set: { value in
                            Task {
                                await model.setVolume(
                                    Float(value)
                                )
                            }
                        }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Playback volume")
                .accessibilityValue(
                    "\(Int(model.snapshot.volume * 100)) percent"
                )

                HStack {
                    Button("Pitch −") {
                        Task {
                            await model.changePitch(by: -1)
                        }
                    }
                    Spacer()
                    Text(
                        "\(model.snapshot.pitchSemitones) st"
                    )
                    .monospacedDigit()
                    Spacer()
                    Button("Pitch +") {
                        Task {
                            await model.changePitch(by: 1)
                        }
                    }
                }

                HStack {
                    Button("Tempo −") {
                        Task {
                            await model.changeTempo(by: -0.05)
                        }
                    }
                    Spacer()
                    Text(
                        String(
                            format: "%.2fx",
                            model.snapshot.tempoRatio
                        )
                    )
                    .monospacedDigit()
                    Spacer()
                    Button("Tempo +") {
                        Task {
                            await model.changeTempo(by: 0.05)
                        }
                    }
                }
            }

            Section(
                "Queue (\(model.snapshot.queue.count))"
            ) {
                if model.snapshot.queue.isEmpty {
                    Text("Queue is empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.snapshot.queue) { item in
                        Text(item.song.title)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await model.removeQueueItem(
                                            item.id
                                        )
                                    }
                                } label: {
                                    Label(
                                        "Remove",
                                        systemImage: "trash"
                                    )
                                }
                            }
                    }
                }
            }

            Section("Songs") {
                if model.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading library…")
                    }
                } else if model.songs.isEmpty {
                    ContentUnavailableView(
                        model.query.isEmpty
                            ? "No Playable Songs"
                            : "No Matching Songs",
                        systemImage: "music.note",
                        description: Text(
                            model.query.isEmpty
                                ? "Add a folder containing MIDI/KAR, MP3, WAV, " +
                                  "or a compatible indexed library in Song Library."
                                : "Change the search in CONTROL to show more songs."
                        )
                    )
                } else {
                    ForEach(model.songs) { song in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title)
                                Text(
                                    song.mediaKind.rawValue
                                        .uppercased()
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                Task {
                                    await model.enqueue(song)
                                }
                            } label: {
                                Label(
                                    "Reserve",
                                    systemImage: "plus.circle"
                                )
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Reserve " + song.title
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Karaoke Host")
        .fullScreenCover(
            isPresented: $showingFullscreenPlayer
        ) {
            FullscreenKaraokePlayerView(
                model: model,
                backgroundsEnabled: settings.stageVisualsEnabled,
                selectedPreset: settings.selectedVisualPreset
            )
        }
        .onChange(of: settings.scoringEnabled) {
            model.setScoringEnabled(
                settings.scoringEnabled
            )

            if settings.scoringEnabled {
                Task {
                    await microphonePitchMonitor.start()
                }
            } else {
                microphonePitchMonitor.stop()
            }
        }
        .onChange(
            of: microphonePitchMonitor.observation
        ) {
            if let observation =
                microphonePitchMonitor.observation {
                model.ingestPitchObservation(observation)
            }
        }
        .task {
            if !isDemoMode {
                networkHost.start()
            }
            model.setScoringEnabled(
                settings.scoringEnabled
            )
            model.setScoringLatencyMilliseconds(
                Int64(settings.scoringLatencyMilliseconds)
            )

            if settings.scoringEnabled {
                await microphonePitchMonitor.start()
            }

            await model.run()
        }
        .onDisappear {
            microphonePitchMonitor.stop()
            if !isDemoMode {
                networkHost.stop()
            }
        }
        .alert(
            "Playback Error",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: {
                    if !$0 {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }



    private var isDemoMode: Bool {
        ProcessInfo.processInfo.environment[
            "KANTA_DEMO_MODE"
        ] == "1"
    }

    private var controlFooterText: String {
        "Open \(KantaTerminology.control) when you want to search, " +
        "manage the queue, or adjust playback. It expands inline and " +
        "does not cover the karaoke stage."
    }

    private var secondDeviceControlTitle: String {
        "Second-Device \(KantaTerminology.control) — Optional"
    }

    private var secondDeviceControlHelp: String {
        "A second phone or tablet can optionally control this session " +
        "over the local network. This is not required—the main device " +
        "has the full \(KantaTerminology.control) panel. The PIN stays " +
        "local and is not advertised through Bonjour."
    }

    private var scoringTargetText: String {
        guard let extraction =
            model.scoringTargetExtraction else {
            return model.snapshot.nowPlaying == nil
                ? "No song"
                : "Unavailable for this media"
        }

        switch extraction {
        case let .resolved(target):
            let source =
                target.evidence == .lyricBearingTrack
                ? "lyric track"
                : "named vocal track"
            return String(target.windows.count)
                + " notes · " + source

        case let .unavailable(reason):
            switch reason {
            case .noStrongCandidate:
                return "No validated melody track"
            case .multipleStrongCandidates:
                return "Ambiguous melody tracks"
            case .candidateIsPolyphonic:
                return "Target track is polyphonic"
            case .candidateUsesPitchBend:
                return "Pitch-bend target unsupported"
            case .malformedNoteLifecycle:
                return "Malformed target notes"
            case .noTargetNotes:
                return "No target notes"
            }
        }
    }

    private var microphoneStatusText: String {
        switch microphonePitchMonitor.status {
        case .idle:
            return "Off"
        case .requestingPermission:
            return "Requesting permission"
        case .running:
            return "Listening locally"
        case .denied:
            return "Permission denied"
        case let .failed(message):
            return "Unavailable: " + message
        }
    }

    private var networkHostStatusText: String {
        switch networkHost.status {
        case .idle:
            return "Off"
        case .starting:
            return "Starting"
        case .ready:
            return "Discoverable"
        case let .failed(message):
            return "Unavailable: " + message
        }
    }

    private func timeText(
        position: Int64,
        duration: Int64?
    ) -> String {
        let current = format(milliseconds: position)
        guard let duration else { return current }
        return current + " / " + format(milliseconds: duration)
    }

    private func format(milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(
            format: "%d:%02d",
            minutes,
            seconds
        )
    }
}
