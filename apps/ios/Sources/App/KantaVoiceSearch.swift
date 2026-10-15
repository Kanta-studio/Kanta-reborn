import AVFoundation
import SwiftUI
import GeloKaraokeCore
@preconcurrency import Speech

/// iOS 17-compatible, opt-in speech-to-search. SFSpeechRecognizer recognizes
/// one locale per request, so language selection is explicit rather than
/// pretending to detect Filipino/English code-switching automatically.
enum KantaVoiceLanguage: String, CaseIterable, Identifiable {
    case filipino
    case englishPhilippines

    var id: String { rawValue }
    var title: String {
        switch self {
        case .filipino: "Filipino"
        case .englishPhilippines: "English (PH)"
        }
    }
    var candidateIDs: [String] {
        switch self {
        case .filipino: ["fil-PH", "tl-PH"]
        case .englishPhilippines: ["en-PH", "en-US"]
        }
    }

    func resolvedLocale() -> Locale? {
        let supported = SFSpeechRecognizer.supportedLocales()
        return candidateIDs.compactMap { candidate in
            supported.first {
                $0.identifier.replacingOccurrences(of: "_", with: "-")
                    .caseInsensitiveCompare(candidate) == .orderedSame
            }
        }.first
    }
}

@MainActor
final class KantaVoiceSearchController: ObservableObject {
    enum Phase {
        case idle, requesting, listening, finishing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var finalQuery = ""
    @Published private(set) var alternativeQueries: [String] = []
    @Published private(set) var message = ""

    // Create the audio graph only after microphone permission and
    // a user action. Rendering Host CONTROL must never start RemoteIO.
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var tapInstalled = false
    private var previousAudioCategory: AVAudioSession.Category?
    private var previousAudioMode: AVAudioSession.Mode?
    private var previousAudioOptions: AVAudioSession.CategoryOptions = []
    private var session = UUID()

    var isActive: Bool { phase != .idle }

    func toggle(language: KantaVoiceLanguage) {
        if phase == .requesting {
            stop()
        } else if isActive {
            finishListening()
        } else {
            Task { await start(language: language) }
        }
    }

    private func start(language: KantaVoiceLanguage) async {
        guard phase == .idle else { return }
        let token = UUID()
        session = token
        phase = .requesting
        transcript = ""
        finalQuery = ""
        alternativeQueries = []
        message = "Requesting microphone and speech permission…"

        let authorization: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization {
                    continuation.resume(returning: $0)
                }
            }
        } else {
            authorization = SFSpeechRecognizer.authorizationStatus()
        }
        guard session == token else { return }
        guard authorization == .authorized else {
            phase = .idle
            message = "Speech permission is off. Enable it in iOS Settings or type your search."
            return
        }

        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission {
                continuation.resume(returning: $0)
            }
        }
        guard session == token else { return }
        guard granted else {
            phase = .idle
            message = "Microphone permission is off. Enable it in Settings or type your search."
            return
        }

        guard let locale = language.resolvedLocale(),
              let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            phase = .idle
            message = language == .filipino
                ? "Filipino recognition isn't available on this device. Try English (PH) or keyboard dictation."
                : "English speech recognition is unavailable. Try again or use the keyboard."
            return
        }

        do {
            let audio = AVAudioSession.sharedInstance()
            previousAudioCategory = audio.category
            previousAudioMode = audio.mode
            previousAudioOptions = audio.categoryOptions
            try audio.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try audio.setActive(true)

            // Query input format after activation, when the current audio
            // route and sample rate are known on real iPhone/iPad devices.
            let voiceEngine = AVAudioEngine()
            engine = voiceEngine
            let input = voiceEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                cleanup()
                message = "No microphone audio input available. Check your audio route."
                return
            }

            let inputRequest = SFSpeechAudioBufferRecognitionRequest()
            inputRequest.shouldReportPartialResults = true
            inputRequest.taskHint = .search
            inputRequest.contextualStrings = [
                "KANTA", "karaoke", "OPM", "song code", "numero",
                "hanapin", "awit", "artist", "Tagalog"
            ]
            inputRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request = inputRequest

            transcript = ""
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) {
                buffer, _ in
                inputRequest.append(buffer)
            }
            tapInstalled = true

            recognitionTask = recognizer.recognitionTask(with: inputRequest) {
                [weak self] result, error in
                let spoken = result?.bestTranscription.formattedString
                let options = result?.transcriptions.prefix(4).map(\.formattedString) ?? []
                let final = result?.isFinal ?? false
                let errorMessage = error?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.receive(
                        token: token,
                        spoken: spoken,
                        options: options,
                        isFinal: final,
                        errorMessage: errorMessage
                    )
                }
            }
            voiceEngine.prepare()
            try voiceEngine.start()
            phase = .listening
            message = recognizer.supportsOnDeviceRecognition
                ? "Listening on-device. Say a song title, artist, or code."
                : "Listening using Apple's speech service, which may process audio online."
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self?.finishListening()
            }
        } catch {
            cleanup()
            message = "Could not start voice search: \(error.localizedDescription). Try typing."
        }
    }

    private func receive(
        token: UUID,
        spoken: String?,
        options: [String],
        isFinal: Bool,
        errorMessage: String?
    ) {
        guard session == token, phase != .idle else { return }
        if let spoken, !spoken.isEmpty {
            transcript = KantaSpeechQueryNormalizer.normalized(spoken)
            var alternatives: [String] = []
            for option in options {
                let candidate = KantaSpeechQueryNormalizer.normalized(option)
                if !candidate.isEmpty, candidate != transcript,
                   !alternatives.contains(candidate) {
                    alternatives.append(candidate)
                }
            }
            alternativeQueries = Array(alternatives.prefix(3))
        }
        if let errorMessage {
            if !transcript.isEmpty { finalQuery = transcript }
            cleanup()
            message = transcript.isEmpty
                ? "Speech recognition ended: \(errorMessage). You can still type."
                : "Voice search ready. Check the title or code before reserving."
        } else if isFinal {
            if !transcript.isEmpty { finalQuery = transcript }
            cleanup()
            message = "Voice search ready. Review or edit the recognized text."
        }
    }

    func finishListening() {
        guard phase == .listening else { return }
        let token = session
        phase = .finishing
        message = "Finishing transcription…"
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine?.stop()
        request?.endAudio()
        recognitionTask?.finish()
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self,
                  self.session == token, self.phase == .finishing else { return }
            if !self.transcript.isEmpty { self.finalQuery = self.transcript }
            self.cleanup()
            self.message = "Voice search ready. Review or edit the recognized text."
        }
    }

    func stop() {
        session = UUID()
        cleanup()
        message = ""
    }

    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine?.stop()
        engine = nil
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        if let category = previousAudioCategory,
           let mode = previousAudioMode {
            try? AVAudioSession.sharedInstance().setCategory(
                category,
                mode: mode,
                options: previousAudioOptions
            )
        }
        previousAudioCategory = nil
        previousAudioMode = nil
        previousAudioOptions = []
        phase = .idle
    }
}

