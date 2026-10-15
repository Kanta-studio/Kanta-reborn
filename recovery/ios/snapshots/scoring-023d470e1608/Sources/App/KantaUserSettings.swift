import Combine
import Foundation

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
            selectedVisualPreset = .bayanDawn
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
    }

    func snapshot() -> KantaSettingsSnapshot {
        KantaSettingsSnapshot(
            stageVisualsEnabled: stageVisualsEnabled,
            selectedVisualPresetRaw:
                selectedVisualPreset.rawValue,
            scoringEnabled: scoringEnabled,
            scoringLatencyMilliseconds:
                scoringLatencyMilliseconds
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
    }
}

struct KantaSettingsSnapshot: Codable, Equatable {
    let stageVisualsEnabled: Bool
    let selectedVisualPresetRaw: String
    let scoringEnabled: Bool?
    let scoringLatencyMilliseconds: Int
}


