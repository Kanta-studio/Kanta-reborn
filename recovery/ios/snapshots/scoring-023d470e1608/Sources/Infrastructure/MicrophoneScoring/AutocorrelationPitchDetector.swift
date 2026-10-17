import Foundation

public struct DetectedPitch:
    Equatable,
    Sendable
{
    public let frequencyHz: Double
    public let confidence: Double
    public let rms: Double

    public init(
        frequencyHz: Double,
        confidence: Double,
        rms: Double
    ) {
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.rms = rms
    }
}

public struct AutocorrelationPitchDetector: Sendable {
    public var minimumFrequencyHz: Double
    public var maximumFrequencyHz: Double
    public var minimumRMS: Double
    public var minimumCorrelation: Double

    public init(
        minimumFrequencyHz: Double = 70,
        maximumFrequencyHz: Double = 1_000,
        minimumRMS: Double = 0.008,
        minimumCorrelation: Double = 0.60
    ) {
        self.minimumFrequencyHz = minimumFrequencyHz
        self.maximumFrequencyHz = maximumFrequencyHz
        self.minimumRMS = minimumRMS
        self.minimumCorrelation = minimumCorrelation
    }

    public func detect(
        samples: [Float],
        sampleRate: Double
    ) -> DetectedPitch? {
        guard sampleRate.isFinite, sampleRate > 0,
              minimumFrequencyHz.isFinite, maximumFrequencyHz.isFinite,
              samples.allSatisfy({ $0.isFinite }),
              samples.count >= 256,
              minimumFrequencyHz > 0,
              maximumFrequencyHz > minimumFrequencyHz else {
            return nil
        }

        let mean =
            samples.reduce(0.0) {
                $0 + Double($1)
            }
            / Double(samples.count)

        let centered = samples.map {
            Double($0) - mean
        }
        let rms = sqrt(
            centered.reduce(0.0) {
                $0 + $1 * $1
            } / Double(centered.count)
        )

        guard rms >= minimumRMS else {
            return nil
        }

        // Search above the configured singing range as well so a
        // high-frequency tone cannot be accepted as an in-range
        // subharmonic. The first strong autocorrelation peak is the
        // candidate fundamental; the configured range is applied
        // after that candidate is measured.
        let analysisMaximumFrequency = min(
            sampleRate / 4,
            max(maximumFrequencyHz * 2, 5_000)
        )
        let analysisMinimumLag = max(
            2,
            Int(min(Double(centered.count / 2), sampleRate / analysisMaximumFrequency))
        )
        let maximumLag = min(
            centered.count / 2 - 1,
            Int(min(Double(centered.count / 2), sampleRate / minimumFrequencyHz))
        )
        guard maximumLag > analysisMinimumLag + 2 else {
            return nil
        }

        var correlations = Array(
            repeating: 0.0,
            count: maximumLag + 2
        )
        var maximumCorrelation = -1.0

        for lag in (analysisMinimumLag - 1)...(maximumLag + 1) {
            let correlation = normalizedCorrelation(
                centered,
                lag: lag
            )
            correlations[lag] = correlation
            maximumCorrelation = max(
                maximumCorrelation,
                correlation
            )
        }

        guard maximumCorrelation >= minimumCorrelation else {
            return nil
        }

        let acceptance = max(
            minimumCorrelation,
            maximumCorrelation * 0.97
        )
        var selectedLag: Int?

        for lag in analysisMinimumLag...maximumLag {
            let value = correlations[lag]
            if value >= acceptance,
               value >= correlations[lag - 1],
               value >= correlations[lag + 1] {
                selectedLag = lag
                break
            }
        }

        guard let lag = selectedLag else {
            return nil
        }

        var refinedLag = Double(lag)
        if lag > analysisMinimumLag, lag < maximumLag {
            let previous = correlations[lag - 1]
            let current = correlations[lag]
            let next = correlations[lag + 1]
            let denominator =
                previous - 2 * current + next

            if abs(denominator) > 0.000_001 {
                let delta =
                    0.5 * (previous - next)
                    / denominator
                if abs(delta) <= 1 {
                    refinedLag += delta
                }
            }
        }

        guard refinedLag > 0 else { return nil }

        let frequency = sampleRate / refinedLag
        guard frequency >= minimumFrequencyHz,
              frequency <= maximumFrequencyHz else {
            return nil
        }

        return DetectedPitch(
            frequencyHz: frequency,
            confidence: min(
                max(correlations[lag], 0),
                1
            ),
            rms: rms
        )
    }

    private func normalizedCorrelation(
        _ samples: [Double],
        lag: Int
    ) -> Double {
        let count = samples.count - lag
        guard count > 0 else { return 0 }

        var numerator = 0.0
        var firstEnergy = 0.0
        var secondEnergy = 0.0

        for index in 0..<count {
            let first = samples[index]
            let second = samples[index + lag]
            numerator += first * second
            firstEnergy += first * first
            secondEnergy += second * second
        }

        let denominator = sqrt(
            firstEnergy * secondEnergy
        )
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}


