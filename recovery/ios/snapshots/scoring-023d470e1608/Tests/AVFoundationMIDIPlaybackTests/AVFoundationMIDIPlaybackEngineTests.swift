#if canImport(AVFoundation)
import Foundation
import GeloKaraokeCore
import Testing
@testable import AVFoundationMIDIPlayback

@Test func midiEngineRequiresSoundFont() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mid")
    defer { try? FileManager.default.removeItem(at: url) }

    try minimalMIDI().write(to: url)

    let engine = AVFoundationMIDIPlaybackEngine()

    await #expect(throws: AudioPlaybackEngineError.missingSoundFont) {
        try await engine.load(
            AudioPlaybackAsset(
                songID: SongID(rawValue: "midi"),
                url: url,
                mediaKind: .midi
            )
        )
    }
}

@Test func midiEngineRejectsFileAudio() async {
    let engine = AVFoundationMIDIPlaybackEngine()

    await #expect(
        throws: AudioPlaybackEngineError.unsupportedMediaKind(.mp3)
    ) {
        try await engine.load(
            AudioPlaybackAsset(
                songID: SongID(rawValue: "audio"),
                url: URL(fileURLWithPath: "/tmp/audio.mp3"),
                mediaKind: .mp3
            )
        )
    }
}

private func minimalMIDI() -> Data {
    Data([
        0x4D, 0x54, 0x68, 0x64,
        0x00, 0x00, 0x00, 0x06,
        0x00, 0x00,
        0x00, 0x01,
        0x01, 0xE0,
        0x4D, 0x54, 0x72, 0x6B,
        0x00, 0x00, 0x00, 0x04,
        0x00, 0xFF, 0x2F, 0x00
    ])
}
#endif

