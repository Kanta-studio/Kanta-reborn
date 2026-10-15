import Foundation

public enum LegacyBlobOffsetVerdict: String, Equatable, Codable, Sendable {
    case unavailable
    case rejected
    case structurallyPlausible
}

public struct LegacyBlobOffsetCorrelation: Equatable, Codable, Sendable {
    public let blobByteCount: Int?
    public let trailingValueCount: Int
    public let trailingValueSamples: [UInt32]
    public let minimumTrailingValue: UInt32?
    public let maximumTrailingValue: UInt32?
    public let nonIncreasingTransitionCount: Int
    public let outOfBoundsValueCount: Int?
    public let candidatePayloadByteCount: Int?
    public let verdict: LegacyBlobOffsetVerdict
}

public enum ShubBlobOffsetCorrelator {
    public static func correlate(
        trailingValues: [UInt32],
        expectedTitleCount: Int,
        blobByteCount: Int?,
        sampleLimit: Int = 128
    ) -> LegacyBlobOffsetCorrelation {
        let samples = Array(trailingValues.prefix(max(0, sampleLimit)))
        let minimum = trailingValues.min()
        let maximum = trailingValues.max()

        var nonIncreasingTransitionCount = 0
        if trailingValues.count > 1 {
            for index in 1..<trailingValues.count {
                if trailingValues[index] <= trailingValues[index - 1] {
                    nonIncreasingTransitionCount += 1
                }
            }
        }

        guard let blobByteCount else {
            return LegacyBlobOffsetCorrelation(
                blobByteCount: nil,
                trailingValueCount: trailingValues.count,
                trailingValueSamples: samples,
                minimumTrailingValue: minimum,
                maximumTrailingValue: maximum,
                nonIncreasingTransitionCount: nonIncreasingTransitionCount,
                outOfBoundsValueCount: nil,
                candidatePayloadByteCount: nil,
                verdict: .unavailable
            )
        }

        let outOfBoundsValueCount = trailingValues.reduce(into: 0) { count, value in
            if blobByteCount <= 0 || UInt64(value) >= UInt64(blobByteCount) {
                count += 1
            }
        }

        let hasExpectedCardinality =
            expectedTitleCount > 0 &&
            trailingValues.count == expectedTitleCount
        let hasStrictOrdering =
            trailingValues.count == 1 || nonIncreasingTransitionCount == 0
        let valuesAreBounded = outOfBoundsValueCount == 0
        let structurallyPlausible =
            hasExpectedCardinality &&
            hasStrictOrdering &&
            valuesAreBounded

        let candidatePayloadByteCount: Int?
        if structurallyPlausible, let first = trailingValues.first {
            candidatePayloadByteCount = blobByteCount - Int(first)
        } else {
            candidatePayloadByteCount = nil
        }

        return LegacyBlobOffsetCorrelation(
            blobByteCount: blobByteCount,
            trailingValueCount: trailingValues.count,
            trailingValueSamples: samples,
            minimumTrailingValue: minimum,
            maximumTrailingValue: maximum,
            nonIncreasingTransitionCount: nonIncreasingTransitionCount,
            outOfBoundsValueCount: outOfBoundsValueCount,
            candidatePayloadByteCount: candidatePayloadByteCount,
            verdict: structurallyPlausible ? .structurallyPlausible : .rejected
        )
    }
}

