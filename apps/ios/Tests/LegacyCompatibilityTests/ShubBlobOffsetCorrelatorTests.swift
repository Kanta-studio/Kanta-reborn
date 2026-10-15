import Foundation
import Testing
@testable import LegacyCompatibility

@Test func correlatorAcceptsStrictlyIncreasingBoundedOffsets() {
    let result = ShubBlobOffsetCorrelator.correlate(
        trailingValues: [16, 24, 40],
        expectedTitleCount: 3,
        blobByteCount: 64,
        sampleLimit: 2
    )

    #expect(result.verdict == .structurallyPlausible)
    #expect(result.trailingValueCount == 3)
    #expect(result.trailingValueSamples == [16, 24])
    #expect(result.minimumTrailingValue == 16)
    #expect(result.maximumTrailingValue == 40)
    #expect(result.nonIncreasingTransitionCount == 0)
    #expect(result.outOfBoundsValueCount == 0)
    #expect(result.candidatePayloadByteCount == 48)
}

@Test func correlatorRejectsNonIncreasingOrOutOfBoundsOffsets() {
    let result = ShubBlobOffsetCorrelator.correlate(
        trailingValues: [16, 16, 80],
        expectedTitleCount: 3,
        blobByteCount: 64
    )

    #expect(result.verdict == .rejected)
    #expect(result.nonIncreasingTransitionCount == 1)
    #expect(result.outOfBoundsValueCount == 1)
    #expect(result.candidatePayloadByteCount == nil)
}

@Test func correlatorKeepsVerdictUnavailableWithoutUserBlob() {
    let result = ShubBlobOffsetCorrelator.correlate(
        trailingValues: [16, 24],
        expectedTitleCount: 2,
        blobByteCount: nil
    )

    #expect(result.verdict == .unavailable)
    #expect(result.outOfBoundsValueCount == nil)
}


@Test func probeCorrelatesOneTrailingUInt32PerTitleAgainstBlobSize() {
    var data = Data(repeating: 0, count: 28)
    data.replaceSubrange(20..<24, with: [28, 0, 0, 0])

    data.append(contentsOf: [0x01, 0x0d, 0x01, 0x00, 1, 0, 0, 0, 2, 0, 0, 0])
    data.append(contentsOf: Array("A".utf8))

    data.append(contentsOf: [0x01, 0x0d, 0x01, 0x00, 3, 0, 0, 0, 4, 0, 0, 0])
    data.append(contentsOf: Array("B".utf8))

    data.append(contentsOf: [16, 0, 0, 0])
    data.append(contentsOf: [32, 0, 0, 0])

    let report = ShubIndexProbe.inspect(
        data,
        shubblobByteCount: 64
    )

    #expect(report.titleIndexRecordCount == 2)
    #expect(report.trailingBytesPerTitleRecord == 4)
    #expect(report.blobOffsetCorrelation.trailingValueCount == 2)
    #expect(report.blobOffsetCorrelation.verdict == .structurallyPlausible)
    #expect(report.blobOffsetCorrelation.trailingValueSamples == [16, 32])
}

