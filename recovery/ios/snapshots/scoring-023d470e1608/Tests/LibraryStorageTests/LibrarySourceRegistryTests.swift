import Foundation
import Testing
@testable import LibraryStorage

@Test func registryRoundTripsRecords() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let registryURL = directory.appendingPathComponent("sources.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let registry = try LibrarySourceRegistry(fileURL: registryURL)
    let record = LibrarySourceRecord(
        displayName: "Songs",
        bookmarkData: Data([1, 2, 3])
    )

    try await registry.upsert(record)

    let reloaded = try LibrarySourceRegistry(fileURL: registryURL)
    let all = await reloaded.all()

    #expect(all.count == 1)
    #expect(all[0].displayName == "Songs")
    #expect(all[0].bookmarkData == Data([1, 2, 3]))
    #expect(reloaded.recoveryNotice == nil)
}

@Test func registryQuarantinesCorruptStateAndStartsEmpty() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let registryURL = directory.appendingPathComponent("sources.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let corruptData = Data("{not-valid-json".utf8)
    try corruptData.write(to: registryURL)

    let registry = try LibrarySourceRegistry(
        fileURL: registryURL
    )
    let records = await registry.all()

    #expect(records.isEmpty)
    #expect(
        !FileManager.default.fileExists(
            atPath: registryURL.path
        )
    )

    let notice = try #require(registry.recoveryNotice)
    let backupURL = directory.appendingPathComponent(
        notice.backupFileName
    )

    #expect(
        FileManager.default.fileExists(
            atPath: backupURL.path
        )
    )
    #expect(try Data(contentsOf: backupURL) == corruptData)
}

@Test func recoveredRegistryCanPersistNewSources() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let registryURL = directory.appendingPathComponent("sources.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    try Data("broken".utf8).write(to: registryURL)

    let registry = try LibrarySourceRegistry(
        fileURL: registryURL
    )
    try await registry.upsert(
        LibrarySourceRecord(
            displayName: "Recovered Songs",
            bookmarkData: Data([7, 8, 9])
        )
    )

    let reloaded = try LibrarySourceRegistry(
        fileURL: registryURL
    )
    let records = await reloaded.all()

    #expect(records.count == 1)
    #expect(records[0].displayName == "Recovered Songs")
    #expect(reloaded.recoveryNotice == nil)
}

@Test func registryFailedWritesPreserveCommittedRecords() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sources.json")
    let registry = try LibrarySourceRegistry(fileURL: url)
    let original = LibrarySourceRecord(displayName: "Original", bookmarkData: Data([1]))
    try await registry.upsert(original)
    try FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    // An occupied directory reliably prevents atomic file replacement, even as root.
    try Data([1]).write(to: url.appendingPathComponent("blocker"))
    var changed = original
    changed.displayName = "Uncommitted"
    do {
        try await registry.upsert(changed)
        Issue.record("Expected persistence failure")
    } catch {}
    #expect(await registry.all() == [original])
    do {
        try await registry.remove(id: original.id)
        Issue.record("Expected persistence failure")
    } catch {}
    #expect(await registry.all() == [original])
}

@Test func registryQuarantinesDuplicateIdentifiers() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("sources.json")
    let record = LibrarySourceRecord(displayName: "Duplicate", bookmarkData: Data())
    let bytes = try JSONEncoder().encode([record, record])
    try bytes.write(to: url)
    let registry = try LibrarySourceRegistry(fileURL: url)
    #expect(await registry.all().isEmpty)
    let notice = try #require(registry.recoveryNotice)
    #expect(try Data(contentsOf: directory.appendingPathComponent(notice.backupFileName)) == bytes)
}

@Test func bookmarkRefreshDoesNotResurrectRemovedSources() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let registry = try LibrarySourceRegistry(fileURL: directory.appendingPathComponent("sources.json"))
    let record = LibrarySourceRecord(displayName: "Removed", bookmarkData: Data([1]))
    try await registry.upsert(record)
    try await registry.remove(id: record.id)
    try await registry.refreshBookmark(id: record.id, bookmarkData: Data([2]))
    #expect(await registry.all().isEmpty)
}

