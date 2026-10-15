import Foundation
import GeloKaraokeCore
import Testing
@testable import LibraryStorage

@Test func catalogBuildsStableLooseSongsAndUsesDeterministicSF2() {
    let sourceID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000123"
    )!

    let source = LibrarySourceRecord(
        id: sourceID,
        displayName: "Karaoke",
        bookmarkData: Data(),
        addedAt: Date(timeIntervalSince1970: 0),
        lastScan: LibraryScanResult(
            rootDisplayName: "Karaoke",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "sound/other.sf2",
                    sizeBytes: 10,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath: "sound/z-bank.sf2",
                    sizeBytes: 20,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath: "sound/ignored.sfz",
                    sizeBytes: 30,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/My Song.kar",
                    sizeBytes: 40,
                    kind: .kar
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/Backing.mp3",
                    sizeBytes: 50,
                    kind: .mp3
                )
            ]
        )
    )

    let entries = LooseMediaCatalog.entries(for: source)

    #expect(entries.count == 2)

    let karaoke = entries.first {
        $0.song.mediaKind == .kar
    }
    #expect(karaoke?.song.title == "My Song")
    #expect(
        karaoke?.soundFontRelativePath
            == "sound/other.sf2"
    )
    #expect(
        karaoke?.song.id.rawValue
            == "file:00000000-0000-0000-0000-000000000123:" +
               "songs/My Song.kar"
    )

    let audio = entries.first {
        $0.song.mediaKind == .mp3
    }
    #expect(audio?.soundFontRelativePath == nil)
}


@Test func catalogHonorsPreferredBYOLSoundFont() {
    let source = LibrarySourceRecord(
        displayName: "Karaoke",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Karaoke",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "sound/z-bank.sf2",
                    sizeBytes: 100,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath:
                        "SoundFonts/USER/yamaha-korg-ketron.sf2",
                    sizeBytes: 948_500_000,
                    kind: .soundFont
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/Test Song.kar",
                    sizeBytes: 20,
                    kind: .kar
                )
            ]
        ),
        preferredSoundFontRelativePath:
            "SoundFonts/USER/yamaha-korg-ketron.sf2"
    )

    let entry = LooseMediaCatalog.entries(
        for: source
    ).first

    #expect(
        entry?.soundFontRelativePath
            == "SoundFonts/USER/yamaha-korg-ketron.sf2"
    )
}

@Test func catalogRejectsEscapingPaths() {
    let source = LibrarySourceRecord(
        displayName: "Unsafe",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Unsafe",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "../outside.mid",
                    sizeBytes: 1,
                    kind: .midi
                ),
                DiscoveredLibraryAsset(
                    relativePath: "/absolute.wav",
                    sizeBytes: 1,
                    kind: .wav
                ),
                DiscoveredLibraryAsset(
                    relativePath: "safe/inside.mid",
                    sizeBytes: 1,
                    kind: .midi
                )
            ]
        )
    )

    let entries = LooseMediaCatalog.entries(for: source)
    #expect(entries.map(\.relativePath) == ["safe/inside.mid"])
}


@Test func catalogResolvesDeterministicSongBackgrounds() {
    let source = LibrarySourceRecord(
        displayName: "Visuals",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Visuals",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "songs/My Song.kar",
                    sizeBytes: 10,
                    kind: .kar
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/My Song.jpg",
                    sizeBytes: 10,
                    kind: .backgroundImage
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/My Song.mp4",
                    sizeBytes: 10,
                    kind: .backgroundVideo
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/Other.mid",
                    sizeBytes: 10,
                    kind: .midi
                ),
                DiscoveredLibraryAsset(
                    relativePath: "songs/background.png",
                    sizeBytes: 10,
                    kind: .backgroundImage
                ),
                DiscoveredLibraryAsset(
                    relativePath: "misc/Third.wav",
                    sizeBytes: 10,
                    kind: .wav
                ),
                DiscoveredLibraryAsset(
                    relativePath: "background.jpg",
                    sizeBytes: 10,
                    kind: .backgroundImage
                )
            ]
        )
    )

    let entries = LooseMediaCatalog.entries(for: source)

    let exact = entries.first { $0.song.title == "My Song" }
    #expect(exact?.backgroundRelativePath == "songs/My Song.mp4")
    #expect(exact?.backgroundKind == .video)

    let localDefault = entries.first { $0.song.title == "Other" }
    #expect(
        localDefault?.backgroundRelativePath
            == "songs/background.png"
    )
    #expect(localDefault?.backgroundKind == .image)

    let rootDefault = entries.first { $0.song.title == "Third" }
    #expect(rootDefault?.backgroundRelativePath == "background.jpg")
    #expect(rootDefault?.backgroundKind == .image)
}

@Test func catalogDoesNotUseUnrelatedArtworkAsBackground() {
    let source = LibrarySourceRecord(
        displayName: "No Background",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "No Background",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "songs/Plain.kar",
                    sizeBytes: 10,
                    kind: .kar
                ),
                DiscoveredLibraryAsset(
                    relativePath: "art/cover.jpg",
                    sizeBytes: 10,
                    kind: .backgroundImage
                )
            ]
        )
    )

    let entry = LooseMediaCatalog.entries(for: source).first
    #expect(entry?.backgroundRelativePath == nil)
    #expect(entry?.backgroundKind == nil)
}


@Test func catalogFallsBackToLibraryBackgroundPool() {
    let source = LibrarySourceRecord(
        displayName: "Library",
        bookmarkData: Data(),
        lastScan: LibraryScanResult(
            rootDisplayName: "Library",
            assets: [
                DiscoveredLibraryAsset(
                    relativePath: "songs/Pool Song.kar",
                    sizeBytes: 10,
                    kind: .kar
                ),
                DiscoveredLibraryAsset(
                    relativePath: "bgphoto/1.jpg",
                    sizeBytes: 10,
                    kind: .backgroundImage
                ),
                DiscoveredLibraryAsset(
                    relativePath: "bgv/Nature/Video1.mp4",
                    sizeBytes: 10,
                    kind: .backgroundVideo
                )
            ]
        )
    )

    let entry = LooseMediaCatalog.entries(for: source).first
    #expect(
        entry?.backgroundRelativePath
            == "bgv/Nature/Video1.mp4"
    )
    #expect(entry?.backgroundKind == .video)
}

@Test func catalogRejectsEmbeddedNullPath() {
    #expect(LooseMediaCatalog.normalizedRelativePath("Songs/bad\0.mid") == nil)
}
