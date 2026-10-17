import Foundation

public enum LegacyPayloadSignature:
    String,
    Equatable,
    Codable,
    Sendable
{
    case standardMIDI
    case wave
    case mp3ID3
    case mkmdV1
    case zip
    case gzip
    case unknown
}

public struct LegacyPayloadSpanSample:
    Equatable,
    Codable,
    Sendable
{
    public let recordIndex: Int
    public let startOffset: UInt32
    public let endOffset: UInt64
    public let byteCount: UInt64
    public let prefixHex: String
    public let signature: LegacyPayloadSignature
}

public struct ShubBlobPayloadProbeResult:
    Equatable,
    Codable,
    Sendable
{
    public let blobByteCount: Int
    public let candidateSpanCount: Int
    public let samples: [LegacyPayloadSpanSample]
    public let signatureCounts:
        [LegacyPayloadSignature: Int]
}

public enum ShubBlobPayloadProbeError:
    Error,
    Equatable,
    Sendable
{
    case blobSizeUnavailable
    case trailingTableUnavailable
    case offsetCorrelationRejected
}

public enum ShubBlobPayloadProbe {
    public static func inspect(
        indexData: Data,
        blobURL: URL,
        sampleLimit: Int = 32,
        prefixByteCount: Int = 16
    ) throws -> ShubBlobPayloadProbeResult {
        let attributes = try FileManager.default
            .attributesOfItem(
                atPath: blobURL.path
            )
        guard let sizeNumber =
                attributes[.size] as? NSNumber else {
            throw ShubBlobPayloadProbeError
                .blobSizeUnavailable
        }
        let blobByteCount = sizeNumber.intValue
        let indexReport = ShubIndexProbe.inspect(
            indexData,
            shubblobByteCount: blobByteCount,
            sampleLimit: 0
        )

        guard indexReport
                .trailingBytesPerTitleRecord == 4,
              let trailingOffset =
                indexReport.trailingOffset else {
            throw ShubBlobPayloadProbeError
                .trailingTableUnavailable
        }

        let offsets =
            (0..<indexReport.titleIndexRecordCount)
                .map { index in
                    readUInt32LE(
                        indexData,
                        at: trailingOffset
                            + index * 4
                    )
                }

        let correlation =
            ShubBlobOffsetCorrelator.correlate(
                trailingValues: offsets,
                expectedTitleCount:
                    indexReport.titleIndexRecordCount,
                blobByteCount: blobByteCount,
                sampleLimit: 0
            )
        guard correlation.verdict
                == .structurallyPlausible else {
            throw ShubBlobPayloadProbeError
                .offsetCorrelationRejected
        }

        let handle = try FileHandle(
            forReadingFrom: blobURL
        )
        defer { try? handle.close() }

        var samples: [LegacyPayloadSpanSample] = []
        var signatureCounts:
            [LegacyPayloadSignature: Int] = [:]
        let recordIndices = sampleRecordIndices(
            recordCount: offsets.count,
            limit: sampleLimit
        )

        for index in recordIndices {
            let start = UInt64(offsets[index])
            let end =
                index + 1 < offsets.count
                ? UInt64(offsets[index + 1])
                : UInt64(blobByteCount)
            guard end > start else {
                continue
            }

            try handle.seek(toOffset: start)
            let requested = min(
                max(0, prefixByteCount),
                Int(end - start)
            )
            let prefix =
                try handle.read(
                    upToCount: requested
                ) ?? Data()
            let detectedSignature =
                signature(for: prefix)
            signatureCounts[
                detectedSignature,
                default: 0
            ] += 1

            samples.append(
                LegacyPayloadSpanSample(
                    recordIndex: index,
                    startOffset: offsets[index],
                    endOffset: end,
                    byteCount: end - start,
                    prefixHex: prefix
                        .map {
                            String(
                                format: "%02x",
                                $0
                            )
                        }
                        .joined(),
                    signature: detectedSignature
                )
            )
        }

        return ShubBlobPayloadProbeResult(
            blobByteCount: blobByteCount,
            candidateSpanCount: offsets.count,
            samples: samples,
            signatureCounts: signatureCounts
        )
    }

    /// Returns deterministic indices distributed across the full
    /// candidate set. This keeps I/O bounded while avoiding a
    /// misleading first-N-only sample.
    private static func sampleRecordIndices(
        recordCount: Int,
        limit: Int
    ) -> [Int] {
        guard recordCount > 0,
              limit > 0 else {
            return []
        }

        let sampleCount = min(
            recordCount,
            limit
        )
        guard sampleCount < recordCount else {
            return Array(0..<recordCount)
        }
        guard sampleCount > 1 else {
            return [0]
        }

        return (0..<sampleCount).map {
            sampleIndex in
            sampleIndex
                * (recordCount - 1)
                / (sampleCount - 1)
        }
    }

    public static func signature(
        for prefix: Data
    ) -> LegacyPayloadSignature {
        let bytes = Array(prefix)

        if bytes.starts(
            with: Array("MThd".utf8)
        ) {
            return .standardMIDI
        }

        if bytes.count >= 12,
           Array(bytes[0..<4])
                == Array("RIFF".utf8),
           Array(bytes[8..<12])
                == Array("WAVE".utf8) {
            return .wave
        }

        if bytes.starts(
            with: Array("ID3".utf8)
        ) {
            return .mp3ID3
        }

        if bytes.starts(
            with: Array("MKMD".utf8)
        ) {
            return .mkmdV1
        }

        if bytes.starts(
            with: [0x50, 0x4b, 0x03, 0x04]
        ) {
            return .zip
        }

        if bytes.starts(
            with: [0x1f, 0x8b]
        ) {
            return .gzip
        }

        return .unknown
    }

    private static func readUInt32LE(
        _ data: Data,
        at offset: Int
    ) -> UInt32 {
        var value: UInt32 = 0
        for byteIndex in 0..<4 {
            value |= UInt32(
                data[offset + byteIndex]
            ) << UInt32(byteIndex * 8)
        }
        return value
    }
}

