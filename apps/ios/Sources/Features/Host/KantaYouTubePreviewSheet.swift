import GeloKaraokeCore
import SwiftUI

/// Explicit opt-in online preview. Queue integration is intentionally separate.
@MainActor
struct KantaYouTubePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var link = ""
    @StateObject private var playerOwner = YouTubeEmbeddedPlayerOwner()
    @State private var lifecycle = YouTubePreviewLifecycle()
    @State private var playerError: String?
    @State private var showInvalidLink = false
    let localPlaybackActive: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let selected = lifecycle.active {
                    YouTubeEmbeddedPlayerView(session: selected, owner: playerOwner) { id in
                        if lifecycle.close(id) {
                            playerError = "Online video could not load. Check your connection and try again."
                        }
                    }
                        .id(selected.id)
                        .frame(minHeight: 220)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    Button("Stop online video") {
                        playerOwner.retire()
                        lifecycle.close()
                    }
                        .buttonStyle(.bordered)
                } else {
                    Text("Online videos use YouTube/Google services, may share playback data and may show ads. Local karaoke works offline. YouTube has separate playback controls from local karaoke.")
                        .font(.footnote)
                    if let playerError {
                        Text(playerError).font(.footnote).accessibilityIdentifier("youtube.preview.error")
                    }
                    TextField("YouTube HTTPS video link", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("youtube.preview.link")
                    if localPlaybackActive {
                        Text("Pause local karaoke before opening an online video.")
                            .font(.footnote)
                            .accessibilityIdentifier("youtube.preview.localPlaybackNotice")
                    }
                    Button("Continue to YouTube") {
                        guard !localPlaybackActive else { return }
                        guard let reference = YouTubeVideoReference(url: link.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                            showInvalidLink = true
                            return
                        }
                        guard scenePhase == .active else { return }
                        playerError = nil
                        lifecycle.open(reference)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localPlaybackActive)
                    .alert("Invalid YouTube link", isPresented: $showInvalidLink) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("Enter a valid HTTPS YouTube video URL.")
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Online video")
            .onChange(of: localPlaybackActive) { _, active in
                if active {
                    playerOwner.retire()
                    lifecycle.close()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    playerOwner.retire()
                    lifecycle.close()
                }
            }
            .onDisappear {
                playerOwner.retire()
                lifecycle.close()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        playerOwner.retire()
                        lifecycle.close()
                        dismiss()
                    }
                }
            }
        }
    }
}
