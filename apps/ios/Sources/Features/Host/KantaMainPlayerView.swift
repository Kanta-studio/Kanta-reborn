import GeloKaraokeCore
import SwiftUI

/// A projection of the existing Host model, never a second player or queue.
@MainActor
struct KantaMainPlayerView: View {
    @ObservedObject var model: HostViewModel
    @ObservedObject var camera: KantaCameraBackground
    @ObservedObject var presentationGate: KantaPresentationGate
    let backgroundsEnabled: Bool
    let selectedPreset: KantaBuiltInVisualPreset
    @Binding var singerName: String
    var microphoneBusy = false
    var onControls: () -> Void = {}
    var onMore: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeStageSheet: StageSheet?

    private enum StageSheet: String, Identifiable {
        case search, queue
        var id: String { rawValue }
    }
    @State private var transportBusy = false

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            ZStack {
                stageBackground
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                LinearGradient(colors: [.black.opacity(0.24), .clear, .black.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 8) {
                    header
                    Group {
                        if model.hasLyrics {
                            KaraokeLyricBlock(page: model.lyricPage)
                        } else {
                            VStack(spacing: 12) {
                                Text(model.snapshot.nowPlaying?.title ?? "Your stage is ready")
                                    .font(.system(size: wide ? 32 : 36, weight: .black, design: .rounded))
                                    .multilineTextAlignment(.center)
                                Text(model.snapshot.nowPlaying?.artist ?? "Search a song, reserve it, then tap Play.")
                                    .font(.headline).foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .shadow(color: .black, radius: 2)
                        }
                    }
                    .padding(.horizontal, wide ? 36 : 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let song = model.snapshot.nowPlaying {
                        Text(song.title + (song.artist.map { " · " + $0 } ?? ""))
                            .font(.caption).lineLimit(1).foregroundStyle(.white.opacity(0.8))
                            .accessibilityIdentifier("stage.currentSong")
                    }
                    controls(wide: wide)
                    HStack {
                        if let notice = model.sessionNotice {
                            Text(notice).font(.caption2).lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        KantaStageWatermark()
                    }
                }
                .padding(.horizontal, wide ? 18 : 16)
                .padding(.vertical, 8)

            }
            .foregroundStyle(.white)
        }
        .background(.black)
        .sheet(item: $activeStageSheet, onDismiss: {
            presentationGate.completeDismissal(.stage)
        }) { sheet in
            switch sheet {
            case .search:
                GeometryReader { geometry in
                    KantaStageSearchView(model: model, singerName: $singerName,
                                         microphoneBusy: microphoneBusy,
                                         onClose: { presentationGate.beginDismissal(.stage); activeStageSheet = nil })
                        .padding(12)
                        .frame(maxWidth: 760, maxHeight: .infinity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(GeloVisualStyle.pageBackground)
                }
                .preferredColorScheme(.dark)
                .presentationDetents([.large])
            case .queue:
                queueSheet
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { camera.stop() }
        }
        .onDisappear { camera.stop() }
        .alert("Camera BGV", isPresented: Binding(
            get: { camera.message != nil },
            set: { if !$0 { camera.message = nil } }
        )) {
            Button("OK", role: .cancel) { camera.message = nil }
        } message: { Text(camera.message ?? "") }
    }

    @ViewBuilder private var stageBackground: some View {
        if camera.isEnabled {
            KantaCameraPreview(capture: camera.capture)
        } else {
            KaraokeStageView(asset: backgroundsEnabled ? model.backgroundAsset : nil,
                             builtInPreset: backgroundsEnabled ? selectedPreset : nil,
                             isPlaying: model.snapshot.transport == .playing,
                             showsWatermark: false)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                KantaBrandMark(size: 30)
                Text("KANTA").font(.title3.bold()).foregroundStyle(GeloVisualStyle.gold)
            }
            Spacer(minLength: 0)
            if camera.isEnabled || camera.isStarting {
                Button { camera.stop() } label: {
                    Label(camera.isStarting ? "Cancel camera" : "Stop camera", systemImage: "video.slash")
                        .font(.caption.bold()).padding(10)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                .accessibilityHint("Stops live front-camera background. No video is saved.")
            }
            Button { camera.stop(); onControls() } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("CONTROL")
            .accessibilityIdentifier("stage.controls")
        }
    }

    @ViewBuilder private func controls(wide: Bool) -> some View {
        if wide {
            HStack(spacing: 20) {
                searchButton
                queueButton
                playButton
                nextButton
                cameraButton
                moreButton
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        } else {
            VStack(spacing: 16) {
                HStack(spacing: 30) { playButton; nextButton }
                HStack { searchButton; Spacer(); queueButton; Spacer(); cameraButton; Spacer(); moreButton }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private var searchButton: some View {
        stageButton("Search", icon: "magnifyingglass") {
            presentationGate.request(.stage) { activeStageSheet = .search }
        }
            .accessibilityIdentifier("stage.search")
    }
    private var queueButton: some View {
        stageButton("Queue", icon: "list.bullet") {
            presentationGate.request(.stage) { activeStageSheet = .queue }
        }
            .accessibilityValue("\(model.snapshot.queue.count) reservations")
    }
    private var cameraButton: some View {
        stageButton("Camera", icon: camera.isEnabled ? "video.fill" : "video") { camera.toggle() }
            .accessibilityValue(camera.isEnabled ? "Front camera live" : "Off")
            .accessibilityIdentifier("stage.camera")
    }
    private var moreButton: some View {
        stageButton("More", icon: "ellipsis") { camera.stop(); onMore() }
    }
    private var playButton: some View {
        Button {
            performTransport { await model.togglePlayPause() }
        } label: {
            Image(systemName: model.snapshot.transport == .playing ? "pause.fill" : "play.fill")
                .font(.system(size: 26, weight: .bold)).frame(width: 62, height: 62)
                .background(GeloVisualStyle.accent.opacity(0.35), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                .shadow(color: GeloVisualStyle.accent, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.snapshot.transport == .playing ? "Pause" : "Play")
        .accessibilityIdentifier("stage.playPause")
        .disabled(!model.isAvailable || transportBusy
                  || (model.snapshot.nowPlaying == nil && model.snapshot.queue.isEmpty))
    }
    private var nextButton: some View {
        stageButton("Next", icon: "forward.end.fill") {
            performTransport { await model.next() }
        }
        .disabled(!model.isAvailable || transportBusy || model.snapshot.queue.isEmpty)
        .accessibilityIdentifier("stage.next")
    }
    private func performTransport(_ action: @escaping @MainActor () async -> Void) {
        guard !transportBusy else { return }
        transportBusy = true
        Task {
            await action()
            transportBusy = false
        }
    }
    private func stageButton(_ title: String, icon: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.3), in: Circle())
                    .overlay(Circle().stroke(GeloVisualStyle.accent.opacity(0.65)))
                Text(title).font(.caption)
            }
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain).accessibilityLabel(title)
    }
    private var queueSheet: some View {
        NavigationStack {
            List {
                if model.snapshot.queue.isEmpty {
                    Text("No reservations yet. Use Search to choose a song.")
                }
                ForEach(model.snapshot.queue) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.song.title)
                            if let singer = item.requestedBy { Text(singer).font(.caption) }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await model.removeQueueItem(item.id) }
                        } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel("Remove " + item.song.title)
                    }
                }
            }
            .navigationTitle("Reservations")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { presentationGate.beginDismissal(.stage); activeStageSheet = nil }
            } }
        }
        .preferredColorScheme(.dark)
    }
}
