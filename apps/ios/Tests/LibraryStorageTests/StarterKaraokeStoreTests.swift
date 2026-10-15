import Foundation
import GeloKaraokeCore
import Testing
@testable import LibraryStorage

private let starterResources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/StarterKaraoke")

private struct StarterFixture {
    let root: URL
    let originals: URL
    let managed: URL
    let store: StarterKaraokeStore
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        originals = root.appendingPathComponent("originals")
        managed = root.appendingPathComponent("managed")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: starterResources, to: originals)
        store = try StarterKaraokeStore(originals: originals, managed: managed)
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
    func library() throws -> BookmarkedKaraokeLibrary {
        BookmarkedKaraokeLibrary(registry: try LibrarySourceRegistry(fileURL: root.appendingPathComponent("sources.json")),
            starterStore: store, starterSoundFontURL: originals.appendingPathComponent("kanta-tone.sf2"),
            catalogFileURL: root.appendingPathComponent("catalog.sqlite"))
    }
}

@Test func starterFilesParseWithTimedWordsLinesAndSeekState() throws {
    let bpms = [96, 108, 84]
    for (index, id) in StarterKaraokeStore.identifiers.enumerated() {
        let file = try StandardMIDIParser.parse(Data(contentsOf: starterResources.appendingPathComponent(id + ".kar")))
        #expect(file.header.format == 0)
        #expect(file.header.timeDivision == .ticksPerQuarterNote(480))
        #expect(file.tracks.count == 1)
        let plan = MIDIPlaybackPlan(file: file)
        let quarter = Double(Int((60_000_000.0 / Double(bpms[index])).rounded())) / 1000
        #expect(abs(Double(plan.durationMilliseconds) - quarter * 16) <= 1)
        #expect(!plan.resumeState(before: 100).activeNotes.isEmpty)
        #expect(plan.resumeState(before: plan.durationMilliseconds).activeNotes.isEmpty)
        let sequence = KaraokeLyricPageSequence(cues: plan.lyrics)
        #expect(sequence.lines.count == 4)
        #expect(sequence.lines.first?.fragments.count == (index == 2 ? 3 : 2))
        for (lineIndex, line) in sequence.lines.enumerated() {
            for (wordIndex, fragment) in line.fragments.enumerated() {
                #expect(abs(Double(fragment.milliseconds) - Double(lineIndex * 4 + wordIndex) * quarter) <= 1)
            }
        }
        let seek = sequence.lines[3].milliseconds
        #expect(sequence.page(atMilliseconds: seek).lines.first == sequence.lines[3])
        #expect(sequence.page(atMilliseconds: 0).lines.first == sequence.lines[0])
        let wordTime = sequence.lines[0].fragments[1].milliseconds
        let page = sequence.page(atMilliseconds: wordTime)
        #expect(page.lines[0].fragments.filter { $0.milliseconds <= page.positionMilliseconds }.count == 2)
    }
}

@Test func starterInstallRemoveRestartAndOfflineRestore() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    let original = try Data(contentsOf: f.originals.appendingPathComponent("morning-light.kar"))
    let installed = try await f.store.installAvailableSongs()
    #expect(installed.count == 3)
    try await f.store.remove("morning-light")
    try await f.store.remove("morning-light")
    let reopened = try StarterKaraokeStore(originals: f.originals, managed: f.managed)
    let afterRestart = try await reopened.installAvailableSongs()
    #expect(afterRestart.count == 2)
    let restored = try await reopened.restore("morning-light")
    let again = try await reopened.restore("morning-light")
    #expect(restored == again)
    #expect(try Data(contentsOf: restored) == original)
    #expect(try Data(contentsOf: f.originals.appendingPathComponent("morning-light.kar")) == original)
}

@Test func concurrentStarterInstallationAndRestoreRemainUnique() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<20 { group.addTask { _ = try await f.store.installAvailableSongs() } }
        try await group.waitForAll()
    }
    try await f.store.remove("sing-together")
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<20 { group.addTask { try await f.store.restoreAll() } }
        try await group.waitForAll()
    }
    let state = await f.store.snapshot()
    #expect(state.urls.count == 3)
    #expect(state.removed.isEmpty)
    let files = try FileManager.default.contentsOfDirectory(atPath: f.managed.path)
    #expect(files.filter { $0.hasSuffix(".kar") }.count == 3)
    #expect(!files.contains { $0.hasSuffix(".tmp") })
}

