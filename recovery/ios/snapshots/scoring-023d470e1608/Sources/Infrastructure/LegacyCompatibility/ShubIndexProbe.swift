import Foundation

public struct LegacyMetadataRecord: Equatable, Codable, Sendable {
    public let offset: Int
    public let kind: UInt8
    public let declaredLength: UInt8
    public let metadataHex: String
    public let text: String
}

public struct LegacyTitleIndexRecord: Equatable, Codable, Sendable {
    public let offset: Int
    public let declaredLength: UInt8
    public let opaqueA: UInt32
    public let opaqueB: UInt32
    public let title: String
}

public struct ShubIndexProbeResult: Equatable, Codable, Sendable {
    public let fileSize: Int
    public let headerWordsLE: [UInt32]
    public let metadataTableOffset: Int?
    public let metadataRecordCount: Int
    public let metadataRecordCountsByKind: [UInt8: Int]
    public let metadataSamples: [LegacyMetadataRecord]
    public let firstUnparsedOffset: Int?
    public let firstUnparsedKind: UInt8?
    public let titleIndexOffset: Int?
    public let titleIndexRecordCount: Int
    public let titleIndexSamples: [LegacyTitleIndexRecord]
    public let trailingOffset: Int?
    public let trailingByteCount: Int
    public let trailingBytesPerTitleRecord: Int?
    public let blobOffsetCorrelation: LegacyBlobOffsetCorrelation
}

public enum ShubIndexProbe {
    /// Research-only structural probe. It never mutates the input and keeps unknown
    /// fields opaque until their semantics are confirmed against additional fixtures.
    public static func inspect(
        _ data: Data,
        shubblobByteCount: Int? = nil,
        sampleLimit: Int = 128
    ) -> ShubIndexProbeResult {
        let headerWords = readHeaderWords(data, count: 7)
        let candidateOffset = headerWords.count > 5 ? Int(headerWords[5]) : nil

        guard let start = candidateOffset, start >= 0, start < data.count else {
            return ShubIndexProbeResult(
                fileSize: data.count,
                headerWordsLE: headerWords,
                metadataTableOffset: nil,
                metadataRecordCount: 0,
                metadataRecordCountsByKind: [:],
                metadataSamples: [],
                firstUnparsedOffset: nil,
                firstUnparsedKind: nil,
                titleIndexOffset: nil,
                titleIndexRecordCount: 0,
                titleIndexSamples: [],
                trailingOffset: nil,
                trailingByteCount: 0,
                trailingBytesPerTitleRecord: nil,
                blobOffsetCorrelation: ShubBlobOffsetCorrelator.correlate(
                    trailingValues: [],
                    expectedTitleCount: 0,
                    blobByteCount: shubblobByteCount,
                    sampleLimit: sampleLimit
                )
            )
        }

        var metadataSamples: [LegacyMetadataRecord] = []
        var metadataCounts: [UInt8: Int] = [:]
        var offset = start
        var metadataRecordCount = 0

        while offset + 2 <= data.count {
            let kind = data[offset]
            guard kind != 1, let prefixLength = metadataPrefixLength(for: kind) else {
                break
            }

            let totalLength = Int(data[offset + 1])
            guard totalLength >= prefixLength,
                  totalLength > 0,
                  offset + totalLength <= data.count else {
                break
            }

            let metadata = data[(offset + 2)..<(offset + prefixLength)]
            let payload = data[(offset + prefixLength)..<(offset + totalLength)]
            metadataRecordCount += 1
            metadataCounts[kind, default: 0] += 1

            if metadataSamples.count < max(0, sampleLimit) {
                metadataSamples.append(
                    LegacyMetadataRecord(
                        offset: offset,
                        kind: kind,
                        declaredLength: UInt8(totalLength),
                        metadataHex: metadata
                            .map { String(format: "%02x", $0) }
                            .joined(),
                        text: decodeText(payload)
                    )
                )
            }

            offset += totalLength
        }

        let titleIndexOffset = offset < data.count && data[offset] == 1 ? offset : nil
        var titleSamples: [LegacyTitleIndexRecord] = []
        var titleCount = 0

        while offset + 12 <= data.count, data[offset] == 1 {
            let totalLength = Int(data[offset + 1])
            guard totalLength >= 12, offset + totalLength <= data.count else {
                break
            }

            let opaqueA = readUInt32LE(data, at: offset + 4)
            let opaqueB = readUInt32LE(data, at: offset + 8)
            let payload = data[(offset + 12)..<(offset + totalLength)]
            titleCount += 1

            if titleSamples.count < max(0, sampleLimit) {
                titleSamples.append(
                    LegacyTitleIndexRecord(
                        offset: offset,
                        declaredLength: UInt8(totalLength),
                        opaqueA: opaqueA,
                        opaqueB: opaqueB,
                        title: decodeText(payload)
                    )
                )
            }

            offset += totalLength
        }

        let trailingByteCount = max(0, data.count - offset)
        let trailingBytesPerTitleRecord: Int? =
            titleCount > 0 && trailingByteCount % titleCount == 0
            ? trailingByteCount / titleCount
            : nil
        let trailingValues = readTrailingUInt32Values(
            data,
            offset: offset,
            titleCount: titleCount,
            bytesPerTitleRecord: trailingBytesPerTitleRecord
        )
        let blobOffsetCorrelation = ShubBlobOffsetCorrelator.correlate(
            trailingValues: trailingValues,
            expectedTitleCount: titleCount,
            blobByteCount: shubblobByteCount,
            sampleLimit: sampleLimit
        )

        return ShubIndexProbeResult(
            fileSize: data.count,
            headerWordsLE: headerWords,
            metadataTableOffset: start,
            metadataRecordCount: metadataRecordCount,
            metadataRecordCountsByKind: metadataCounts,
            metadataSamples: metadataSamples,
            firstUnparsedOffset: titleIndexOffset,
            firstUnparsedKind: titleIndexOffset.map { data[$0] },
            titleIndexOffset: titleIndexOffset,
            titleIndexRecordCount: titleCount,
            titleIndexSamples: titleSamples,
            trailingOffset: offset < data.count ? offset : nil,
            trailingByteCount: trailingByteCount,
            trailingBytesPerTitleRecord: trailingBytesPerTitleRecord,
            blobOffsetCorrelation: blobOffsetCorrelation
        )
    }

