import Foundation
import GeloKaraokeCore
import Testing
@testable import LegacyCompatibility

@Test func payloadResolverMaterializesOnlySelectedNativeSpan() throws {
    let index = makeResolverIndex(
        titles: ["Alpha", "Beta"],
        offsets: [0, 16]
    )

    var blob = Data()
    blob.append(contentsOf: Array("MThd".utf8))
    blob.append(Data(repeating: 0, count: 12))
    blob.append(contentsOf: Array("ID3".utf8))
    blob.append(Data(repeating: 0, count: 13))

    let root =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    let blobURL =
        root.appendingPathComponent("shubblob")
    try blob.write(to: blobURL)

    let result =
        try ShubBlobPayloadResolver.materialize(
            indexData: index,
            blobURL: blobURL,
            recordIndex: 0,
            destinationDirectory:
                root.appendingPathComponent(
                    "cache"
                )
        )

    #expect(result.payload.recordIndex == 0)
    #expect(result.payload.startOffset == 0)
    #expect(result.payload.endOffset == 16)
    #expect(result.payload.byteCount == 16)
    #expect(
        result.payload.signature
            == .standardMIDI
    )
    #expect(
        result.payload.mediaKind == .midi
    )
    #expect(
        result.url.pathExtension == "mid"
    )

    let extracted = try Data(
        contentsOf: result.url
    )
    #expect(
        extracted == Data(blob.prefix(16))
    )
}

@Test func payloadResolverDecodesMKMDV1ToNativeMIDI() throws {
    let expectedMIDI = Data([
        0x4d, 0x54, 0x68, 0x64,
        0x00, 0x00, 0x00, 0x06,
        0x00, 0x00, 0x00, 0x01,
        0x00, 0x60,
        0x4d, 0x54, 0x72, 0x6b,
        0x00, 0x00, 0x00, 0x04,
        0x00, 0xff, 0x2f, 0x00
    ])

    // MKMD v1 fixture generated from the expected MIDI using
    // AES-256-CBC and raw DEFLATE according to the Android
    // processMidiData compatibility path.
    let blob = Data(hex:
        "4d4b4d44011a00000019000000"
        + "7da85c44923c3146777be15483cb10f3"
        + "a2c14960804776333a73a975123fc6a7"
    )
    let index = makeResolverIndex(
        titles: ["Protected"],
        offsets: [0]
    )

    let root =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    let blobURL =
        root.appendingPathComponent("shubblob")
    try blob.write(to: blobURL)

    let result =
        try ShubBlobPayloadResolver.materialize(
            indexData: index,
            blobURL: blobURL,
            recordIndex: 0,
            destinationDirectory:
                root.appendingPathComponent(
                    "cache"
                )
        )

    #expect(
        result.payload.signature == .mkmdV1
    )
    #expect(
        result.payload.mediaKind == .midi
    )
    #expect(
        result.url.pathExtension == "mid"
    )
    #expect(
        try Data(contentsOf: result.url)
            == expectedMIDI
    )
}

@Test func payloadResolverRejectsTruncatedMKMDCiphertext() throws {
    let blob = Data(hex:
        "4d4b4d44011a00000019000000"
        + "7da85c44923c3146777be15483cb10f3"
    )
    let index = makeResolverIndex(
        titles: ["Broken"],
        offsets: [0]
    )

    let root =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    let blobURL =
        root.appendingPathComponent("shubblob")
    try blob.write(to: blobURL)

    #expect(
        throws:
            ShubMKMDDecodeError
                .truncatedCiphertext(
                    required: 32,
                    available: 16
                )
    ) {
        _ = try ShubBlobPayloadResolver.resolve(
            indexData: index,
            blobURL: blobURL,
            recordIndex: 0
        )
    }
}

@Test func payloadResolverStillRejectsUnprovenZipPayload() throws {
    let index = makeResolverIndex(
        titles: ["Compressed"],
        offsets: [0]
    )

    var blob = Data([
        0x50, 0x4b, 0x03, 0x04
    ])
    blob.append(
        Data(repeating: 0, count: 28)
    )

    let root =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    let blobURL =
        root.appendingPathComponent("shubblob")
    try blob.write(to: blobURL)

    #expect(
        throws:
            ShubBlobPayloadResolveError
                .unsupportedPayloadSignature(
                    .zip
                )
    ) {
        _ = try ShubBlobPayloadResolver.resolve(
            indexData: index,
            blobURL: blobURL,
            recordIndex: 0
        )
    }
}

@Test func indexProbeDecodesAllTitlesWithoutCapturingMetadataSamples() {
    let index = makeResolverIndex(
        titles: [
            "One",
            "Two",
            "Three"
        ],
        offsets: [0, 8, 16]
    )

    let records =
        ShubIndexProbe.decodeTitleRecords(
            index
        )
    let offsets =
        ShubIndexProbe.trailingUInt32Values(
            in: index
        )

    #expect(
        records.map(\.title)
            == ["One", "Two", "Three"]
    )
    #expect(
        offsets == [0, 8, 16]
    )
}

private func makeResolverIndex(
    titles: [String],
    offsets: [UInt32]
) -> Data {
    precondition(
        titles.count == offsets.count
    )

    var index = Data(
        repeating: 0,
        count: 28
    )
    index.replaceSubrange(
        20..<24,
        with: [28, 0, 0, 0]
    )

    for (
        recordIndex,
        title
    ) in titles.enumerated() {
        let titleBytes =
            Array(title.utf8)
        index.append(contentsOf: [
            0x01,
            UInt8(
                12 + titleBytes.count
            ),
            0x00,
            0x00
        ])
        appendUInt32LE(
            UInt32(recordIndex + 1),
            to: &index
        )
        appendUInt32LE(
            UInt32(recordIndex + 2),
            to: &index
        )
        index.append(
            contentsOf: titleBytes
        )
    }

    for offset in offsets {
        appendUInt32LE(
            offset,
            to: &index
        )
    }

    return index
}

private func appendUInt32LE(
    _ value: UInt32,
    to data: inout Data
) {
    data.append(contentsOf: [
        UInt8(
            truncatingIfNeeded:
                value
        ),
        UInt8(
            truncatingIfNeeded:
                value >> 8
        ),
        UInt8(
            truncatingIfNeeded:
                value >> 16
        ),
        UInt8(
            truncatingIfNeeded:
                value >> 24
        )
    ])
}

private extension Data {
    init(hex: String) {
        precondition(
            hex.count.isMultiple(of: 2)
        )

        self.init()
        reserveCapacity(
            hex.count / 2
        )

        var index = hex.startIndex
        while index < hex.endIndex {
            let next =
                hex.index(
                    index,
                    offsetBy: 2
                )
            let byte = UInt8(
                hex[index..<next],
                radix: 16
            )!
            append(byte)
            index = next
        }
    }
}

@Test func payloadResolverRejectsOversizedExternalSpan() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("MThd".utf8).write(to: url)
    let span = LegacyPayloadSpan(recordIndex: 0, startOffset: 0,
                                 endOffset: UInt64.max, source: .trailingOffsetTable)
    #expect(throws: ShubBlobPayloadResolveError.invalidSpan) {
        try ShubBlobPayloadResolver.resolve(blobURL: url, span: span, prefixByteCount: .max)
    }
}

