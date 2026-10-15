import Foundation
import GeloKaraokeCore
import Testing
@testable import LibraryStorage

@Test func indexedCatalogBuildsStableLegacySongsFromValidatedIndex() throws {
    let sourceID = UUID(
        uuidString:
            "00000000-0000-0000-0000-000000000456"
    )!
    let source = LibrarySourceRecord(
        id: sourceID,
        displayName: "Reference Library",
        bookmarkData: Data(),
        addedAt: Date(
            timeIntervalSince1970: 0
        ),
        lastScan: LibraryScanResult(
            rootDisplayName: "Reference Library",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath:
                        "legacy/index.bin",
                    sizeBytes: 100,
                    kind: .libraryIndex
                ),
                DiscoveredLibraryAsset(
                    relativePath:
                        "legacy/media.container",
                    sizeBytes: 32,
                    kind: .libraryContainer
                ),
                DiscoveredLibraryAsset(
                    relativePath:
                        "sound/default-bank.sf2",
                    sizeBytes: 10,
                    kind: .soundFont
                )
            ]
        )
    )

    let index = makeCatalogIndex(
        titles: ["Alpha", "Beta"],
        offsets: [0, 16]
    )
    let root = try temporaryDirectory()
    defer {
        try? FileManager.default
            .removeItem(at: root)
    }
    let containerURL =
        root.appendingPathComponent(
            "media.container"
        )
    try Data(
        repeating: 0,
        count: 32
    ).write(to: containerURL)

    let entries =
        try IndexedContainerCatalog.entries(
            for: source,
            indexData: index,
            containerURL: containerURL
        )

    #expect(entries.count == 2)
    #expect(
        entries.map(\.song.title)
            == ["Alpha", "Beta"]
    )
    #expect(
        entries.allSatisfy {
            $0.song.mediaKind
                == .legacyContainer
        }
    )
    #expect(
        entries[0].song.id.rawValue
            == "indexed:00000000-0000-0000-0000-000000000456:0"
    )
    #expect(
        entries[1].recordIndex == 1
    )
    #expect(
        entries[0].payloadSpan.startOffset
            == 0
    )
    #expect(
        entries[0].payloadSpan.endOffset
            == 16
    )
    #expect(
        entries[0].payloadSpan.source
            == .trailingOffsetTable
    )
    #expect(
        entries[0].indexRelativePath
            == "legacy/index.bin"
    )
    #expect(
        entries[0].blobRelativePath
            == "legacy/media.container"
    )
    #expect(
        entries[0].soundFontRelativePath
            == "sound/default-bank.sf2"
    )
}


@Test func indexedCatalogUsesPreferredBYOLSoundFont() {
    let source = LibrarySourceRecord(
        displayName: "Reference Library",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Reference Library",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "legacy/index.bin",
                    sizeBytes: 100,
                    kind: .libraryIndex
                ),
                DiscoveredLibraryAsset(
                    relativePath: "legacy/media.container",
                    sizeBytes: 128,
                    kind: .libraryContainer
                ),
                DiscoveredLibraryAsset(
                    relativePath: "sound/default-bank.sf2",
                    sizeBytes: 98_600_000,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath:
                        "SoundFonts/USER/custom.sf2",
                    sizeBytes: 948_500_000,
                    kind: .soundFont
                )
            ]
        ),
        preferredSoundFontRelativePath:
            "SoundFonts/USER/custom.sf2"
    )

    let files = IndexedContainerCatalog.sourceFiles(
        for: source
    )

    #expect(
        files?.soundFontRelativePath
            == "SoundFonts/USER/custom.sf2"
    )
}

