import Foundation
import GeloKaraokeCore
#if canImport(AVFoundation)
import AVFoundation

public actor KantaPartySFXEngine: PartySFXPlayback {
    private let root: URL
    private var voices: [(PartySFX, AVAudioPlayer)] = []
    private var volume: Float = 0.4
    public init(storageDirectory: URL) { root = storageDirectory }
    public func trigger(_ sound: PartySFX) async throws {
        voices.removeAll { !$0.1.isPlaying }
        if voices.count >= 4 { voices.removeFirst().1.stop() }
        let custom = clipURL(sound)
        let player = try FileManager.default.fileExists(atPath: custom.path)
            ? AVAudioPlayer(contentsOf: custom) : AVAudioPlayer(data: Self.synthesize(sound))
        player.volume = volume
        guard player.prepareToPlay(), player.play() else { throw CocoaError(.fileReadCorruptFile) }
        voices.append((sound, player))
    }
    public func stopAll() async { voices.forEach { $0.1.stop() }; voices.removeAll() }
    public func setSFXVolume(_ value: Float) async {
        volume = value.isFinite ? min(max(value, 0), 0.65) : 0
        voices.forEach { $0.1.volume = volume }
    }
    public func hasCustomSound(_ sound: PartySFX) -> Bool {
        FileManager.default.fileExists(atPath: clipURL(sound).path)
    }
    public func resetClip(for sound: PartySFX) throws {
        let url = clipURL(sound)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    public func importClip(from source: URL, for sound: PartySFX) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 5 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let audio = try AVAudioFile(forReading: source)
        let seconds = Double(audio.length) / audio.processingFormat.sampleRate
        guard seconds.isFinite, seconds > 0, seconds <= 10 else { throw CocoaError(.fileReadCorruptFile) }
        let bytes = try Data(contentsOf: source)
        guard bytes.count == size else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try bytes.write(to: clipURL(sound), options: .atomic)
    }
    private func clipURL(_ sound: PartySFX) -> URL { root.appendingPathComponent(sound.rawValue + ".clip") }
    private static func synthesize(_ sound: PartySFX) -> Data {
        let rate = 22050, count = rate * 2
        let notes: [PartySFX: Double] = [.applause: 180, .cheering: 650, .drumRoll: 100,
            .airHorn: 220, .laughter: 420, .taDa: 523.25, .ding: 1046.5, .sadTrombone: 174.6]
        var seed: UInt32 = 0x4B414E54
        var samples = Data(capacity: count * 2)
        for i in 0..<count {
            let t = Double(i) / Double(rate), decay = exp(-t * (sound == .ding ? 4 : 1.8))
            seed = 1664525 &* seed &+ 1013904223
            let noise = Double(seed >> 16) / 32768 - 1
            let base = notes[sound] ?? 440
            let frequency = sound == .sadTrombone ? base * pow(2, -t / 4) : base
            let tone = sin(2 * .pi * frequency * t) + 0.25 * sin(2 * .pi * frequency * 1.5 * t)
            let noisy = sound == .applause || sound == .drumRoll || sound == .cheering
            let pulse = sound == .laughter ? max(0, sin(t * 24)) : 1
            let value = (noisy ? noise * (0.4 + 0.6 * abs(sin(t * 38))) : tone * 0.5) * decay * pulse
            var sample = Int16(max(-1, min(1, value)) * 24000).littleEndian
            withUnsafeBytes(of: &sample) { samples.append(contentsOf: $0) }
        }
        var data = Data("RIFF".utf8)
        func u32(_ n: UInt32) { var x = n.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { var x = n.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        u32(UInt32(36 + samples.count)); data.append(Data("WAVEfmt ".utf8)); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        data.append(Data("data".utf8)); u32(UInt32(samples.count)); data.append(samples); return data
    }
}
#endif
