import GeloKaraokeCore
import SwiftUI

enum KantaStageSheet: String, Identifiable {
    case search
    case queue

    var id: String { rawValue }
}

/// Shared content for the Host-owned embedded sheet and the fullscreen child sheet.
@MainActor
struct KantaStageSheetContent: View {
    let sheet: KantaStageSheet
    @ObservedObject var model: HostViewModel
    @Binding var singerName: String
    let microphoneBusy: Bool
    let onClose: () -> Void

    @ViewBuilder
    var body: some View {
        switch sheet {
        case .search:
            KantaStageSearchView(
                model: model,
                singerName: $singerName,
                microphoneBusy: microphoneBusy,
                onClose: onClose
            )
            .padding(12)
            .background(GeloVisualStyle.pageBackground)
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
        case .queue:
            NavigationStack {
                List {
                    if model.snapshot.queue.isEmpty {
                        Text("No reservations yet. Use Search to choose a song.")
                    }
                    ForEach(model.snapshot.queue) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.song.title)
                                if let singer = item.requestedBy {
                                    Text(singer).font(.caption)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await model.removeQueueItem(item.id) }
                            } label: {
                                Image(systemName: "trash").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Remove " + item.song.title)
                        }
                    }
                }
                .navigationTitle("Reservations")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onClose)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
