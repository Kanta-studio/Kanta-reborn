import AVFoundation
import GeloKaraokeCore
import Foundation
import SwiftUI
@preconcurrency import WhisperKit

/// User-installed multilingual Whisper Core ML model. Locale availability
/// is independent of Speech.framework.
@MainActor
final class KantaFilipinoModelStore: ObservableObject {
    static let shared = KantaFilipinoModelStore()

    enum Status: Equatable {
        case notInstalled
        case downloading
        case preparing
        case ready
        case error(String)
    }

    @Published private(set) var status: Status = .notInstalled
    @Published private(set) var downloadFraction = 0.0
    @Published private(set) var isTranscribing = false

    static let modelRepository = "argmaxinc/whisperkit-coreml"
    static let modelVariant = "base" // Explicit multilingual model, not base.en.
    static let approximateDownloadMegabytes = 147

    private struct Installation: Codable {
        let version: Int
        let repository: String
        let variant: String
        let relativeFolder: String
        let relativeTokenizerPath: String
    }

    private let fileManager = FileManager.default
    private let modelRoot: URL
    private let manifestURL: URL

    private init() {
        let support = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        modelRoot = support.appendingPathComponent(
            "KANTA-Filipino-Speech", isDirectory: true
        )
        manifestURL = modelRoot.appendingPathComponent("installation.json")
        if installedFolder() != nil { status = .ready }
    }

    var isInstalled: Bool {
        installedFolder() != nil
    }

    var isDownloading: Bool {
        status == .downloading || status == .preparing
    }

    /// Only called from the explicit Download button, never app launch/search.
    func downloadWithConsent() async {
        guard !isDownloading, !isTranscribing else { return }
        if isInstalled {
            status = .ready
            return
        }

        status = .downloading
        downloadFraction = 0
        do {
            try fileManager.createDirectory(
                at: modelRoot, withIntermediateDirectories: true
            )
            var excluded = URLResourceValues()
            excluded.isExcludedFromBackup = true
            var root = modelRoot
            try root.setResourceValues(excluded)

            // HF Hub's snapshot client handles individual model files,
            // local caching and partial downloads; no model is in the IPA.
            let folder = try await WhisperKit.download(
                variant: Self.modelVariant,
                downloadBase: modelRoot,
                from: Self.modelRepository,
                progressCallback: { [weak self] progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor [weak self] in
                        guard self?.status == .downloading else { return }
                        self?.downloadFraction = min(1, max(0, fraction))
                    }
                }
            )
            try Task.checkCancellation()
            guard isWithinModelRoot(folder), hasModelFiles(folder) else {
                throw PackError.invalidContents
            }

            status = .preparing
            // This also installs and validates the multilingual tokenizer
            // while the user-authorized download session is ongoing.
            let engine = try await WhisperKit(
                WhisperKitConfig(
                    modelFolder: folder.path,
                    tokenizerFolder: modelRoot,
                    verbose: false,
                    load: true,
                    download: false
                )
            )
            await engine.unloadModels()
            try Task.checkCancellation()

            // Do not mark the pack ready unless the tokenizer was cached
            // locally during the explicit installation session.
            guard let tokenizerURL = cachedTokenizerURL() else {
                throw PackError.invalidContents
            }
            let tokenizerPath = String(
                tokenizerURL.standardizedFileURL.path
                    .dropFirst(modelRoot.standardizedFileURL.path.count + 1)
            )

            let path = String(
                folder.standardizedFileURL.path
                    .dropFirst(modelRoot.standardizedFileURL.path.count + 1)
            )
            let metadata = Installation(
                version: 1,
                repository: Self.modelRepository,
                variant: Self.modelVariant,
                relativeFolder: path,
                relativeTokenizerPath: tokenizerPath
            )
            try JSONEncoder().encode(metadata).write(
                to: manifestURL, options: .atomic
            )
            downloadFraction = 1
            status = .ready
        } catch {
            status = .error(
                "Model setup failed: \(error.localizedDescription). Try downloading again."
            )
        }
    }

    func transcribe(url: URL) async throws -> String {
        guard let folder = installedFolder(), !isDownloading,
              !isTranscribing else {
            throw PackError.notReady
        }
        isTranscribing = true
        defer { isTranscribing = false }

        // Inference uses the installed model; audio and query text stay on device.
        let engine = try await WhisperKit(
            WhisperKitConfig(
                modelFolder: folder.path,
                tokenizerFolder: modelRoot,
                verbose: false,
                load: true,
                download: false
            )
        )
        let options = DecodingOptions(
            task: .transcribe,
            language: "tl",
            sampleLength: 128,
            withoutTimestamps: true,
            concurrentWorkerCount: 1
        )
        do {
            let segments = try await engine.transcribe(
                audioPath: url.path, decodeOptions: options
            )
            await engine.unloadModels()
            return segments.map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            await engine.unloadModels()
            throw error
        }
    }

    /// Destructive action requiring confirmation from the calling view.
    func removeDownloadedModel() throws {
        guard !isDownloading, !isTranscribing else {
            throw PackError.busy
        }
        if fileManager.fileExists(atPath: modelRoot.path) {
            try fileManager.removeItem(at: modelRoot)
        }
        downloadFraction = 0
        status = .notInstalled
    }

    private func installedFolder() -> URL? {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(
                Installation.self, from: data
              ),
              manifest.version == 1,
              manifest.repository == Self.modelRepository,
              manifest.variant == Self.modelVariant,
              !manifest.relativeFolder.isEmpty,
              !manifest.relativeTokenizerPath.isEmpty else { return nil }
        let tokenizer = modelRoot.appendingPathComponent(
            manifest.relativeTokenizerPath
        )
        guard isWithinModelRoot(tokenizer),
              fileManager.fileExists(atPath: tokenizer.path) else {
            return nil
        }
        let folder = modelRoot.appendingPathComponent(
            manifest.relativeFolder, isDirectory: true
        )
        guard isWithinModelRoot(folder), hasModelFiles(folder) else {
            return nil
        }
        return folder
    }

    private func isWithinModelRoot(_ folder: URL) -> Bool {
        let root = modelRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let candidate = folder.standardizedFileURL
            .resolvingSymlinksInPath().path
        return candidate.hasPrefix(root + "/")
    }

    private func cachedTokenizerURL() -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: modelRoot,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return nil }
        for case let file as URL in enumerator {
            if file.lastPathComponent == "tokenizer.json",
               isWithinModelRoot(file) {
                return file
            }
        }
        return nil
    }

    private func hasModelFiles(_ folder: URL) -> Bool {
        for name in [
            "AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc",
            "TextDecoder.mlmodelc"
        ] {
            let component = folder.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(
                atPath: component.path, isDirectory: &isDirectory
            ), isDirectory.boolValue else { return false }
        }
        return true
    }

    enum PackError: LocalizedError {
        case invalidContents, notReady, busy

        var errorDescription: String? {
            switch self {
            case .invalidContents:
                "Downloaded model is incomplete or has invalid paths."
            case .notReady:
                "Download the Filipino speech pack before using offline voice search."
            case .busy:
                "Finish voice search or the current download first."
            }
        }
    }
}