struct KantaVoiceSearchAccessory: View {
    @Binding var query: String
    @Environment(\.scenePhase) private var scenePhase
    var microphoneBusy = false

    @StateObject private var voice = KantaVoiceSearchController()
    @StateObject private var offline = KantaFilipinoVoiceCapture()
    @ObservedObject private var pack = KantaFilipinoModelStore.shared
    @State private var language: KantaVoiceLanguage = .englishPhilippines

    private var offlineSelected: Bool {
        language == .filipino
    }

    private var anyVoiceActive: Bool {
        voice.isActive || offline.phase != .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Picker("Voice language", selection: $language) {
                    Text("Filipino / Taglish · Offline")
                        .tag(KantaVoiceLanguage.filipino)
                    Text("English (PH) · Apple Speech")
                        .tag(KantaVoiceLanguage.englishPhilippines)
                }
                .pickerStyle(.menu)
                .disabled(anyVoiceActive)

                Button {
                    if offlineSelected {
                        if offline.phase == .recording {
                            offline.finish(pack: pack)
                        } else if offline.phase == .idle {
                            offline.begin(pack: pack)
                        }
                    } else {
                        voice.toggle(language: .englishPhilippines)
                    }
                } label: {
                    Label(
                        (offlineSelected && offline.phase == .recording)
                            || (!offlineSelected && voice.isActive)
                            ? "Finish" : "Voice Search",
                        systemImage:
                            anyVoiceActive ? "stop.circle.fill" : "mic.circle.fill"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(
                    (microphoneBusy && !anyVoiceActive)
                    || (offlineSelected && !pack.isInstalled)
                    || (offlineSelected && pack.isTranscribing)
                    || (offlineSelected && offline.phase == .transcribing)
                    || (offlineSelected && offline.phase == .requesting)
                    || (!offlineSelected && offline.phase != .idle)
                )
                .accessibilityHint(
                    "Speak a song title, artist, or five-digit KANTA code."
                )
            }

            KantaFilipinoPackControls()

            if microphoneBusy {
                Text(
                    "Pause room scoring or live Soundcard microphone effects " +
                    "before starting voice search on this device."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            if offline.phase != .idle || !offline.message.isEmpty {
                Text(offline.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !voice.message.isEmpty {
                Text(voice.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !voice.transcript.isEmpty && voice.isActive {
                Text("Heard: " + voice.transcript)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GeloVisualStyle.cyan)
            }
            if !voice.alternativeQueries.isEmpty && !voice.isActive {
                Text("Other recognized titles")
                    .font(.caption.weight(.semibold))
                ForEach(voice.alternativeQueries, id: \.self) { candidate in
                    Button(candidate) { query = candidate }
                        .buttonStyle(.borderless)
                }
            }

            Text(
                "Say an actual song title, artist, or code. Filipino uses " +
                "the downloaded local model; English uses Apple's speech " +
                "recognition (which may process audio online). Confirm " +
                "the correct result before Reserve."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

        }
        .onChange(of: voice.finalQuery) {
            if !voice.finalQuery.isEmpty { query = voice.finalQuery }
        }
        .onChange(of: offline.finalQuery) {
            if !offline.finalQuery.isEmpty {
                query = offline.finalQuery
            }
        }
        .onChange(of: pack.status) {
            if pack.status == .ready { language = .filipino }
        }
        .onChange(of: language) {
            voice.stop()
            offline.cancel()
        }
        .onAppear {
            if pack.isInstalled { language = .filipino }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                voice.stop()
                offline.cancel()
            }
        }
        .onDisappear {
            voice.stop()
            offline.cancel()
        }
    }
}

