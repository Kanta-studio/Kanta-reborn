import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum KantaPrivateSongbook {
    public struct Export: Sendable {
        public let url: URL
        public let accessCode: String
    }
    private struct Envelope: Codable {
        let format: String
        let version: Int
        let payload: String
    }
    public static func makeExport(csvURL: URL) throws -> Export {
        #if canImport(CryptoKit)
        let size = try csvURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 16 * 1024 * 1024 else {
            throw CocoaError(.fileReadTooLarge)
        }
        let csv = try Data(contentsOf: csvURL)
        guard csv.count == size else { throw CocoaError(.fileReadCorruptFile) }
        let code = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
            .map { String(format: "%02X", $0) }.joined()
        let digest = SHA256.hash(data: Data(("KANTA-SONGBOOK-V1:" + code).utf8))
        let sealed = try AES.GCM.seal(csv, using: SymmetricKey(data: digest))
        guard let combined = sealed.combined else { throw CocoaError(.fileWriteUnknown) }
        let envelope = Envelope(format: "kanta-private-songbook", version: 1,
                                payload: combined.base64EncodedString())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("KANTA-" + UUID().uuidString + ".kanta-book")
        try JSONEncoder().encode(envelope).write(to: url, options: .atomic)
        return Export(url: url, accessCode: code)
        #else
        throw CocoaError(.featureUnsupported)
        #endif
    }
}
