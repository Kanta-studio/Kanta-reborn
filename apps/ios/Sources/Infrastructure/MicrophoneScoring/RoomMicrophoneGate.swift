import Foundation

public enum RoomMicrophoneState: Equatable, Sendable {
    case needsCheck
    case checking
    case ready
    case tooNoisy
}

/// Ambient-level gate, not voice isolation or acoustic echo cancellation.
/// Calibration consumes three seconds of actual input, never wall-clock gaps.
public struct RoomMicrophoneGate: Sendable {
    public private(set) var state: RoomMicrophoneState = .needsCheck
    public private(set) var minimumRMS: Double = 0.008
    public private(set) var progress: Double = 0
    private var duration: Double = 0
    private var energy: Double = 0

    public init() {}

    public mutating func beginCheck() {
        self = Self()
        state = .checking
    }

    public mutating func consume(rms: Double, durationSeconds: Double) {
        guard state == .checking, rms.isFinite, rms >= 0,
              durationSeconds.isFinite, durationSeconds > 0 else { return }
        let interval = min(durationSeconds, 0.25, 3 - duration)
        energy += rms * rms * interval
        duration += interval
        progress = min(1, duration / 3)
        guard duration >= 3 - 0.000_001 else { return }
        minimumRMS = max(0.008, sqrt(energy / duration) * 3)
        state = minimumRMS <= 0.12 ? .ready : .tooNoisy
        progress = 1
    }

    public func accepts(rms: Double, confidence: Double, clipped: Bool) -> Bool {
        state == .ready && !clipped && rms.isFinite && confidence.isFinite
            && rms >= minimumRMS && confidence >= 0.75
    }
}