@Test func indexedCatalogRejectsType9IdentifierTableEvenWithProtectedPayloadHeaders() throws {
    let source = LibrarySourceRecord(
        displayName: "Legacy Sample",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Legacy Sample",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "index.bin",
                    sizeBytes: 100,
                    kind: .libraryIndex
                ),
                DiscoveredLibraryAsset(
                    relativePath: "media.container",
                    sizeBytes: 128,
                    kind: .libraryContainer
                )
            ]
        )
    )

    let index = makeCatalogIndex(
        titles: ["One", "Two"],
        offsets: [
            0x504a0009,
            0x34dd0009
        ]
    )

    var blob = Data(
        repeating: 0,
        count: 128
    )
    writeProtectedPayloadHeader(
        into: &blob,
        at: 0
    )
    writeProtectedPayloadHeader(
        into: &blob,
        at: 64
    )

    let root = try temporaryDirectory()
    defer {
        try? FileManager.default
            .removeItem(at: root)
    }
    let containerURL =
        root.appendingPathComponent(
            "media.container"
        )
    try blob.write(to: containerURL)

    #expect(
        throws:
            IndexedContainerCatalogError
                .offsetCorrelationRejected
    ) {
        _ = try IndexedContainerCatalog.entries(
            for: source,
            indexData: index,
            containerURL: containerURL
        )
    }
}

@Test func indexedCatalogRejectsUnboundedOffsetsWithoutMatchingProtectedPayloads() throws {
    let source = LibrarySourceRecord(
        displayName: "Bad",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Bad",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "index.bin",
                    sizeBytes: 100,
                    kind: .libraryIndex
                ),
                DiscoveredLibraryAsset(
                    relativePath: "media.container",
                    sizeBytes: 8,
                    kind: .libraryContainer
                )
            ]
        )
    )

    let index = makeCatalogIndex(
        titles: ["One", "Two"],
        offsets: [0, 64]
    )

    let root = try temporaryDirectory()
    defer {
        try? FileManager.default
            .removeItem(at: root)
    }
    let containerURL =
        root.appendingPathComponent(
            "media.container"
        )
    try Data(
        repeating: 0,
        count: 8
    ).write(to: containerURL)

    #expect(
        throws:
            IndexedContainerCatalogError
                .offsetCorrelationRejected
    ) {
        _ = try IndexedContainerCatalog.entries(
            for: source,
            indexData: index,
            containerURL: containerURL
        )
    }
}

private func makeCatalogIndex(
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
        appendCatalogUInt32LE(
            UInt32(recordIndex + 1),
            to: &index
        )
        appendCatalogUInt32LE(
            UInt32(recordIndex + 2),
            to: &index
        )
        index.append(
            contentsOf: titleBytes
        )
    }

    for offset in offsets {
        appendCatalogUInt32LE(
            offset,
            to: &index
        )
    }

    return index
}

private func writeProtectedPayloadHeader(
    into data: inout Data,
    at offset: Int
) {
    let header: [UInt8] = [
        0x4d, 0x4b, 0x4d, 0x44,
        0x01,
        0x1a, 0x00, 0x00, 0x00,
        0x10, 0x00, 0x00, 0x00
    ]
    data.replaceSubrange(
        offset..<(offset + header.count),
        with: header
    )
}

private func temporaryDirectory() throws -> URL {
    let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
    try FileManager.default
        .createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    return url
}

private func appendCatalogUInt32LE(
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



@Test func standaloneIndexRemainsSearchableWithoutPlaybackOffsets() throws {
    let source = LibrarySourceRecord(
        displayName: "Titles only", bookmarkData: Data(),
        lastScan: LibraryScanResult(rootDisplayName: "Titles only", assets: [
            DiscoveredLibraryAsset(relativePath: "titles.bin", sizeBytes: 100, kind: .libraryIndex)
        ])
    )
    #expect(IndexedContainerCatalog.indexRelativePath(for: source) == "titles.bin")
    #expect(IndexedContainerCatalog.sourceFiles(for: source) == nil)
    let index = makeCatalogIndex(titles: ["One", "Two"], offsets: [0x504a0009, 0x34dd0009])
    let songs = try IndexedContainerCatalog.catalogOnlySongs(for: source, indexData: index)
    #expect(songs.map(\.title) == ["One", "Two"])
    #expect(songs.allSatisfy { !$0.isPlayable })
    #expect(songs[0].id.rawValue == "indexed:" + source.id.uuidString.lowercased() + ":0")
    #expect(throws: IndexedContainerCatalogError.malformedTitleIndex) {
        _ = try IndexedContainerCatalog.catalogOnlySongs(for: source, indexData: Data())
    }
}
