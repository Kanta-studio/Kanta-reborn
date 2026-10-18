import GeloKaraokeCore
import SwiftUI

/// Explicit opt-in online preview. Queue integration is intentionally separate.
@MainActor
struct KantaYouTubePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var link = ""
    @State private var selected: YouTubeVideoReference?
    @State private var showInvalidLink = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let selected {
                    YouTubeEmbeddedPlayerView(reference: selected)
                        .frame(minHeight: 220)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    Button("Stop online video") { self.selected = nil }
                        .buttonStyle(.bordered)
                } else {
                    Text("Online videos use YouTube/Google services, may share playback data and may show ads. Local karaoke works offline. YouTube has separate playback controls from local karaoke.")
                        .font(.footnote)
                    TextField("YouTube HTTPS video link", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("youtube.preview.link")
                    Button("Continue to YouTube") {
                        guard let reference = YouTubeVideoReference(url: link.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                            showInvalidLink = true
                            return
                        }
                        selected = reference
                    }
                    .buttonStyle(.borderedProminent)
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
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { selected = nil }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selected = nil
                        dismiss()
                    }
                }
            }
        }
    }
}
