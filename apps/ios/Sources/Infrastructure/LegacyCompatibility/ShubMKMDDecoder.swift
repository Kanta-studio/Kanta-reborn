import Foundation
import GeloKaraokeCore
import GeloLegacyCompression

struct ShubMKMDHeader: Equatable, Sendable {
    static let byteCount: UInt64 = 13
    static let currentVersion: UInt8 = 1

    let version: UInt8
    let decodedByteCount: UInt64
    let compressedByteCount: UInt64
    let encryptedByteCount: UInt64
}

enum ShubMKMDDecodeError:
    Error,
    Equatable,
    Sendable
{
    case truncatedHeader
    case invalidMagic
    case unsupportedVersion(UInt8)
    case invalidDeclaredSize
    case compressedPayloadTooLarge(UInt64)
    case decodedPayloadTooLarge(UInt64)
    case truncatedCiphertext(
        required: UInt64,
        available: UInt64
    )
    case codecFailure(Int32)
    case decodedSizeMismatch(
        expected: UInt64,
        actual: UInt64
    )
    case unsupportedDecodedSignature(
        LegacyPayloadSignature
    )
}

extension ShubMKMDDecodeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .truncatedHeader:
            return "The MKMD song header is truncated."
        case .invalidMagic:
            return "The legacy payload is not a valid MKMD song."
        case let .unsupportedVersion(version):
            return "MKMD version \(version) is not supported."
        case .invalidDeclaredSize:
            return "The MKMD song declares an invalid payload size."
        case let .compressedPayloadTooLarge(size):
            return "The compressed MKMD payload exceeds the safety limit (\(size) bytes)."
        case let .decodedPayloadTooLarge(size):
            return "The decoded MKMD payload exceeds the safety limit (\(size) bytes)."
        case let .truncatedCiphertext(required, available):
            return "The MKMD song is incomplete (needs \(required) encrypted bytes, has \(available))."
        case let .codecFailure(status):
            return "The MKMD decoder rejected the payload (codec status \(status))."
        case let .decodedSizeMismatch(expected, actual):
            return "The MKMD decoded size did not match its header (expected \(expected), got \(actual))."
        case let .unsupportedDecodedSignature(signature):
            return "The decoded MKMD media type is unsupported (\(signature.rawValue))."
        }
    }
}

enum ShubMKMDDecoder {
    static let maximumCompressedByteCount:
        UInt64 = 64 * 1024 * 1024
    static let maximumDecodedByteCount:
        UInt64 = 64 * 1024 * 1024

    // Compatibility material is isolated here instead of leaking into
    // storage or presentation code. It is used only for user-supplied
    // legacy libraries and never for bundled/distributed song content.
    private static let key: [UInt8] = [
        0x9e, 0xac, 0x94, 0xf7,
        0xd1, 0xab, 0xf0, 0xc1,
        0xe0, 0x8e, 0x9f, 0x67,
        0xd3, 0xa2, 0xf6, 0xfc,
        0x45, 0xfd, 0xa3, 0x1d,
        0x24, 0x77, 0x70, 0x2d,
        0xae, 0x56, 0x5b, 0x25,
        0x9c, 0x49, 0xfe, 0x6b
    ]

    private static let iv: [UInt8] = Array(
        "JtNpObAv6714@*#&".utf8
    )

    static func readHeader(
        blobURL: URL,
        startOffset: UInt64,
        spanByteCount: UInt64
    ) throws -> ShubMKMDHeader {
        guard spanByteCount >= ShubMKMDHeader.byteCount else {
            throw ShubMKMDDecodeError.truncatedHeader
        }

        let handle = try FileHandle(
            forReadingFrom: blobURL
        )
        defer { try? handle.close() }

        try handle.seek(toOffset: startOffset)
        let data = try handle.read(
            upToCount: Int(ShubMKMDHeader.byteCount)
        ) ?? Data()

        return try parseHeader(
            data,
            spanByteCount: spanByteCount
        )
    }