@Test func starterFailurePreservesTombstoneAndRejectsCorruptState() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    _ = try await f.store.installAvailableSongs()
    try await f.store.remove("morning-light")
    try FileManager.default.removeItem(at: f.originals.appendingPathComponent("morning-light.kar"))
    let beforeFailure = await f.store.snapshot()
    await #expect(throws: (any Error).self) { try await f.store.restoreAll() }
    let afterFailure = await f.store.snapshot()
    #expect(afterFailure.revision > beforeFailure.revision)
    let removed = await f.store.removedIdentifiers()
    #expect(removed.contains("morning-light"))
    await #expect(throws: StarterKaraokeStore.StoreError.unknownSong) {
        _ = try await f.store.restore("../imported")
    }
    try Data("broken".utf8).write(to: f.managed.appendingPathComponent("removed-starters.json"))
    #expect(throws: (any Error).self) {
        try StarterKaraokeStore(originals: f.originals, managed: f.managed)
    }
}

@Test func starterCancellationDoesNotInstallAndSymlinkCannotTouchImports() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    let canceled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try await f.store.installAvailableSongs()
    }
    await #expect(throws: CancellationError.self) { try await canceled.value }
    let before = await f.store.snapshot()
    #expect(before.urls.isEmpty)
    let imported = f.root.appendingPathComponent("user-song.kar")
    let bytes = Data("user owned".utf8)
    try bytes.write(to: imported)
    try FileManager.default.createSymbolicLink(at: f.managed.appendingPathComponent("morning-light.kar"), withDestinationURL: imported)
    await #expect(throws: StarterKaraokeStore.StoreError.unsafeStorage) {
        _ = try await f.store.installIfAllowed("morning-light")
    }
    #expect(try Data(contentsOf: imported) == bytes)
}

@Test func starterCatalogPublishesRemovalAndRestoreWithoutDuplicates() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    let library = try f.library()
    let report = await library.loadIfNeeded()
    #expect(report.issues.isEmpty)
    #expect(report.songCount == 3)
    let song = StarterKaraokeStore.song("morning-light")
    let asset = try await library.playbackAsset(for: song.id)
    #expect(asset.mediaKind == .kar)
    #expect(asset.soundFontURL?.lastPathComponent == "kanta-tone.sf2")
    let cues = try await library.lyricCues(for: song.id)
    #expect(!cues.isEmpty)
    try await library.changeStarterSong("morning-light", restore: false)
    let absent = try await library.song(id: song.id)
    #expect(absent == nil)
    await #expect(throws: (any Error).self) { try await library.playbackAsset(for: song.id) }
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask { try await library.changeStarterSong(nil, restore: true) }
            group.addTask { _ = await library.reload() }
        }
        try await group.waitForAll()
    }
    try await library.changeStarterSong("sing-together", restore: false)
    let final = await library.searchSongs(matching: "")
    #expect(final.count == 2)
    #expect(Set(final.map(\.id)).count == 2)
    let matching = await library.searchSongs(matching: "Morning")
    #expect(matching.map(\.id) == [song.id])
}

@Test func removingStarterPreservesImportedSameNamedSongAndSoundFontPreference() async throws {
    let f = try StarterFixture(); defer { f.cleanup() }
    let user = f.root.appendingPathComponent("user")
    try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
    let userSong = user.appendingPathComponent("morning-light.kar")
    try FileManager.default.copyItem(at: f.originals.appendingPathComponent("morning-light.kar"), to: userSong)
    try FileManager.default.copyItem(at: f.originals.appendingPathComponent("kanta-tone.sf2"), to: user.appendingPathComponent("my-bank.sf2"))
    let bytes = try Data(contentsOf: userSong)
    let registry = try LibrarySourceRegistry(fileURL: f.root.appendingPathComponent("sources.json"))
    let source = LibrarySourceRecord(displayName: "User", bookmarkData: try user.bookmarkData(
        options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil),
        lastScan: LibraryScanResult(rootDisplayName: "User", assets: [
            DiscoveredLibraryAsset(relativePath: "morning-light.kar", sizeBytes: Int64(bytes.count), kind: .kar),
            DiscoveredLibraryAsset(relativePath: "my-bank.sf2", sizeBytes: 1000, kind: .soundFont)]))
    try await registry.upsert(source)
    let library = BookmarkedKaraokeLibrary(registry: registry, starterStore: f.store,
        starterSoundFontURL: f.originals.appendingPathComponent("kanta-tone.sf2"),
        catalogFileURL: f.root.appendingPathComponent("catalog.sqlite"))
    _ = await library.loadIfNeeded()
    let asset = try await library.playbackAsset(for: StarterKaraokeStore.song("morning-light").id)
    #expect(asset.soundFontURL?.lastPathComponent == "my-bank.sf2")
    #expect(asset.fallbackSoundFontURLs.last?.lastPathComponent == "kanta-tone.sf2")
    try await library.changeStarterSong("morning-light", restore: false)
    let imported = await library.searchSongs(matching: "morning")
    #expect(imported.count == 1)
    #expect(imported.first?.id.rawValue.hasPrefix("file:") == true)
    #expect(try Data(contentsOf: userSong) == bytes)
}
