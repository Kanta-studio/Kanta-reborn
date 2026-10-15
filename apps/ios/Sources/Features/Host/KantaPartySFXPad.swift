import AVFoundationPlayback
import GeloKaraokeCore
import SwiftUI
import UniformTypeIdentifiers

/// Host-only one-shot soundboard. Remote sends bounded SFX commands to this
/// same Host engine; clips stay private and are never transferred over LAN.
@MainActor
struct KantaPartySFXPad: View {
    @ObservedObject var model: HostViewModel
    @ObservedObject var settings: KantaUserSettings
    let engine: KantaPartySFXEngine

    @State private var importingFor: PartySFX?
    @State private var importerOpen = false
    @State private var customSounds = Set<PartySFX>()
    @State private var feedback: String?

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 9)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Party Soundboard", systemImage: "speaker.wave.2")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await model.stopPartySFX() }
                } label: {
                    Label("Stop SFX", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Text("Tap for an original KANTA effect. Long-press to replace a pad with a short audio clip you own.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(PartySFX.allCases) { sound in
                    Button {
                        Task { await model.triggerPartySFX(sound) }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: sound.symbol)
                                .font(.title2)
                            Text(sound.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            if customSounds.contains(sound) {
                                Text("CUSTOM")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 75)
                    }
                    .buttonStyle(.bordered)
                    .contextMenu {
                        Button {
                            importingFor = sound
                            importerOpen = true
                        } label: {
                            Label("Import clip for " + sound.title, systemImage: "square.and.arrow.down")
                        }
                        if customSounds.contains(sound) {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await engine.resetClip(for: sound)
                                        await refreshCustomBadges()
                                    } catch {
                                        feedback = error.localizedDescription
                                    }
                                }
                            } label: {
                                Label("Restore original", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                    .accessibilityHint("Long-press to import your own short effect clip")
                }
            }

            HStack {
                Text("SFX volume")
                Spacer()
                Text("\(Int(settings.partySFXVolume * 100))%")
                    .monospacedDigit()
            }
            .font(.caption)
            Slider(
                value: Binding(
                    get: { Double(settings.partySFXVolume) },
                    set: { settings.partySFXVolume = Float($0) }
                ),
                in: 0...0.65
            )
            .accessibilityLabel("Party sound effects volume")

            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("The pads are separate from microphone monitoring and karaoke playback. Imported audio stays locally in the app. Four overlapping SFX voices maximum.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fileImporter(
            isPresented: $importerOpen,
            allowedContentTypes: [.audio]
        ) { result in
            guard let slot = importingFor else { return }
            importingFor = nil
            switch result {
            case let .success(url):
                Task {
                    do {
                        try await engine.importClip(from: url, for: slot)
                        await refreshCustomBadges()
                        feedback = "Custom " + slot.title + " clip saved."
                    } catch {
                        feedback = error.localizedDescription
                    }
                }
            case let .failure(error):
                feedback = error.localizedDescription
            }
        }
        .task {
            await model.setPartySFXVolume(settings.partySFXVolume)
            await refreshCustomBadges()
        }
        .onChange(of: settings.partySFXVolume) {
            Task { await model.setPartySFXVolume(settings.partySFXVolume) }
        }
    }

    private func refreshCustomBadges() async {
        var found = Set<PartySFX>()
        for sound in PartySFX.allCases {
            if await engine.hasCustomSound(sound) { found.insert(sound) }
        }
        customSounds = found
    }
}

