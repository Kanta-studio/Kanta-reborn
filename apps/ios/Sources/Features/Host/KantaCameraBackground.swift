import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Main-actor intent; every permission completion is fenced by a generation.
/// Camera is opt-in and ephemeral, independent of the karaoke audio session.
@MainActor
final class KantaCameraBackground: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isStarting = false
    @Published var message: String?
    let capture = KantaCameraCapture()
    private var generation = 0

    func toggle() {
        if isEnabled || isStarting { stop(); return }
        generation += 1
        let request = generation
        isStarting = true
        message = nil
        Task { [weak self] in
            let allowed: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: allowed = true
            case .notDetermined:
                allowed = await AVCaptureDevice.requestAccess(for: .video)
            default: allowed = false
            }
            guard let self, self.generation == request, self.isStarting else { return }
            guard allowed else {
                self.isStarting = false
                self.message = "Allow Camera in iOS Settings to use your front camera as BGV."
                return
            }
            self.capture.start { [weak self] result in
                Task { @MainActor in
                    guard let self, self.generation == request else { return }
                    switch result {
                    case .running:
                        self.isStarting = false
                        self.isEnabled = true
                    case .unavailable:
                        self.stop()
                        self.message = "Front camera is unavailable. Your selected background is still active."
                    case .interrupted:
                        self.stop()
                        self.message = "Camera stopped by iOS. Tap Camera to try again."
                    }
                }
            }
        }
    }

    func stop() {
        generation += 1
        isStarting = false
        isEnabled = false
        capture.stop()
    }
}

/// AVFoundation session mutations are confined to queue. Main-thread access is
/// limited to attaching a preview layer; no outputs, frames, audio or files are
/// captured. This explicit confinement is the justification for unchecked Sendable.
final class KantaCameraCapture: @unchecked Sendable {
    enum Event: Sendable { case running, unavailable, interrupted }
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "kanta.camera.preview", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []

    func start(report: @escaping @Sendable (Event) -> Void) {
        queue.async { [self] in
            tearDown()
            session.beginConfiguration()
            session.automaticallyConfiguresApplicationAudioSession = false
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            }
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front
            ), let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                report(.unavailable)
                return
            }
            session.addInput(input)
            // Bound disposable visual work without modifying any user's media.
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
            }) {
                do {
                    try device.lockForConfiguration()
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                    device.unlockForConfiguration()
                } catch { /* Keep the supported preset's default cadence. */ }
            }
            session.commitConfiguration()
            for name in [AVCaptureSession.wasInterruptedNotification,
                         AVCaptureSession.runtimeErrorNotification] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: session, queue: nil
                ) { _ in report(.interrupted) })
            }
            session.startRunning() // Never blocks the main actor or audio callback.
            report(session.isRunning ? .running : .unavailable)
        }
    }

    func stop() { queue.async { [self] in tearDown() } }

    private func tearDown() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.commitConfiguration()
    }
}

@MainActor
struct KantaCameraPreview: UIViewRepresentable {
    let capture: KantaCameraCapture
    func makeUIView(context: Context) -> KantaCameraPreviewView {
        let view = KantaCameraPreviewView()
        view.preview.session = capture.session
        return view
    }
    func updateUIView(_ view: KantaCameraPreviewView, context: Context) {
        view.updateOrientation()
    }
    static func dismantleUIView(_ view: KantaCameraPreviewView, coordinator: ()) {
        view.preview.session = nil
    }
}

@MainActor
final class KantaCameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateOrientation()
    }
    func updateOrientation() {
        preview.videoGravity = .resizeAspectFill
        guard let connection = preview.connection else { return }
        let angle: CGFloat
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: angle = 180
        case .landscapeRight: angle = 0
        case .portraitUpsideDown: angle = 270
        default: angle = 90
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