    static func parseHeader(
        _ data: Data,
        spanByteCount: UInt64
    ) throws -> ShubMKMDHeader {
        guard spanByteCount >= ShubMKMDHeader.byteCount,
              data.count >= Int(ShubMKMDHeader.byteCount) else {
            throw ShubMKMDDecodeError.truncatedHeader
        }
        guard data.prefix(4) == Data("MKMD".utf8) else {
            throw ShubMKMDDecodeError.invalidMagic
        }

        let version = data[4]
        guard version == ShubMKMDHeader.currentVersion else {
            throw ShubMKMDDecodeError
                .unsupportedVersion(version)
        }

        let decodedByteCount = UInt64(
            readUInt32LE(data, at: 5)
        )
        let compressedByteCount = UInt64(
            readUInt32LE(data, at: 9)
        )

        guard decodedByteCount > 0,
              compressedByteCount > 0 else {
            throw ShubMKMDDecodeError.invalidDeclaredSize
        }
        guard compressedByteCount
                <= maximumCompressedByteCount else {
            throw ShubMKMDDecodeError
                .compressedPayloadTooLarge(
                    compressedByteCount
                )
        }
        guard decodedByteCount
                <= maximumDecodedByteCount else {
            throw ShubMKMDDecodeError
                .decodedPayloadTooLarge(
                    decodedByteCount
                )
        }

        let encryptedByteCount =
            roundUpToAESBlock(compressedByteCount)
        let availableCiphertext =
            spanByteCount - ShubMKMDHeader.byteCount

        guard encryptedByteCount
                <= availableCiphertext else {
            throw ShubMKMDDecodeError
                .truncatedCiphertext(
                    required: encryptedByteCount,
                    available: availableCiphertext
                )
        }

        return ShubMKMDHeader(
            version: version,
            decodedByteCount: decodedByteCount,
            compressedByteCount: compressedByteCount,
            encryptedByteCount: encryptedByteCount
        )
    }

    static func materialize(
        blobURL: URL,
        startOffset: UInt64,
        spanByteCount: UInt64,
        destinationURL: URL
    ) throws -> MediaKind {
        let header = try readHeader(
            blobURL: blobURL,
            startOffset: startOffset,
            spanByteCount: spanByteCount
        )

        var outputByteCount: UInt64 = 0

        let status: Int32 = key.withUnsafeBytes {
            keyBuffer in
            iv.withUnsafeBytes { ivBuffer in
                blobURL.path.withCString {
                    inputPath in
                    destinationURL.path.withCString {
                        outputPath in
                        gelo_aes256_cbc_raw_inflate_file_range(
                            inputPath,
                            startOffset
                                + ShubMKMDHeader.byteCount,
                            header.encryptedByteCount,
                            header.compressedByteCount,
                            keyBuffer.bindMemory(
                                to: UInt8.self
                            ).baseAddress,
                            ivBuffer.bindMemory(
                                to: UInt8.self
                            ).baseAddress,
                            outputPath,
                            header.decodedByteCount,
                            &outputByteCount
                        )
                    }
                }
            }
        }

        guard status == GELO_INFLATE_OK else {
            throw ShubMKMDDecodeError.codecFailure(
                status
            )
        }
        guard outputByteCount
                == header.decodedByteCount else {
            try? FileManager.default.removeItem(
                at: destinationURL
            )
            throw ShubMKMDDecodeError
                .decodedSizeMismatch(
                    expected: header.decodedByteCount,
                    actual: outputByteCount
                )
        }

        let signature = try decodedSignature(
            at: destinationURL
        )
        switch signature {
        case .standardMIDI:
            return .midi
        case .wave:
            return .wav
        case .mp3ID3:
            return .mp3
        case .mkmdV1, .zip, .gzip, .unknown:
            try? FileManager.default.removeItem(
                at: destinationURL
            )
            throw ShubMKMDDecodeError
                .unsupportedDecodedSignature(
                    signature
                )
        }
    }

    private static func decodedSignature(
        at url: URL
    ) throws -> LegacyPayloadSignature {
        let handle = try FileHandle(
            forReadingFrom: url
        )
        defer { try? handle.close() }
        let prefix = try handle.read(
            upToCount: 16
        ) ?? Data()
        return ShubBlobPayloadProbe.signature(
            for: prefix
        )
    }

    private static func roundUpToAESBlock(
        _ value: UInt64
    ) -> UInt64 {
        let remainder = value % 16
        return remainder == 0
            ? value
            : value + (16 - remainder)
    }

    private static func readUInt32LE(
        _ data: Data,
        at offset: Int
    ) -> UInt32 {
        var value: UInt32 = 0
        for byteIndex in 0..<4 {
            value |= UInt32(data[offset + byteIndex])
                << UInt32(byteIndex * 8)
        }
        return value
    }
}