/// Captures a short *temporary* speech sample for offline Whisper inference.
/// It never modifies scoring taps and removes raw audio immediately afterward.
@MainActor
final class KantaFilipinoVoiceCapture: ObservableObject {
    enum Phase: Equatable { case idle, requesting, recording, transcribing }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var finalQuery = ""
    @Published private(set) var message = ""

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var generation = UUID()
    private var previousCategory: AVAudioSession.Category?
    private var previousMode: AVAudioSession.Mode?
    private var previousOptions: AVAudioSession.CategoryOptions = []

    func begin(pack: KantaFilipinoModelStore) {
        guard phase == .idle, pack.isInstalled,
              !pack.isDownloading, !pack.isTranscribing else { return }
        let token = UUID()
        generation = token
        finalQuery = ""
        phase = .requesting
        message = "Allow microphone access to recognize your song title privately."
        Task { [weak self] in
            guard let self else { return }
            let permitted = await withCheckedContinuation {
                (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance()
                    .requestRecordPermission { allowed in
                        continuation.resume(returning: allowed)
                    }
            }
            guard self.generation == token else { return }
            guard permitted else {
                self.phase = .idle
                self.message = "Microphone permission is disabled. Use text search or enable it in Settings."
                return
            }
            self.startRecording(token: token, pack: pack)
        }
    }

    private func startRecording(
        token: UUID, pack: KantaFilipinoModelStore
    ) {
        guard generation == token, phase == .requesting else { return }
        do {
            let audio = AVAudioSession.sharedInstance()
            previousCategory = audio.category
            previousMode = audio.mode
            previousOptions = audio.categoryOptions
            try audio.setCategory(
                .playAndRecord, mode: .measurement,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try audio.setActive(true)

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("kanta-voice-" + UUID().uuidString)
                .appendingPathExtension("caf")
            let recorder = try AVAudioRecorder(
                url: destination,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]
            )
            guard recorder.prepareToRecord(), recorder.record() else {
                throw CaptureError.cannotRecord
            }
            self.recorder = recorder
            recordingURL = destination
            phase = .recording
            message = "Listening in Filipino/Taglish (max 8 seconds). Tap Finish when done."
            timer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.finish(pack: pack)
            }
        } catch {
            cancel()
            message = "Could not record: \(error.localizedDescription)"
        }
    }

