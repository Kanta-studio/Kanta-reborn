import SwiftUI

@MainActor
struct KantaSettingsView: View {
    @ObservedObject private var settings: KantaUserSettings
    @ObservedObject private var cloudSync: ICloudSyncCoordinator
    @Environment(\.dismiss) private var dismiss

    init(services: AppServices) {
        settings = services.settings
        cloudSync = services.cloudSync
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Scoring") {
                    Toggle(
                        "Enable scoring",
                        isOn: $settings.scoringEnabled
                    )

                    Text(
                        "Experimental room scoring uses this device's built-in microphone. " +
                        "Check the room in Host while playback is paused, then sing near the device. " +
                        "An estimated score is shown after a completed song only when enough " +
                        "clear singing matches a supported melody track. Loud backing music " +
                        "and echo can affect results; this is not voice isolation. " +
                        "Audio is not recorded or uploaded."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if settings.scoringEnabled {
                        Stepper(
                            value:
                                $settings.scoringLatencyMilliseconds,
                            in: -500...1_500,
                            step: 10
                        ) {
                            LabeledContent(
                                "Latency compensation",
                                value:
                                    "\(settings.scoringLatencyMilliseconds) ms"
                            )
                        }
                    }
                }

                Section("Stage") {
                    Toggle(
                        "Stage visuals",
                        isOn: $settings.stageVisualsEnabled
                    )

                    if settings.stageVisualsEnabled {
                        Picker(
                            "Default visual",
                            selection:
                                $settings.selectedVisualPreset
                        ) {
                            ForEach(
                                KantaBuiltInVisualPreset.allCases
                            ) { preset in
                                Text(preset.displayName)
                                    .tag(preset)
                            }
                        }
                    }

                    Text(
                        "Built-in visuals are KANTA-owned procedural " +
                        "presets rendered at device resolution."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("iCloud") {
                    LabeledContent(
                        "Status",
                        value: cloudSync.accountState.title
                    )

                    Text(
                        "Use iCloud Save from the main menu to choose " +
                        "exactly which categories are backed up."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .tint(GeloVisualStyle.accent)
    }
}

