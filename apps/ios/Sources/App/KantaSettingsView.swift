import MicrophoneScoring
import SwiftUI

@MainActor
struct KantaSettingsView: View {
    @ObservedObject private var settings: KantaUserSettings
    @ObservedObject private var cloudSync: ICloudSyncCoordinator
    @ObservedObject private var diagnostics: KantaSupportDiagnostics
    private let microphone: MicrophonePitchMonitor
    @Environment(\.dismiss) private var dismiss

    init(services: AppServices) {
        settings = services.settings
        cloudSync = services.cloudSync
        diagnostics = services.diagnostics
        microphone = services.microphonePitchMonitor
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Filipino & English Voice Search") {
                    KantaFilipinoPackControls()
                    Text(
                        "The optional downloaded Filipino/Taglish model works " +
                        "offline. English (PH) search uses Apple's speech " +
                        "recognition and may require online processing. " +
                        "You can always type a title or artist."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Scoring") {
                    Toggle(
                        "Enable scoring",
                        isOn: $settings.scoringEnabled
                    )

                    Text(
                        "When enabled, KANTA uses the microphone locally " +
                        "to compare your pitch with supported melody tracks. " +
                        "A final score is shown after each completed song. " +
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

                Section("Soundcard · Live Vocal FX") {
                    Label(
                        "Hall, Room, Studio, Plate, Echo and tone controls",
                        systemImage: "waveform.path"
                    )
                    Text(
                        "Open Start Karaoke → Soundcard · Vocal FX to adjust " +
                        "your live microphone effects. Monitoring is off " +
                        "after every app launch and requires a wired headset " +
                        "or compatible USB audio output. Bluetooth, AirPlay " +
                        "and the built-in speaker are blocked."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Support & Diagnostic Reports") {
                    Toggle(
                        "Keep local diagnostic events",
                        isOn: Binding(
                            get: { diagnostics.enabled },
                            set: { diagnostics.setEnabled($0) }
                        )
                    )
                    Text(
                        "Optional, off by default. Keeps up to 200 technical " +
                        "events from the last 7 days on this device. Records " +
                        "microphone status, safe audio routes, DSP engine " +
                        "selection, and app session markers—not audio, song " +
                        "names, file paths, passwords, PINs or network IDs."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if diagnostics.enabled {
                        LabeledContent(
                            "Stored events",
                            value: String(diagnostics.count)
                        )
                        Button {
                            diagnostics.prepareSupportReport(
                                microphone: microphone,
                                settings: settings.vocalEffects
                            )
                        } label: {
                            Label(
                                "Prepare support report",
                                systemImage: "doc.text.magnifyingglass"
                            )
                        }
                        if let export = diagnostics.shareURL {
                            ShareLink(item: export) {
                                Label(
                                    "Review / Share report",
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            Text(
                                "The report is only shared if you choose " +
                                "a destination. Please review it before " +
                                "sending; receiving services may keep a copy."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Button(role: .destructive) {
                            diagnostics.clear()
                        } label: {
                            Label(
                                "Erase local diagnostic history",
                                systemImage: "trash"
                            )
                        }
                    }
                    if let message = diagnostics.statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(
                        "An interrupted foreground session is not proof " +
                        "of a crash. A full iOS crash report may need to " +
                        "be shared separately from Settings → Privacy & " +
                        "Security → Analytics & Improvements → Analytics Data."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Link(
                        "KANTA support and setup guide",
                        destination: URL(string:
                            "https://kanta-public.vercel.app/guide"
                        )!
                    )
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

                #if KANTA_PERSONAL_SIGNING
                Section("iCloud (personal test build)") {
                    Text(
                        "iCloud Save is unavailable in this free-account " +
                        "AltStore test build. All normal local karaoke, " +
                        "Soundcard and support-report features remain available."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                #else
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
                #endif
            }
            .kantaListSurface()
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

