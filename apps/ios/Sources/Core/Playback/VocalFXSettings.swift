import Foundation

/// DSP knobs for microphone-through-app monitoring. These are separate from
/// the music playback volume/pitch and from the room microphone scoring tap.
public enum VocalFXPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case dry, room, studio, hall, cathedral, plate, echo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dry: "Dry / Clean"
        case .room: "Small Room"
        case .studio: "Studio Vocal"
        case .hall: "Concert Hall"
        case .cathedral: "Cathedral"
        case .plate: "Plate Reverb"
        case .echo: "Echo / Delay"
        }
    }

    public var defaultReverbMix: Float {
        switch self {
        case .dry: 0
        case .room: 18
        case .studio: 25
        case .hall: 42
        case .cathedral: 50
        case .plate: 32
        case .echo: 8
        }
    }

    public var defaultEchoMix: Float {
        self == .echo ? 27 : 0
    }
}

public enum VocalPolishPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case custom, opmBallad, popStar, rockConcert, duet, studioClean, partyKaraoke

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .custom: "Custom"
        case .opmBallad: "OPM Ballad"
        case .popStar: "Pop Star"
        case .rockConcert: "Rock Concert"
        case .duet: "Duet"
        case .studioClean: "Studio Clean"
        case .partyKaraoke: "Party Karaoke"
        }
    }
}

public struct VocalFXSettings: Codable, Equatable, Sendable {
    public var monitorEnabled: Bool
    public var preset: VocalFXPreset
    public var reverbMix: Float
    public var echoMix: Float
    public var bassGain: Float
    public var trebleGain: Float
    public var microphoneLevel: Float
    /// Optional; older Soundcard saves decode with this disabled.
    public var pitchCorrection: VocalPitchCorrection?
    public var polishPreset: VocalPolishPreset
    public var compression: Float
    public var noiseGate: Float
    public var deEsser: Float
    public var doubler: Float
    public var delayMilliseconds: Float

    public init(
        monitorEnabled: Bool = false,
        preset: VocalFXPreset = .dry,
        reverbMix: Float = 0,
        echoMix: Float = 0,
        bassGain: Float = 0,
        trebleGain: Float = 0,
        microphoneLevel: Float = 0.55,
        pitchCorrection: VocalPitchCorrection? = nil,
        polishPreset: VocalPolishPreset = .custom,
        compression: Float = 0.25,
        noiseGate: Float = 0,
        deEsser: Float = 0,
        doubler: Float = 0,
        delayMilliseconds: Float = 220
    ) {
        self.monitorEnabled = monitorEnabled
        self.preset = preset
        self.reverbMix = Self.bounded(reverbMix, 0, 70)
        self.echoMix = Self.bounded(echoMix, 0, 50)
        self.bassGain = Self.bounded(bassGain, -12, 12)
        self.trebleGain = Self.bounded(trebleGain, -12, 12)
        self.microphoneLevel = Self.bounded(microphoneLevel, 0, 0.85)
        self.pitchCorrection = pitchCorrection?.clamped
        self.polishPreset = polishPreset
        self.compression = min(max(compression.isFinite ? compression : 0, 0), 1)
        self.noiseGate = min(max(noiseGate.isFinite ? noiseGate : 0, 0), 1)
        self.deEsser = min(max(deEsser.isFinite ? deEsser : 0, 0), 1)
        self.doubler = min(max(doubler.isFinite ? doubler : 0, 0), 40)
        self.delayMilliseconds = min(max(delayMilliseconds.isFinite ? delayMilliseconds : 220, 70), 700)
    }

