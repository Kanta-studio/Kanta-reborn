import Foundation
import Testing
@testable import MicrophoneScoring

@Test func autocorrelationDetectorFindsA4SineWave() {
    let sampleRate = 44_100.0
    let frequency = 440.0
    let count = 4_096

    let samples = (0..<count).map { index in
        Float(
            sin(
                2 * Double.pi * frequency
                    * Double(index) / sampleRate
            ) * 0.4
        )
    }

    let detector = AutocorrelationPitchDetector()
    let detected = detector.detect(
        samples: samples,
        sampleRate: sampleRate
    )

    #expect(detected != nil)
    #expect(
        abs((detected?.frequencyHz ?? 0) - frequency)
            < 2
    )
    #expect((detected?.confidence ?? 0) > 0.9)
}

@Test func autocorrelationDetectorRejectsSilence() {
    let detector = AutocorrelationPitchDetector()

    #expect(
        detector.detect(
            samples: Array(repeating: 0, count: 2_048),
            sampleRate: 44_100
        ) == nil
    )
}

@Test func autocorrelationDetectorRejectsOutOfRangeTone() {
    let sampleRate = 44_100.0
    let frequency = 2_000.0
    let samples = (0..<4_096).map { index in
        Float(
            sin(
                2 * Double.pi * frequency
                    * Double(index) / sampleRate
            ) * 0.4
        )
    }

    let detector = AutocorrelationPitchDetector(
        minimumFrequencyHz: 70,
        maximumFrequencyHz: 1_000
    )

    #expect(
        detector.detect(
            samples: samples,
            sampleRate: sampleRate
        ) == nil
    )
}

@Test func autocorrelationRejectsNonfiniteInputs() {
    let detector = AutocorrelationPitchDetector()
    #expect(detector.detect(samples: Array(repeating: 1, count: 256), sampleRate: .infinity) == nil)
    #expect(detector.detect(samples: Array(repeating: .nan, count: 256), sampleRate: 44_100) == nil)
}