    func finish(pack: KantaFilipinoModelStore) {
        guard phase == .recording, let audioFile = recordingURL else {
            return
        }
        timer?.cancel()
        timer = nil
        recorder?.stop()
        recorder = nil
        restoreAudioSession()
        phase = .transcribing
        message = "Recognizing your title offline. This may take longer on older phones."
        let token = generation
        // The active transcription owns this file until inference terminates.
        recordingURL = nil

        transcriptionTask = Task { [weak self] in
            guard let self else {
                try? FileManager.default.removeItem(at: audioFile)
                return
            }
            defer {
                try? FileManager.default.removeItem(at: audioFile)
                if self.generation == token {
                    self.recordingURL = nil
                    self.transcriptionTask = nil
                    self.phase = .idle
                }
            }
            do {
                let result = try await pack.transcribe(url: audioFile)
                guard token == self.generation, !Task.isCancelled else {
                    return
                }
                let normalized = KantaSpeechQueryNormalizer.normalized(result)
                if !normalized.isEmpty {
                    self.finalQuery = normalized
                    self.message = "Offline Filipino search ready. Check the title before reserving."
                } else {
                    self.message = "I couldn't hear a clear title. Try again or type it."
                }
            } catch {
                guard token == self.generation else { return }
                self.message = "Offline recognition failed: \(error.localizedDescription)"
            }
        }
    }

    func cancel() {
        generation = UUID()
        timer?.cancel()
        timer = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        recorder?.stop()
        recorder = nil
        restoreAudioSession()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        phase = .idle
    }

    private func restoreAudioSession() {
        if let category = previousCategory,
           let mode = previousMode {
            try? AVAudioSession.sharedInstance().setCategory(
                category, mode: mode, options: previousOptions
            )
        }
        previousCategory = nil
        previousMode = nil
        previousOptions = []
    }

    private enum CaptureError: LocalizedError {
        case cannotRecord
        var errorDescription: String? { "The microphone could not start recording." }
    }
}

/// The same model download controls are available from Settings,
/// Host CONTROL, Songbook and paired Remote, with one shared install state.
struct KantaFilipinoPackControls: View {
    @ObservedObject private var pack = KantaFilipinoModelStore.shared
    @State private var showRemove = false
    @State private var removalError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Label(
                    "Filipino + Taglish Offline Pack",
                    systemImage: "waveform.badge.mic"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GeloVisualStyle.gold)
                Spacer(minLength: 4)
                if pack.isInstalled {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(GeloVisualStyle.cyan)
                }
            }
            if pack.isInstalled {
                Text(
                    "Speech recognition runs locally using the downloaded " +
                    "multilingual model. Song titles, artists and spoken codes " +
                    "remain editable before search."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                Button("Remove Downloaded Model", role: .destructive) {
                    showRemove = true
                }
                .buttonStyle(.bordered)
                .disabled(pack.isTranscribing)
            } else {
                Text(
                    "Optional one-time download: about " +
                    "\(KantaFilipinoModelStore.approximateDownloadMegabytes) MB " +
                    "plus tokenizer and temporary cache. Wi-Fi and available " +
                    "storage recommended. No speech uploads to KANTA."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                if pack.isDownloading {
                    ProgressView(value: pack.downloadFraction)
                    Text(
                        pack.status == .preparing
                            ? "Preparing and validating model…"
                            : "Downloading Filipino model… " +
                                "\(Int(pack.downloadFraction * 100))%"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await pack.downloadWithConsent() }
                    } label: {
                        Label(
                            "Download Filipino Offline Pack",
                            systemImage: "arrow.down.to.line.compact"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                if case let .error(problem) = pack.status {
                    Text(problem).font(.caption2).foregroundStyle(.orange)
                }
            }
            if let removalError {
                Text(removalError).font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeloVisualStyle.cardTop,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .confirmationDialog(
            "Remove the offline Filipino speech pack?",
            isPresented: $showRemove, titleVisibility: .visible
        ) {
            Button("Remove Model", role: .destructive) {
                do {
                    try pack.removeDownloadedModel()
                    removalError = nil
                } catch {
                    removalError = error.localizedDescription
                }
            }
        } message: {
            Text(
                "This clears the downloaded model, not your songs, " +
                "Favorites, playback settings or library. You can reinstall later."
            )
        }
    }
}

