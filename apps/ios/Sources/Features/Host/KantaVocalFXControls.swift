import GeloKaraokeCore
import MicrophoneScoring
import SwiftUI

/// Effects apply ONLY to microphone audio passing through KANTA. The
/// microphone input tap for scoring remains upstream of this DSP chain.
@MainActor
struct KantaVocalFXControls: View {
    @ObservedObject var settings: KantaUserSettings
    @ObservedObject var monitor: MicrophonePitchMonitor

    private var effects: VocalFXSettings { settings.vocalEffects }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "Live microphone to sound output",
                isOn: Binding(
                    get: { effects.monitorEnabled },
                    set: { enabled in
                        var updated = effects
                        updated.monitorEnabled = enabled
                        settings.vocalEffects = updated
                    }
                )
            )
            .font(.subheadline.weight(.semibold))

            LabeledContent(
                "Monitor",
                value: monitor.isMonitorAudible
                    ? "Active · " + monitor.monitoringRoute.rawValue
                    : "Muted · " + routeDescription
            )
            .font(.caption)

            Text(
                "Requires a wired headset or supported USB audio interface. " +
                "Built-in speakers, Bluetooth and AirPlay are muted to avoid " +
                "feedback and delay. A microphone connected directly to " +
                "an external mixer is not processed by KANTA."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Picker(
                "Vocal environment",
                selection: Binding(
                    get: { effects.preset },
                    set: { selected in
                        var updated = effects
                        updated.preset = selected
                        updated.reverbMix = selected.defaultReverbMix
                        updated.echoMix = selected.defaultEchoMix
                        settings.vocalEffects = updated
                    }
                )
            ) {
                ForEach(VocalFXPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Picker(
                "Vocal style",
                selection: Binding(
                    get: { effects.polishPreset },
                    set: { selected in
                        var updated = effects
                        updated.selectPolishPreset(selected)
                        settings.vocalEffects = updated.clamped
                    }
                )
            ) {
                ForEach(VocalPolishPreset.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)

            Text("Vocal polish · processed mic only")
                .font(.subheadline.weight(.semibold))

            effectSlider(
                "Compression", value: effects.compression * 100,
                range: 0...100, unit: "%",
                set: { updateValue(\.compression, to: $0 / 100) }
            )
            effectSlider(
                "Noise Gate / Expander", value: effects.noiseGate * 100,
                range: 0...100, unit: "%",
                set: { updateValue(\.noiseGate, to: $0 / 100) }
            )
            effectSlider(
                "De-Esser", value: effects.deEsser * 100,
                range: 0...100, unit: "%",
                set: { updateValue(\.deEsser, to: $0 / 100) }
            )
            effectSlider(
                "Vocal Doubler", value: effects.doubler,
                range: 0...40, unit: "%",
                set: { updateValue(\.doubler, to: $0) }
            )
            effectSlider(
                "Echo Time", value: effects.delayMilliseconds,
                range: 70...700, unit: " ms",
                set: { updateValue(\.delayMilliseconds, to: $0) }
            )
            Label("Output peak limiter is always active.", systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)

            effectSlider(
                "Reverb", value: effects.reverbMix,
                range: 0...70, unit: "%",
                set: { updateValue(\.reverbMix, to: $0) }
            )
            effectSlider(
                "Echo", value: effects.echoMix,
                range: 0...50, unit: "%",
                set: { updateValue(\.echoMix, to: $0) }
            )
            effectSlider(
                "Bass", value: effects.bassGain,
                range: -12...12, unit: " dB",
                set: { updateValue(\.bassGain, to: $0) }
            )
            effectSlider(
                "Treble", value: effects.trebleGain,
                range: -12...12, unit: " dB",
                set: { updateValue(\.trebleGain, to: $0) }
            )
            effectSlider(
                "Mic Level", value: effects.microphoneLevel * 100,
                range: 0...85, unit: "%",
                set: { updateValue(\.microphoneLevel, to: $0 / 100) }
            )

            // Auto-Tune-style correction is optional and separate from dry scoring.
            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Pitch Correction (experimental)",
                    isOn: Binding(
                        get: { activeCorrection.enabled },
                        set: { value in
                            var correction = activeCorrection
                            correction.enabled = value
                            setCorrection(correction)
                        }
                    )
                )
                .font(.subheadline.weight(.semibold))

                if activeCorrection.enabled {
                    Picker(
                        "Tuning Engine",
                        selection: Binding(
                            get: { activeCorrection.selectedBackend },
                            set: { selected in
                                var correction = activeCorrection
                                correction.backend = selected
                                setCorrection(correction)
                            }
                        )
                    ) {
                        ForEach(VocalPitchBackend.allCases) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                    .accessibilityHint(
                        "Soundpipe uses an MIT licensed vocal pitch correction " +
                        "audio effect. Native uses Apple's original pitch shifting."
                    )
                    Text(
                        activeCorrection.selectedBackend == .soundpipe
                        ? "Soundpipe PitchCorrect · open-source DSP, preserves your dry scoring input."
                        : "Apple native fallback · KANTA's original note-snap pipeline."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker(
                        "Key",
                        selection: Binding(
                            get: { activeCorrection.root },
                            set: { root in
                                var correction = activeCorrection
                                correction.root = root
                                setCorrection(correction)
                            }
                        )
                    ) {
                        ForEach(0..<12, id: \.self) { index in
                            Text(VocalPitchCorrection.pitchClassNames[index])
                                .tag(index)
                        }
                    }
                    Picker(
                        "Scale",
                        selection: Binding(
                            get: { activeCorrection.scale },
                            set: { scale in
                                var correction = activeCorrection
                                correction.scale = scale
                                setCorrection(correction)
                            }
                        )
                    ) {
                        ForEach(VocalPitchScale.allCases) { scale in
                            Text(scale.displayName).tag(scale)
                        }
                    }
                    effectSlider(
                        "Correction Amount",
                        value: activeCorrection.amount * 100,
                        range: 0...100, unit: "%",
                        set: { value in
                            var correction = activeCorrection
                            correction.amount = value / 100
                            setCorrection(correction)
                        }
                    )
                    effectSlider(
                        "Response Speed",
                        value: activeCorrection.speed * 100,
                        range: 0...100, unit: "%",
                        set: { value in
                            var correction = activeCorrection
                            correction.speed = value / 100
                            setCorrection(correction)
                        }
                    )
                }

                Text(
                    "Experimental monophonic vocal tuning for a mic routed through KANTA. " +
                    "SoundpipeAudioKit PitchCorrect is MIT licensed; the Apple " +
                    "native fallback is also available. Neither is the commercial " +
                    "Auto-Tune plug-in. Fast tuning may sound synthetic. Connect a " +
                    "supported wired/USB audio output; scoring stays dry."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("Phase 3 · Coming later", systemImage: "lock")
                    .font(.subheadline.weight(.semibold))
                Text("Vocal harmonizer and tempo-aware harmonies remain planned. Experimental pitch correction above requires real-device validation before release.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Vocal harmonies · Coming later") {}
                    .disabled(true)
                    .buttonStyle(.bordered)
            }
            .padding(.top, 8)

            HStack {
                Button("Reset to Dry") {
                    var updated = VocalFXSettings()
                    updated.monitorEnabled = effects.monitorEnabled
                    settings.vocalEffects = updated
                }
                .buttonStyle(.bordered)
                Spacer()
                if effects.monitorEnabled && !monitor.isMonitorAudible {
                    Button("Retry Mic") {
                        Task { await monitor.start() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var activeCorrection: VocalPitchCorrection {
        effects.pitchCorrection ?? VocalPitchCorrection()
    }

    private func setCorrection(_ value: VocalPitchCorrection) {
        var updated = effects
        updated.pitchCorrection = value.clamped
        settings.vocalEffects = updated.clamped
    }

    private var routeDescription: String {
        if !effects.monitorEnabled { return "Off" }
        switch monitor.status {
        case .denied: return "Microphone access denied"
        case .failed(let reason): return reason
        case .requestingPermission: return "Requesting microphone access"
        case .idle: return "Waiting for mic"
        case .running: return "Connect wired/USB output"
        }
    }

    private func effectSlider(
        _ name: String, value: Float,
        range: ClosedRange<Double>, unit: String,
        set: @escaping (Float) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.subheadline)
                Spacer()
                Text(String(format: "%.0f", value) + unit)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { set(Float($0)) }
                ),
                in: range
            )
            .accessibilityLabel(name)
        }
    }

    private func updateValue(
        _ keyPath: WritableKeyPath<VocalFXSettings, Float>, to value: Float
    ) {
        var updated = effects
        updated[keyPath: keyPath] = value
        updated.polishPreset = .custom
        settings.vocalEffects = updated.clamped
    }
}

