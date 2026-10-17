import Foundation
import Testing
@testable import LegacyCompatibility

@Test func payloadProbeReadsCandidateSpansWithoutLoadingWholeBlob() throws {
    let index = makeIndex(offsets: [0, 16])

    var blob = Data()
    blob.append(contentsOf: Array("MThd".utf8))
    blob.append(Data(repeating: 0, count: 12))
    blob.append(contentsOf: Array("ID3".utf8))
    blob.append(Data(repeating: 0, count: 13))

    let url = try writeTemporaryBlob(blob)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try ShubBlobPayloadProbe.inspect(
        indexData: index,
        blobURL: url,
        sampleLimit: 2
    )

    #expect(result.blobByteCount == 32)
    #expect(result.candidateSpanCount == 2)
    #expect(
        result.samples.map(\.signature)
            == [.standardMIDI, .mp3ID3]
    )
    #expect(
        result.samples.map(\.byteCount)
            == [16, 16]
    )
    #expect(
        result.signatureCounts[.standardMIDI] == 1
    )
    #expect(
        result.signatureCounts[.mp3ID3] == 1
    )
}

@Test func payloadProbeIdentifiesMKMDV1Envelope() throws {
    let index = makeIndex(offsets: [0])
    let blob = Data([
        0x4d, 0x4b, 0x4d, 0x44,
        0x01,
        0x1a, 0x00, 0x00, 0x00,
        0x19, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00
    ])

    let url = try writeTemporaryBlob(blob)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try ShubBlobPayloadProbe.inspect(
        indexData: index,
        blobURL: url,
        sampleLimit: 1
    )

    #expect(result.samples.count == 1)
    #expect(result.samples[0].signature == .mkmdV1)
    #expect(result.signatureCounts[.mkmdV1] == 1)
}

@Test func payloadProbeDistributesBoundedSamplesAcrossCandidateRange() throws {
    let index = makeIndex(
        offsets: [0, 8, 16, 24, 32]
    )

    var blob = Data()
    blob.append(
        contentsOf:
            Array("MThd".utf8) + [0, 0, 0, 0]
    )
    blob.append(
        contentsOf:
            Array("NONE".utf8) + [0, 0, 0, 0]
    )
    blob.append(
        contentsOf:
            Array("ID3!".utf8) + [0, 0, 0, 0]
    )
    blob.append(
        contentsOf:
            [0x50, 0x4b, 0x03, 0x04, 0, 0, 0, 0]
    )
    blob.append(
        contentsOf:
            [0x1f, 0x8b, 0, 0, 0, 0, 0, 0]
    )

    let url = try writeTemporaryBlob(blob)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try ShubBlobPayloadProbe.inspect(
        indexData: index,
        blobURL: url,
        sampleLimit: 3,
        prefixByteCount: 4
    )

    #expect(result.candidateSpanCount == 5)
    #expect(
        result.samples.map(\.recordIndex)
            == [0, 2, 4]
    )
    #expect(
        result.samples.map(\.signature)
            == [.standardMIDI, .mp3ID3, .gzip]
    )
    #expect(
        result.samples.map(\.prefixHex)
            == [
                "4d546864",
                "49443321",
                "1f8b0000"
            ]
    )
    #expect(
        result.samples.last?.endOffset
            == UInt64(blob.count)
    )
}

@Test func payloadProbeRejectsNonMonotonicCandidateOffsets() throws {
    let index = makeIndex(
        offsets: [16, 16]
    )
    let url = try writeTemporaryBlob(
        Data(repeating: 0, count: 32)
    )
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(
        throws:
            ShubBlobPayloadProbeError
                .offsetCorrelationRejected
    ) {
        _ = try ShubBlobPayloadProbe.inspect(
            indexData: index,
            blobURL: url
        )
    }
}

private func makeIndex(
    offsets: [UInt32]
) -> Data {
    var index = Data(
        repeating: 0,
        count: 28
    )
    index.replaceSubrange(
        20..<24,
        with: [28, 0, 0, 0]
    )

    for recordIndex in offsets.indices {
        index.append(contentsOf: [
            0x01, 0x0d, 0x01, 0x00,
            UInt8(
                truncatingIfNeeded:
                    recordIndex + 1
            ), 0, 0, 0,
            UInt8(
                truncatingIfNeeded:
                    recordIndex + 2
            ), 0, 0, 0
        ])
        index.append(
            UInt8(ascii: "A")
                + UInt8(
                    truncatingIfNeeded:
                        recordIndex
                )
        )
    }

    for offset in offsets {
        index.append(contentsOf: [
            UInt8(
                truncatingIfNeeded:
                    offset
            ),
            UInt8(
                truncatingIfNeeded:
                    offset >> 8
            ),
            UInt8(
                truncatingIfNeeded:
                    offset >> 16
            ),
            UInt8(
                truncatingIfNeeded:
                    offset >> 24
            )
        ])
    }

    return index
}

private func writeTemporaryBlob(
    _ data: Data
) throws -> URL {
    let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString
            )
    try data.write(to: url)
    return url
}

