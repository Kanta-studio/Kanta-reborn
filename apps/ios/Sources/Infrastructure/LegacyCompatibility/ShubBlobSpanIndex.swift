import Foundation

public enum LegacyPayloadSpanSource:
    String,
    Equatable,
    Codable,
    Sendable
{
    case trailingOffsetTable
}

public struct LegacyPayloadSpan:
    Equatable,
    Codable,
    Sendable
{
    public let recordIndex: Int
    public let startOffset: UInt64
    public let endOffset: UInt64
    public let source: LegacyPayloadSpanSource

    public var byteCount: UInt64 {
        endOffset - startOffset
    }

    public init(
        recordIndex: Int,
        startOffset: UInt64,
        endOffset: UInt64,
        source: LegacyPayloadSpanSource
    ) {
        self.recordIndex = recordIndex
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.source = source
    }
}

public enum ShubBlobSpanIndexError:
    Error,
    Equatable,
    Sendable
{
    case blobSizeUnavailable
    case malformedTitleIndex
    case offsetCorrelationRejected
    case invalidSpan(Int)
}

public enum ShubBlobSpanIndex {
    public static func spans(
        indexData: Data,
        blobURL: URL
    ) throws -> [LegacyPayloadSpan] {
        let attributes =
            try FileManager.default
                .attributesOfItem(
                    atPath: blobURL.path
                )
        guard let sizeNumber =
                attributes[.size] as? NSNumber else {
            throw ShubBlobSpanIndexError
                .blobSizeUnavailable
        }

        let blobByteCount =
            UInt64(sizeNumber.uint64Value)
        let report = ShubIndexProbe.inspect(
            indexData,
            shubblobByteCount: Int(
                min(
                    blobByteCount,
                    UInt64(Int.max)
                )
            ),
            sampleLimit: 0
        )

        guard report.titleIndexRecordCount > 0,
              report.trailingBytesPerTitleRecord == 4 else {
            throw ShubBlobSpanIndexError
                .malformedTitleIndex
        }

        guard report.blobOffsetCorrelation.verdict
                == .structurallyPlausible else {
            throw ShubBlobSpanIndexError
                .offsetCorrelationRejected
        }

        let offsets =
            ShubIndexProbe.trailingUInt32Values(
                in: indexData
            )
            .map(UInt64.init)

        guard offsets.count
                == report.titleIndexRecordCount else {
            throw ShubBlobSpanIndexError
                .malformedTitleIndex
        }

        return try makeSpans(
            offsets: offsets,
            blobByteCount: blobByteCount
        )
    }

    private static func makeSpans(
        offsets: [UInt64],
        blobByteCount: UInt64
    ) throws -> [LegacyPayloadSpan] {
        guard !offsets.isEmpty else {
            throw ShubBlobSpanIndexError
                .malformedTitleIndex
        }

        var spans: [LegacyPayloadSpan] = []
        spans.reserveCapacity(offsets.count)

        for index in offsets.indices {
            let start = offsets[index]
            let end =
                index + 1 < offsets.count
                ? offsets[index + 1]
                : blobByteCount

            guard end > start,
                  end <= blobByteCount else {
                throw ShubBlobSpanIndexError
                    .invalidSpan(index)
            }

            spans.append(
                LegacyPayloadSpan(
                    recordIndex: index,
                    startOffset: start,
                    endOffset: end,
                    source: .trailingOffsetTable
                )
            )
        }

        return spans
    }
}