    public static func decodeTitleRecords(_ data: Data) -> [LegacyTitleIndexRecord] {
        let report = inspect(data, sampleLimit: 0)
        guard var offset = report.titleIndexOffset else {
            return []
        }

        var records: [LegacyTitleIndexRecord] = []
        records.reserveCapacity(report.titleIndexRecordCount)

        while offset + 12 <= data.count, data[offset] == 1 {
            let totalLength = Int(data[offset + 1])
            guard totalLength >= 12, offset + totalLength <= data.count else {
                break
            }

            records.append(
                LegacyTitleIndexRecord(
                    offset: offset,
                    declaredLength: UInt8(totalLength),
                    opaqueA: readUInt32LE(data, at: offset + 4),
                    opaqueB: readUInt32LE(data, at: offset + 8),
                    title: decodeText(data[(offset + 12)..<(offset + totalLength)])
                )
            )
            offset += totalLength
        }

        return records
    }

    public static func trailingUInt32Values(in data: Data) -> [UInt32] {
        let report = inspect(data, sampleLimit: 0)
        guard let offset = report.trailingOffset else {
            return []
        }

        return readTrailingUInt32Values(
            data,
            offset: offset,
            titleCount: report.titleIndexRecordCount,
            bytesPerTitleRecord: report.trailingBytesPerTitleRecord
        )
    }

    private static func metadataPrefixLength(for kind: UInt8) -> Int? {
        switch kind {
        case 2, 3:
            return 6
        case 4, 5:
            return 5
        case 6, 7:
            return 4
        default:
            return nil
        }
    }

    private static func readTrailingUInt32Values(
        _ data: Data,
        offset: Int,
        titleCount: Int,
        bytesPerTitleRecord: Int?
    ) -> [UInt32] {
        guard titleCount > 0, bytesPerTitleRecord == 4 else {
            return []
        }

        return (0..<titleCount).map { index in
            readUInt32LE(data, at: offset + index * 4)
        }
    }

    private static func decodeText(_ bytes: Data.SubSequence) -> String {
        let data = Data(bytes)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        return "<binary>"
    }

    private static func readHeaderWords(_ data: Data, count: Int) -> [UInt32] {
        stride(from: 0, to: min(data.count, count * 4), by: 4).compactMap { offset in
            guard offset + 4 <= data.count else { return nil }
            return readUInt32LE(data, at: offset)
        }
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for byteIndex in 0..<4 {
            value |= UInt32(data[offset + byteIndex]) << UInt32(byteIndex * 8)
        }
        return value
    }
}

