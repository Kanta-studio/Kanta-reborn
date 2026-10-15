import Foundation
import Testing
import GeloKaraokeCore
@testable import LibraryStorage
#if canImport(CryptoKit)
import CryptoKit
#endif

private func recoverySong(_ id: String = "1", title: String = "Morning Light") -> LibrarySong {
    LibrarySong(id: SongID(rawValue: id), code: id, title: title, artist: "KANTA Originals", mediaKind: .kar)
}
private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); return root
}
@Test func durableSaveRetryDoesNotDuplicateACollection() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("sets.json"), key = UUID()
    let store = try SavedKaraokeSetStore(fileURL: file)
    let first = try await store.save(name: "Friday", songs: [recoverySong(), recoverySong()], idempotencyKey: key)
    let reopened = try SavedKaraokeSetStore(fileURL: file)
    let retry = try await reopened.save(name: "Retry", songs: [], idempotencyKey: key)
    let all = await reopened.all()
    #expect(retry.id == first.id)
    #expect(all.count == 1)
    #expect(retry.songs.count == 2) // Intentional repeated songs survive.
}
@Test func failedWriteDoesNotPublishAStorageMutation() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let parent = root.appendingPathComponent("parent"), file = parent.appendingPathComponent("sets.json")
    let store = try SavedKaraokeSetStore(fileURL: file)
    try Data("obstruction".utf8).write(to: parent)
    var failed = false
    do { _ = try await store.save(name: "Friday", songs: [recoverySong()]) } catch { failed = true }
    let all = await store.all()
    #expect(failed); #expect(all.isEmpty)
}
@Test func catalogHandlesUnicodeAndLiteralSearchSafely() throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let catalog = try SQLiteSongCatalog(fileURL: root.appendingPathComponent("catalog.sqlite"))
    try catalog.replaceIfChanged([recoverySong("1", title: "Kántá Together"), recoverySong("2")])
    let matching = try catalog.search("kanta together", limit: 50, offset: 0)
    let injection = try catalog.search("' OR 1=1 --", limit: 50, offset: 0)
    #expect(matching.map { $0.id.rawValue } == ["1"]); #expect(injection.isEmpty)
    try catalog.replaceIfChanged([recoverySong("2")])
    let removed = try catalog.search("together", limit: 50, offset: 0)
    #expect(removed.isEmpty)
}
@Test func songbookCSVQuotesMetadataAndNeutralizesFormulas() {
    let bytes = KantaSongbookCSV.encode([recoverySong(title: "=HYPERLINK(\"example\")\nA,B")])
    let csv = String(decoding: bytes, as: UTF8.self)
    #expect(csv.hasPrefix("KANTA Code,Song Title,Artist,Availability\r\n"))
    #expect(csv.contains("\"'=HYPERLINK(\"\"example\"\")\nA,B\""))
    #expect(!csv.contains("file://"))
}
#if canImport(CryptoKit)
@Test func privateSongbookMatchesTheCapturedBrowserEnvelope() throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let csv = root.appendingPathComponent("book.csv"), original = KantaSongbookCSV.encode([recoverySong()])
    try original.write(to: csv)
    let export = try KantaPrivateSongbook.makeExport(csvURL: csv)
    defer { try? FileManager.default.removeItem(at: export.url) }
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: export.url)) as? [String: Any])
    #expect(object["format"] as? String == "kanta-private-songbook")
    #expect(object["version"] as? Int == 1); #expect(export.accessCode.count == 32)
    let payload = try #require(object["payload"] as? String)
    let combined = try #require(Data(base64Encoded: payload))
    let digest = SHA256.hash(data: Data(("KANTA-SONGBOOK-V1:" + export.accessCode).utf8))
    let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(data: digest))
    #expect(plain == original)
    let second = try KantaPrivateSongbook.makeExport(csvURL: csv)
    defer { try? FileManager.default.removeItem(at: second.url) }
    #expect(second.accessCode != export.accessCode); #expect(second.url != export.url)
}
#endif
