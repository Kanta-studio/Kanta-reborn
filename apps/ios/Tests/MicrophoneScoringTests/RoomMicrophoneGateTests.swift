import Testing
@testable import MicrophoneScoring

@Test func roomGateRequiresExplicitCompleteCheck() {
    var gate = RoomMicrophoneGate()
    #expect(!gate.accepts(rms: 0.2, confidence: 1, clipped: false))
    gate.consume(rms: 0, durationSeconds: 3)
    #expect(gate.state == .needsCheck)
    gate.beginCheck()
    for _ in 0..<29 { gate.consume(rms: 0.01, durationSeconds: 0.1) }
    #expect(gate.state == .checking)
    #expect(!gate.accepts(rms: 0.2, confidence: 1, clipped: false))
    gate.consume(rms: 0.01, durationSeconds: 0.1)
    #expect(gate.state == .ready)
    #expect(abs(gate.minimumRMS - 0.03) < 0.000_01)
    #expect(gate.accepts(rms: 0.1, confidence: 0.9, clipped: false))
    #expect(!gate.accepts(rms: 0.01, confidence: 1, clipped: false))
    #expect(!gate.accepts(rms: 0.1, confidence: 0.5, clipped: false))
    #expect(!gate.accepts(rms: 0.1, confidence: 1, clipped: true))
}

@Test func roomGateRejectsLoudRoomAndCanRecheck() {
    var gate = RoomMicrophoneGate()
    gate.beginCheck()
    for _ in 0..<30 { gate.consume(rms: 0.1, durationSeconds: 0.1) }
    #expect(gate.state == .tooNoisy)
    #expect(!gate.accepts(rms: 0.4, confidence: 1, clipped: false))
    gate.beginCheck()
    for _ in 0..<30 { gate.consume(rms: 0, durationSeconds: 0.1) }
    #expect(gate.state == .ready)
    #expect(gate.minimumRMS == 0.008)
}

@Test func roomGateRejectsInvalidMeasurementsAndWallClockGaps() {
    var gate = RoomMicrophoneGate()
    gate.beginCheck()
    gate.consume(rms: .nan, durationSeconds: 3)
    gate.consume(rms: 0, durationSeconds: .infinity)
    gate.consume(rms: -1, durationSeconds: 3)
    #expect(gate.progress == 0)
    gate.consume(rms: 0, durationSeconds: 30)
    #expect(gate.state == .checking)
    #expect(gate.progress < 0.1)
    #expect(!gate.accepts(rms: .infinity, confidence: 1, clipped: false))
}
