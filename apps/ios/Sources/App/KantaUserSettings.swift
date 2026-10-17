import Combine
import Foundation
import GeloKaraokeCore

@MainActor
final class KantaUserSettings: ObservableObject {
    private enum Key {
        static let stageVisualsEnabled =
            "kanta.settings.stageVisualsEnabled"
        static let visualPreset =
            "kanta.settings.visualPreset"
        static let scoringLatency =
            "kanta.settings.scoringLatency"
        static let scoringEnabled =
            "kanta.settings.scoringEnabled"
        static let vocalEffects = "kanta.settings.vocalEffects.v1"
        static let partySFXVolume = "kanta.settings.partySFXVolume"
    }

    @Published var stageVisualsEnabled: Bool {
        didSet {
            defaults.set(
                stageVisualsEnabled,
                forKey: Key.stageVisualsEnabled
            )
        }
    }

    @Published var selectedVisualPreset:
        KantaBuiltInVisualPreset
    {
        didSet {
            defaults.set(
                selectedVisualPreset.rawValue,
                forKey: Key.visualPreset
            )
        }
    }

    @Published var scoringEnabled: Bool {
        didSet {
            defaults.set(
                scoringEnabled,
                forKey: Key.scoringEnabled
            )
        }
    }

    @Published var scoringLatencyMilliseconds: Int {
        didSet {
            defaults.set(
                scoringLatencyMilliseconds,
                forKey: Key.scoringLatency
            )
        }
    }

    @Published var vocalEffects: VocalFXSettings {
        didSet {
            defaults.set(
                try? JSONEncoder().encode(vocalEffects.clamped),
                forKey: Key.vocalEffects
            )
        }
    }

    @Published var partySFXVolume: Float {
        didSet {
            defaults.set(partySFXVolume, forKey: Key.partySFXVolume)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(
            forKey: Key.stageVisualsEnabled
        ) == nil {
            stageVisualsEnabled = true
        } else {
            stageVisualsEnabled = defaults.bool(
                forKey: Key.stageVisualsEnabled
            )
        }

        if let raw = defaults.string(
            forKey: Key.visualPreset
        ),
        let preset = KantaBuiltInVisualPreset(rawValue: raw) {
            selectedVisualPreset = preset
        } else {
            selectedVisualPreset = .emberSunset
        }

        if defaults.object(
            forKey: Key.scoringEnabled
        ) == nil {
            scoringEnabled = false
        } else {
            scoringEnabled = defaults.bool(
                forKey: Key.scoringEnabled
            )
        }

        scoringLatencyMilliseconds = defaults.integer(
            forKey: Key.scoringLatency
        )
        let persisted = defaults.object(forKey: Key.partySFXVolume)
        let level = persisted == nil ? 0.35 : defaults.float(forKey: Key.partySFXVolume)
        partySFXVolume = level.isFinite ? min(max(level, 0), 0.65) : 0
        if let saved = defaults.data(forKey: Key.vocalEffects),
           let config = try? JSONDecoder().decode(
                VocalFXSettings.self, from: saved
           ) {
            var safe = config.clamped
            // A prior session may have explicitly enabled live monitoring.
            // Never resume an open microphone/output path on app launch.
            safe.monitorEnabled = false
            vocalEffects = safe
        } else {
            vocalEffects = VocalFXSettings()
        }
    }

    func snapshot() -> KantaSettingsSnapshot {
        KantaSettingsSnapshot(
            stageVisualsEnabled: stageVisualsEnabled,
            selectedVisualPresetRaw:
                selectedVisualPreset.rawValue,
            scoringEnabled: scoringEnabled,
            scoringLatencyMilliseconds:
                scoringLatencyMilliseconds,
            vocalEffects: vocalEffects
        )
    }

    func apply(_ snapshot: KantaSettingsSnapshot) {
        stageVisualsEnabled = snapshot.stageVisualsEnabled
        if let preset = KantaBuiltInVisualPreset(
            rawValue: snapshot.selectedVisualPresetRaw
        ) {
            selectedVisualPreset = preset
        }
        scoringEnabled = snapshot.scoringEnabled ?? false
        scoringLatencyMilliseconds =
            snapshot.scoringLatencyMilliseconds
        // Never automatically activate live mic output from a cloud restore.
        if let restored = snapshot.vocalEffects {
            var safe = restored.clamped
            safe.monitorEnabled = false
            vocalEffects = safe
        }
    }
}

struct KantaSettingsSnapshot: Codable, Equatable {
    let stageVisualsEnabled: Bool
    let selectedVisualPresetRaw: String
    let scoringEnabled: Bool?
    let scoringLatencyMilliseconds: Int
    let vocalEffects: VocalFXSettings?
}


