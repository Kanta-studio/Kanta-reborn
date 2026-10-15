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


#if canImport(AVFoundation)
import AVFoundation

@Test func originalStarterSoundFontProducesNonSilentAudio() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/StarterKaraoke")
    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()
    engine.attach(sampler)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    engine.connect(sampler, to: engine.mainMixerNode, format: format)
    try sampler.loadSoundBankInstrument(at: root.appendingPathComponent("kanta-tone.sf2"),
        program: 0, bankMSB: 0x79, bankLSB: 0)
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    try engine.start()
    defer { engine.stop() }
    sampler.startNote(60, withVelocity: 88, onChannel: 0)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
    var peak: Float = 0
    for _ in 0..<8 {
        let status = try engine.renderOffline(1024, to: buffer)
        #expect(status == .success)
        if let samples = buffer.floatChannelData?[0] {
            for index in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[index])) }
        }
    }
    sampler.stopNote(60, onChannel: 0)
    #expect(peak > 0.001)
}
#endif
