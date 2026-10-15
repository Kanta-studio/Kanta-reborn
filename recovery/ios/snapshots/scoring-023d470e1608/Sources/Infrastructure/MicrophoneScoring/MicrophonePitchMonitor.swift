import AVFoundation
import Combine
import Dispatch
import Foundation
import GeloKaraokeCore

public enum MicrophonePitchMonitorStatus: Equatable, Sendable {
    case idle
    case requestingPermission
    case running
    case denied
    case failed(String)
}

@MainActor
public final class MicrophonePitchMonitor: ObservableObject {
    @Published public private(set) var status: MicrophonePitchMonitorStatus = .idle
    @Published public private(set) var observation: PitchObservation?
    @Published public private(set) var roomState: RoomMicrophoneState = .needsCheck
    @Published public private(set) var inputLevel: Double = 0
    @Published public private(set) var checkProgress: Double = 0
    @Published public private(set) var inputName = "Built-in microphone"

    private let engine = AVAudioEngine()
    private let detector: AutocorrelationPitchDetector
    private let analysisQueue = DispatchQueue(label: "kanta.room-pitch", qos: .userInitiated)
    private var hasTap = false
    private var captureGeneration = UUID()
    private var gate = RoomMicrophoneGate()
    private var subscriptions: Set<AnyCancellable> = []
    private var routeIdentity = ""
    private var ownsAudioSession = false

    public init(detector: AutocorrelationPitchDetector = AutocorrelationPitchDetector()) {
        self.detector = detector
        #if os(iOS)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.status == .running,
                          self.currentRouteIdentity != self.routeIdentity else { return }
                    self.invalidate("Audio route changed. Retry the microphone and check the room again.")
                }
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in
                    self?.invalidate("Audio was interrupted. Retry the microphone and check the room again.")
                }
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.invalidate("Audio services restarted. Reopen Host before using room scoring.")
                }
            }.store(in: &subscriptions)
        #endif
    }

    /// Call while karaoke playback is paused and the singer is quiet.
    public func beginRoomCheck() {
        guard status == .running else { return }
        gate.beginCheck()
        roomState = gate.state
        checkProgress = 0
        observation = nil
    }

    public func cancelRoomCheck() {
        guard roomState == .checking else { return }
        gate = RoomMicrophoneGate()
        roomState = gate.state
        checkProgress = 0
    }

    public func start() async {
        guard status != .running, status != .requestingPermission else { return }
        let generation = UUID()
        captureGeneration = generation
        status = .requestingPermission
        let granted = await requestRecordPermission()
        guard generation == captureGeneration else { return }
        guard !Task.isCancelled else { stop(); return }
        guard granted else { status = .denied; return }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            // A2DP preserves stereo output. HFP would route BOTH directions through
            // the Bluetooth headset; room scoring deliberately uses the phone mic.
            ownsAudioSession = true
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
            guard let microphone = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                throw RoomCaptureError.unavailable
            }
            try session.setPreferredInput(microphone)
            guard session.currentRoute.inputs.contains(where: { $0.portType == .builtInMic }) else {
                throw RoomCaptureError.unavailable
            }
            inputName = microphone.portName
            routeIdentity = currentRouteIdentity
            #endif

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw RoomCaptureError.unavailable
            }
            let detector = self.detector
            let queue = analysisQueue
            // One in-flight buffer; slow analysis drops input rather than creating
            // unbounded work or performing autocorrelation on the audio callback.
            let slot = DispatchSemaphore(value: 1)
            input.installTap(onBus: 0, bufferSize: 2_048, format: nil) { [weak self] buffer, _ in
                guard let channels = buffer.floatChannelData, buffer.frameLength > 0,
                      slot.wait(timeout: .now()) == .success else { return }
                let count = min(Int(buffer.frameLength), 4_096)
                let samples = Array(UnsafeBufferPointer(start: channels[0], count: count))
                let rate = buffer.format.sampleRate
                let timestamp = Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
                queue.async { [weak self] in
                    defer { slot.signal() }
                    guard rate.isFinite, rate > 0, samples.allSatisfy({ $0.isFinite }) else { return }
                    let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(count))
                    let clipped = samples.filter { abs($0) >= 0.98 }.count * 100 >= count
                    let detected = detector.detect(samples: samples, sampleRate: rate)
                    let duration = Double(count) / rate
                    let captureTime = max(0, timestamp - Int64(duration * 500))
                    Task { @MainActor [weak self] in
                        guard let self, self.captureGeneration == generation,
                              self.status == .running else { return }
                        self.inputLevel = min(1, max(0, (20 * log10(max(rms, 0.000_001)) + 60) / 60))
                        self.gate.consume(rms: rms, durationSeconds: duration)
                        self.roomState = self.gate.state
                        self.checkProgress = self.gate.progress
                        guard let detected,
                              self.gate.accepts(rms: detected.rms, confidence: detected.confidence, clipped: clipped) else {
                            self.observation = nil
                            return
                        }
                        self.observation = PitchObservation(timestampMilliseconds: captureTime,
                            frequencyHz: detected.frequencyHz, confidence: detected.confidence, rms: detected.rms)
                    }
                }
            }
            hasTap = true
            engine.prepare()
            try engine.start()
            status = .running
        } catch {
            stop()
            status = .failed(error.localizedDescription)
        }
    }

    public func stop() {
        endCapture()
        #if os(iOS)
        if ownsAudioSession {
            // Never deactivate the shared session: the karaoke engine may be playing.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        }
        #endif
        ownsAudioSession = false
        status = .idle
    }

    private func endCapture() {
        captureGeneration = UUID()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        engine.stop()
        observation = nil
        inputLevel = 0
        gate = RoomMicrophoneGate()
        roomState = gate.state
        checkProgress = 0
    }

    private func invalidate(_ message: String) {
        guard status == .running || status == .requestingPermission else { return }
        endCapture()
        status = .failed(message)
    }

    #if os(iOS)
    private var currentRouteIdentity: String {
        let route = AVAudioSession.sharedInstance().currentRoute
        return (route.inputs + route.outputs).map { $0.uid }.joined(separator: "|")
    }
    #endif

    private func requestRecordPermission() async -> Bool {
        #if os(iOS)
        await AVAudioApplication.requestRecordPermission()
        #else
        true
        #endif
    }
}

private enum RoomCaptureError: LocalizedError {
    case unavailable
    var errorDescription: String? { "The built-in microphone is unavailable on this audio route." }
}