    private static func bounded(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, lower), upper)
    }

    /// Ensure restored or edited values cannot exceed safe UI/DSP ranges.
    public var clamped: VocalFXSettings {
        VocalFXSettings(
            monitorEnabled: monitorEnabled,
            preset: preset,
            reverbMix: reverbMix,
            echoMix: echoMix,
            bassGain: bassGain,
            trebleGain: trebleGain,
            microphoneLevel: microphoneLevel,
            pitchCorrection: pitchCorrection,
            polishPreset: polishPreset,
            compression: compression,
            noiseGate: noiseGate,
            deEsser: deEsser,
            doubler: doubler,
            delayMilliseconds: delayMilliseconds
        )
    }
    /// Backward-compatible with preferences and older iCloud settings
    /// saved before the expanded Soundcard shipped.
    private enum CodingKeys: String, CodingKey {
        case monitorEnabled, preset, reverbMix, echoMix, bassGain, trebleGain
        case microphoneLevel, pitchCorrection, polishPreset, compression, noiseGate, deEsser
        case doubler, delayMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            monitorEnabled: try c.decodeIfPresent(Bool.self, forKey: .monitorEnabled) ?? false,
            preset: try c.decodeIfPresent(VocalFXPreset.self, forKey: .preset) ?? .dry,
            reverbMix: try c.decodeIfPresent(Float.self, forKey: .reverbMix) ?? 0,
            echoMix: try c.decodeIfPresent(Float.self, forKey: .echoMix) ?? 0,
            bassGain: try c.decodeIfPresent(Float.self, forKey: .bassGain) ?? 0,
            trebleGain: try c.decodeIfPresent(Float.self, forKey: .trebleGain) ?? 0,
            microphoneLevel: try c.decodeIfPresent(Float.self, forKey: .microphoneLevel) ?? 0.55,
            pitchCorrection: try c.decodeIfPresent(VocalPitchCorrection.self, forKey: .pitchCorrection),
            polishPreset: try c.decodeIfPresent(VocalPolishPreset.self, forKey: .polishPreset) ?? .custom,
            compression: try c.decodeIfPresent(Float.self, forKey: .compression) ?? 0.25,
            noiseGate: try c.decodeIfPresent(Float.self, forKey: .noiseGate) ?? 0,
            deEsser: try c.decodeIfPresent(Float.self, forKey: .deEsser) ?? 0,
            doubler: try c.decodeIfPresent(Float.self, forKey: .doubler) ?? 0,
            delayMilliseconds: try c.decodeIfPresent(Float.self, forKey: .delayMilliseconds) ?? 220
        )
    }

    public mutating func selectPolishPreset(_ selected: VocalPolishPreset) {
        polishPreset = selected
        switch selected {
        case .custom: break
        case .opmBallad:
            compression = 0.45; noiseGate = 0.10; deEsser = 0.25
            doubler = 6; reverbMix = 30; echoMix = 6; preset = .hall
        case .popStar:
            compression = 0.60; noiseGate = 0.20; deEsser = 0.55
            doubler = 24; reverbMix = 22; echoMix = 14; preset = .studio
        case .rockConcert:
            compression = 0.50; noiseGate = 0.30; deEsser = 0.20
            doubler = 14; reverbMix = 18; echoMix = 23; preset = .plate
        case .duet:
            compression = 0.35; noiseGate = 0.08; deEsser = 0.30
            doubler = 16; reverbMix = 24; echoMix = 3; preset = .room
        case .studioClean:
            compression = 0.50; noiseGate = 0.35; deEsser = 0.60
            doubler = 0; reverbMix = 12; echoMix = 0; preset = .studio
        case .partyKaraoke:
            compression = 0.55; noiseGate = 0.25; deEsser = 0.25
            doubler = 22; reverbMix = 35; echoMix = 28; preset = .hall
        }
    }
}

/// Fail closed on speaker, AirPlay and Bluetooth. These output routes can
/// produce acoustic feedback or unacceptable karaoke monitor latency.
public enum VocalMonitoringRoute: String, Sendable {
    case wiredHeadphones, usbAudio, lineOut, unsupported

    public var permitsLiveMonitor: Bool {
        self != .unsupported
    }
}

