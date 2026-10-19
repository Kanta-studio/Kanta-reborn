import AVFoundationPlayback
import GeloKaraokeCore
import LocalNetworkControl
import MicrophoneScoring
import SwiftUI

@MainActor
struct HostView: View {
    private let onOpenNavigation: () -> Void
    @ObservedObject var presentationGate: KantaPresentationGate
    let navigationSheetPresented: Bool
    @StateObject private var camera = KantaCameraBackground()
    @State private var pendingFullscreen = false
    @State private var dismissedHostSheet: HostSheet?
    @State private var activeHostSheet: HostSheet? =
        ProcessInfo.processInfo.environment["KANTA_CONTROL_EXPANDED"] == "1" ? .controls : nil

    private enum HostSheet: String, Identifiable {
        case controls, sessionSave, favorites
        var id: String { rawValue }
    }
    @StateObject private var model: HostViewModel
    @ObservedObject private var networkHost: BonjourHostAdvertiser
    @ObservedObject private var microphonePitchMonitor:
        MicrophonePitchMonitor
    @ObservedObject private var settings: KantaUserSettings
    @ObservedObject private var externalStage = KantaExternalStageCoordinator.shared
    @State private var singerName = ""
    @StateObject private var audioInputs = KantaAudioInputDiagnostics()
    @StateObject private var intermission = KantaIntermissionMusic()
    private let partySFX: KantaPartySFXEngine
    private let diagnostics: KantaSupportDiagnostics
    @State private var showControlCenter =
        ProcessInfo.processInfo.environment[
            "KANTA_CONTROL_EXPANDED"
        ] == "1"
    @State private var showingFullscreenPlayer =
        ProcessInfo.processInfo.environment[
            "KANTA_FULLSCREEN"
        ] == "1"

