import AVFoundation
import MicrophoneScoring
import SwiftUI

/// Read and explicitly select the system microphone without creating a
/// second capture graph. The Soundcard and scoring continue to share the
/// existing AVAudioEngine and its fail-closed output monitoring policy.
@MainActor
final class KantaAudioInputDiagnostics: ObservableObject {
    struct Input: Identifiable, Equatable {
        let id: String
        let name: String
    }

    @Published private(set) var activeInput = "No active microphone"
    @Published private(set) var output = "No active output"
    @Published private(set) var availableInputs: [Input] = []
    @Published private(set) var sampleRate = 0
    @Published private(set) var ioBufferMilliseconds = 0.0
    @Published private(set) var message: String?
    @Published private(set) var selectedID = ""

    // Host navigation must not open an audio-session diagnostic surface.
    // Register only while the actual diagnostic panel is visible.
    private var routeObserver: NSObjectProtocol?

    func activate() {
        guard routeObserver == nil else {
            refresh()
            return
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        refresh()
    }

    func deactivate() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
    }

    func refresh() {
        let session = AVAudioSession.sharedInstance()
        activeInput = session.currentRoute.inputs
            .map(\.portName).joined(separator: ", ")
        if activeInput.isEmpty { activeInput = "No active microphone" }
        output = session.currentRoute.outputs
            .map(\.portName).joined(separator: ", ")
        if output.isEmpty { output = "No active output" }
        availableInputs = (session.availableInputs ?? []).map {
            Input(id: $0.uid, name: $0.portName)
        }
        selectedID = session.preferredInput?.uid
            ?? session.currentRoute.inputs.first?.uid
            ?? ""
        sampleRate = Int(session.sampleRate)
        ioBufferMilliseconds = session.ioBufferDuration * 1_000
    }

    func selectInput(_ id: String) {
        let session = AVAudioSession.sharedInstance()
        if id.isEmpty {
            do {
                try session.setPreferredInput(nil)
                message = "Using system-selected microphone."
            } catch {
                message = "Unable to reset input: " + error.localizedDescription
            }
            refresh()
            return
        }
        guard let port = session.availableInputs?.first(where: {
            $0.uid == id
        }) else {
            message = "This microphone is no longer connected."
            refresh()
            return
        }
        do {
            try session.setPreferredInput(port)
            message = "Preferred microphone: " + port.portName
        } catch {
            message = "Unable to change input: " + error.localizedDescription
        }
        refresh()
    }
}

@MainActor
struct KantaAudioInputPanel: View {
    @ObservedObject var diagnostics: KantaAudioInputDiagnostics
    @ObservedObject var microphone: MicrophonePitchMonitor
    @ObservedObject var settings: KantaUserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Microphone", value: diagnostics.activeInput)
            LabeledContent("Audio output", value: diagnostics.output)
            if !diagnostics.availableInputs.isEmpty {
                Picker(
                    "Preferred microphone",
                    selection: Binding(
                        get: { diagnostics.selectedID },
                        set: { diagnostics.selectInput($0) }
                    )
                ) {
                    Text("System default").tag("")
                    ForEach(diagnostics.availableInputs) { input in
                        Text(input.name).tag(input.id)
                    }
                }
            }
            HStack {
                LabeledContent(
                    "Input sample rate",
                    value: "\(diagnostics.sampleRate) Hz"
                )
                LabeledContent(
                    "I/O buffer",
                    value: String(
                        format: "%.1f ms",
                        diagnostics.ioBufferMilliseconds
                    )
                )
            }
            .font(.caption)

            if microphone.status == .running {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Microphone test · live input level")
                        .font(.caption.weight(.semibold))
                    ProgressView(
                        value: Double(min(max(
                            microphone.inputRMS * 8, 0
                        ), 1))
                    )
                    .accessibilityLabel("Microphone input level")
                }
            } else {
                Text(
                    "Enable scoring or live vocal monitoring to see " +
                    "a microphone level. Input selection alone does " +
                    "not start microphone recording."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Stepper(
                "Scoring offset · \(settings.scoringLatencyMilliseconds) ms",
                value: $settings.scoringLatencyMilliseconds,
                in: -500...1_500,
                step: 10
            )
            .font(.caption)
            Text(
                "I/O buffer is a hardware estimate, not measured " +
                "round-trip microphone latency. For HDMI/AirPlay, " +
                "calibrate lyric timing and scoring on physical devices."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let message = diagnostics.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh audio devices") { diagnostics.refresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .onAppear { diagnostics.activate() }
        .onDisappear { diagnostics.deactivate() }
    }
}

