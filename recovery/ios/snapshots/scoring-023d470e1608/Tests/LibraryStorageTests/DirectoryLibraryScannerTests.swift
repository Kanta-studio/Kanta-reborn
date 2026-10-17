import Foundation
import Testing
@testable import LibraryStorage

@Test func scannerRecognizesRenamedIndexedLibraryAndLooseMedia() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let index = makeIndexedLibraryFixture(
        titles: ["Alpha", "Beta"],
        offsets: [0, 16]
    )
    try index.write(
        to: root.appendingPathComponent("catalog-map.bin")
    )

    var container = Data(repeating: 0, count: 32)
    container.replaceSubrange(
        0..<4,
        with: Data("MThd".utf8)
    )
    container.replaceSubrange(
        16..<20,
        with: Data("MThd".utf8)
    )
    try container.write(
        to: root.appendingPathComponent("library-pack.data")
    )

    try validSF2Fixture().write(
        to: root.appendingPathComponent("anything-you-own.sf2")
    )
    try Data([1, 2, 3]).write(
        to: root.appendingPathComponent("song.mid")
    )
    try Data([1, 2, 3]).write(
        to: root.appendingPathComponent("track.kar")
    )
    try Data([1, 2, 3]).write(
        to: root.appendingPathComponent("readme.txt")
    )

    let result = try DirectoryLibraryScanner().scan(root: root)

    #expect(result.hasIndexedLibrary)
    #expect(result.looseSongCount == 2)
    #expect(result.soundFontCount == 1)
    #expect(result.recognizedAssetCount == 5)
    #expect(
        result.assets.first {
            $0.kind == .libraryIndex
        }?.relativePath == "catalog-map.bin"
    )
    #expect(
        result.assets.first {
            $0.kind == .libraryContainer
        }?.relativePath == "library-pack.data"
    )
}

@Test func scannerAcceptsValidSF2RegardlessOfFilename() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    try validSF2Fixture().write(
        to: root.appendingPathComponent("My Custom Karaoke Bank.sf2")
    )
    try Data([1, 2, 3]).write(
        to: root.appendingPathComponent("fake.sf2")
    )

    let result = try DirectoryLibraryScanner().scan(root: root)

    #expect(result.soundFontCount == 1)
    #expect(
        result.assets.first {
            $0.kind == .soundFont
        }?.relativePath == "My Custom Karaoke Bank.sf2"
    )
    #expect(
        result.assets.first {
            $0.relativePath == "fake.sf2"
        }?.kind == .other
    )
}

@Test func scannerDoesNotFollowSymbolicLinks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let outside = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: outside,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: outside)
    }

    try Data([1]).write(
        to: outside.appendingPathComponent("hidden.mid")
    )
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("linked"),
        withDestinationURL: outside
    )

    let result = try DirectoryLibraryScanner().scan(root: root)
    #expect(result.looseSongCount == 0)
}

private func validSF2Fixture() -> Data {
    var data = Data("RIFF".utf8)
    data.append(contentsOf: [0, 0, 0, 0])
    data.append(Data("sfbk".utf8))
    return data
}

private func makeIndexedLibraryFixture(
    titles: [String],
    offsets: [UInt32]
) -> Data {
    precondition(titles.count == offsets.count)

    var index = Data(repeating: 0, count: 28)
    index.replaceSubrange(
        20..<24,
        with: [28, 0, 0, 0]
    )

    for (recordIndex, title) in titles.enumerated() {
        let titleBytes = Array(title.utf8)
        index.append(contentsOf: [
            0x01,
            UInt8(12 + titleBytes.count),
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
        index.append(contentsOf: titleBytes)
    }

    for offset in offsets {
        appendUInt32LE(offset, to: &index)
    }

    return index
}

private func appendUInt32LE(
    _ value: UInt32,
    to data: inout Data
) {
    data.append(contentsOf: [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ])
}