    init(services: AppServices, presentationGate: KantaPresentationGate = KantaPresentationGate(), navigationSheetPresented: Bool = false, onOpenNavigation: @escaping () -> Void = {}) {
        self.presentationGate = presentationGate
        self.navigationSheetPresented = navigationSheetPresented
        self.onOpenNavigation = onOpenNavigation
        partySFX = services.partySFX
        diagnostics = services.diagnostics
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
                library: services.library,
                savedSets: services.savedSets
            )
        )
    }

    @State private var remoteExpanded = false

    var body: some View {
        hostContent
        .sheet(item: $activeHostSheet, onDismiss: {
            if dismissedHostSheet == .sessionSave {
                model.showingSessionSavePrompt = false
            }
            dismissedHostSheet = nil
            if pendingFullscreen {
                pendingFullscreen = false
                // Queue fullscreen before releasing CONTROL so the gate owns the
                // transition continuously, including while the sheet animates out.
                presentationGate.request(.fullscreen) { showingFullscreenPlayer = true }
            }
            presentationGate.completeDismissal(.host)
        }) { sheet in
            switch sheet {
            case .controls:
                NavigationStack {
                    hostControls
                        .safeAreaInset(edge: .bottom) {
                            Button(action: openFullscreenPlayer) {
                                Label("Open fullscreen player", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("controls.openFullscreen")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.regularMaterial)
                        }
                        .navigationTitle("CONTROL")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    presentationGate.beginDismissal(.host)
                                    activeHostSheet = nil
                                }
                            }
                        }
                }
            case .sessionSave:
                SaveSessionFavoritesView(model: model)
            case .favorites:
                SavedFavoritesView(model: model)
            }
        }
        .navigationTitle("Karaoke Host")
        .navigationBarTitleDisplayMode(.large)
        .background {
            SingingFullscreenPresentation(
                isPresented: $showingFullscreenPlayer,
                model: model,
                backgroundsEnabled: settings.stageVisualsEnabled,
                selectedPreset: settings.selectedVisualPreset,
                camera: camera,
                presentationGate: presentationGate,
                microphoneBusy: microphonePitchMonitor.status == .running
                    || microphonePitchMonitor.status == .requestingPermission
            )
            .frame(width: 1, height: 1)
        }
        .onChange(of: model.snapshot.transport) {
            intermission.sync(model.snapshot.transport)
        }
        .onChange(of: settings.scoringEnabled) {
            diagnostics.record(
                settings.scoringEnabled ? .scoringEnabled : .scoringDisabled
            )
            microphonePitchMonitor.configureEffects(settings.vocalEffects)
            model.setScoringEnabled(
                settings.scoringEnabled
            )

            if settings.scoringEnabled || settings.vocalEffects.monitorEnabled {
                Task {
                    await microphonePitchMonitor.start()
                }
            } else {
                microphonePitchMonitor.stop()
            }
        }
        .onChange(of: settings.scoringLatencyMilliseconds) {
            model.setScoringLatencyMilliseconds(
                Int64(settings.scoringLatencyMilliseconds)
            )
        }
        .onChange(of: settings.vocalEffects) {
            microphonePitchMonitor.configureEffects(settings.vocalEffects)
            if settings.scoringEnabled || settings.vocalEffects.monitorEnabled {
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
            diagnostics.record(.hostOpened)
            externalStage.activate(host: model, settings: settings)
            intermission.activate()
            if !isDemoMode {
                networkHost.start()
            }
            model.setScoringEnabled(
                settings.scoringEnabled
            )
            model.setScoringLatencyMilliseconds(
                Int64(settings.scoringLatencyMilliseconds)
            )

            if settings.scoringEnabled || settings.vocalEffects.monitorEnabled {
                await microphonePitchMonitor.start()
            }

            await model.run()
            intermission.sync(model.snapshot.transport)
        }
        .onChange(of: activeHostSheet) { previous, current in
            if previous != nil && current == nil {
                presentationGate.beginDismissal(.host)
                dismissedHostSheet = previous
            }
        }
        // Only *dismiss* the Host session-save sheet automatically. Do not
        // automatically present it on a navigation transition — keep the pending
        // save state and require an explicit user action (Save session) to open
        // the Host sheet so it cannot block the Library → Search handoff.
        .onChange(of: model.showingSessionSavePrompt) { _, pending in
            if !pending && activeHostSheet == .sessionSave {
                presentationGate.beginDismissal(.host)
                activeHostSheet = nil
            }
        }
        .onDisappear {
            camera.stop()
            diagnostics.record(.hostClosed)
            externalStage.deactivate(host: model)
            intermission.deactivate()
            Task { await partySFX.stopAll() }
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



    private var hostContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                embeddedStage
                inlineRemote

                GeloSectionCard("External TV / Stage Display") {
                    Text(externalStage.isPresenting ? "Extended screen active" : "No independent display detected")
                    Text("Connect HDMI/USB-C or an AirPlay display with extended-screen support. The TV shows lyrics and backgrounds; controls stay here. Mirroring also shows this device’s cont[...]")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(.black)
    }

    private var embeddedStage: some View {
        KantaMainPlayerView(
            model: model, camera: camera, presentationGate: presentationGate,
            backgroundsEnabled: settings.stageVisualsEnabled,
            selectedPreset: settings.selectedVisualPreset,
            singerName: $singerName,
            microphoneBusy: microphonePitchMonitor.status == .running
                || microphonePitchMonitor.status == .requestingPermission,
            onControls: {
                presentationGate.request(.host) { activeHostSheet = .controls }
            },
            onMore: onOpenNavigation,
            onSaveSession: {
                guard model.showingSessionSavePrompt else { return }
                // Do not open the session-save sheet while navigation is still
                // presented or while another Host sheet is active. Keep the
                // pending save decision and surface the explicit Save session
                // action on the Stage so the user can open it after navigation
                // completes.
                guard !navigationSheetPresented && activeHostSheet == nil else { return }
                presentationGate.request(.host) { activeHostSheet = .sessionSave }
            },
            embedded: true,
            onExpand: openFullscreenPlayer
        )
    }

    private var inlineRemote: some View {
        DisclosureGroup(isExpanded: $remoteExpanded) {
            InAppControlCenterView(
                model: model,
                backgroundsEnabled: $settings.stageVisualsEnabled,
                selectedPreset: $settings.selectedVisualPreset,
                singerName: $singerName,
                microphoneBusy: microphonePitchMonitor.status == .running
                    || microphonePitchMonitor.status == .requestingPermission
            )
            .padding(.top, 16)
        } label: {
            Label("Remote Control", systemImage: "rectangle.and.hand.point.up.left")
                .font(.headline)
        }
        .padding(18)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("host.remotePanel")
    }

    private func openFullscreenPlayer() {
        guard activeHostSheet != nil else {
            presentationGate.request(.fullscreen) { showingFullscreenPlayer = true }
            return
        }
        pendingFullscreen = true
        presentationGate.beginDismissal(.host)
        activeHostSheet = nil
    }

    private var hostControls: some View {
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

