import Foundation
import GeloKaraokeCore

// Neutral interoperability facade. Vendor-/format-specific implementation
// details stay confined to the private compatibility files behind this API.

public typealias ContainerOffsetVerdict = LegacyBlobOffsetVerdict
public typealias ContainerOffsetCorrelation = LegacyBlobOffsetCorrelation
public typealias IndexedLibraryProbeResult = ShubIndexProbeResult
public typealias IndexedTitleRecord = LegacyTitleIndexRecord
public typealias ContainerPayloadSpan = LegacyPayloadSpan
public typealias ResolvedContainerPayload = LegacyResolvedPayload

public enum ContainerOffsetCorrelator {
    public static func correlate(
        trailingValues: [UInt32],
        expectedTitleCount: Int,
        containerByteCount: Int?,
        sampleLimit: Int = 128
    ) -> ContainerOffsetCorrelation {
        ShubBlobOffsetCorrelator.correlate(
            trailingValues: trailingValues,
            expectedTitleCount: expectedTitleCount,
            blobByteCount: containerByteCount,
            sampleLimit: sampleLimit
        )
    }
}

public enum IndexedLibraryProbe {
    public static func inspect(
        _ data: Data,
        containerByteCount: Int? = nil,
        sampleLimit: Int = 128
    ) -> IndexedLibraryProbeResult {
        ShubIndexProbe.inspect(
            data,
            shubblobByteCount: containerByteCount,
            sampleLimit: sampleLimit
        )
    }

    public static func decodeTitleRecords(
        _ data: Data
    ) -> [IndexedTitleRecord] {
        ShubIndexProbe.decodeTitleRecords(data)
    }

    public static func trailingUInt32Values(
        in data: Data
    ) -> [UInt32] {
        ShubIndexProbe.trailingUInt32Values(in: data)
    }
}

public enum ContainerPayloadProbe {
    public static func containsRecognizedPayload(
        indexData: Data,
        containerURL: URL,
        sampleLimit: Int = 8
    ) -> Bool {
        guard let report = try? ShubBlobPayloadProbe.inspect(
            indexData: indexData,
            blobURL: containerURL,
            sampleLimit: sampleLimit,
            prefixByteCount: 16
        ) else {
            return false
        }

        return report.samples.contains {
            switch $0.signature {
            case .standardMIDI, .wave, .mp3ID3, .mkmdV1:
                true
            case .zip, .gzip, .unknown:
                false
            }
        }
    }
}

public enum ContainerSpanIndex {
    public static func spans(
        indexData: Data,
        containerURL: URL
    ) throws -> [ContainerPayloadSpan] {
        try ShubBlobSpanIndex.spans(
            indexData: indexData,
            blobURL: containerURL
        )
    }
}

public typealias ContainerPayloadResolver = ShubBlobPayloadResolver

