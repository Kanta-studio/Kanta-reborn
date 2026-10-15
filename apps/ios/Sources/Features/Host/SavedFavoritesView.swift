import GeloKaraokeCore
import LibraryStorage
import SwiftUI

/// Displayed when the session finishes. The user explicitly chooses whether
/// to persist the history: leaving it unsaved stores no song metadata.
@MainActor
struct SaveSessionFavoritesView: View {
    @ObservedObject var model: HostViewModel
    @State private var collectionName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Favorites name", text: $collectionName)
                        .textInputAutocapitalization(.words)
                    if !model.canSaveFavorites {
                        Text(
                            "Favorites storage is unavailable. You can " +
                            "continue singing, but saving is disabled."
                        )
                        .foregroundStyle(.secondary)
                    }
                    Text(
                        "Save \(model.pendingSessionSongs.count) played song(s)"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Save your karaoke session?")
                } footer: {
                    Text(
                        "Only song titles, IDs and codes are saved on this " +
                        "device. Music files stay in your imported library."
                    )
                }

                Section("Songs played") {
                    ForEach(Array(model.pendingSessionSongs.enumerated()),
                            id: \.offset) { entry in
                        HStack {
                            Text("\(entry.offset + 1).")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.element.title)
                                if let artist = entry.element.artist, !artist.isEmpty {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .kantaListSurface()
            .navigationTitle("Save to Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Don't Save", role: .destructive) {
                        model.discardFinishedSession()
                    }
                    .disabled(model.isSavingFinishedSession)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await model.saveFinishedSession(named: collectionName)
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(
                        !model.canSaveFavorites ||
                        model.isSavingFinishedSession ||
                        collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
            .onAppear {
                if collectionName.isEmpty {
                    collectionName = model.suggestedFavoritesName
                }
            }
            .interactiveDismissDisabled()
        }
    }
}

/// Stored sets may be renamed, removed or appended to Up Next. Songs are
/// resolved by the current library before enqueue, never loaded from a
/// stale file path or from saved metadata.
@MainActor
struct SavedFavoritesView: View {
    @ObservedObject var model: HostViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: SavedKaraokeSet?
    @State private var renamedTitle = ""
    @State private var editingCollectionID: UUID?
    @State private var showingPlaylistEditor = false

    var body: some View {
        NavigationStack {
            List {
                if model.savedFavorites.isEmpty {
                    ContentUnavailableView(
                        "No Favorites yet",
                        systemImage: "heart.text.square",
                        description: Text(
                            "Save a singing session, or tap New Playlist to " +
                            "create a reusable list from your song library."
                        )
                    )
                } else {
                    ForEach(model.savedFavorites) { set in
                        Section {
                            ForEach(Array(set.songs.enumerated()), id: \.offset) { entry in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.element.title)
                                    if let artist = entry.element.artist, !artist.isEmpty {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Button {
                                Task { await model.loadFavoritesIntoQueue(set) }
                            } label: {
                                Label(
                                    "Load \(set.songs.count) songs to Up Next",
                                    systemImage: "text.badge.plus"
                                )
                            }
                            Button {
                                editingCollectionID = set.id
                                showingPlaylistEditor = true
                            } label: {
                                Label("Edit songs", systemImage: "square.and.pencil")
                            }
                        } header: {
                            HStack {
                                Text(set.name)
                                if set.kind == .playlist {
                                    Text("PLAYLIST")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    renamedTitle = set.name
                                    renaming = set
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .accessibilityLabel("Rename " + set.name)
                                Button(role: .destructive) {
                                    Task { await model.deleteFavorites(set.id) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete " + set.name)
                            }
                        } footer: {
                            Text(
                                "\(set.songs.count) played songs · " +
                                set.createdAt.formatted(date: .abbreviated, time: .omitted)
                            )
                        }
                    }
                }
            }
            .kantaListSurface()
            .navigationTitle("Saved Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        editingCollectionID = nil
                        showingPlaylistEditor = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPlaylistEditor) {
                KantaPlaylistEditorView(
                    model: model,
                    collectionID: editingCollectionID
                )
            }
            .task { await model.refreshSavedFavorites() }
            .alert(
                "Rename Favorites",
                isPresented: Binding(
                    get: { renaming != nil },
                    set: { if !$0 { renaming = nil } }
                )
            ) {
                TextField("Collection name", text: $renamedTitle)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Rename") {
                    guard let set = renaming else { return }
                    renaming = nil
                    Task {
                        await model.renameFavorites(set.id, to: renamedTitle)
                    }
                }
                .disabled(renamedTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty)
            } message: {
                Text("Choose a name for this saved karaoke session.")
            }
        }
    }
}

