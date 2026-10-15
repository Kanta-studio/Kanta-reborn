import GeloKaraokeCore
import LibraryStorage
import SwiftUI

/// Edits stored song references in the SAME Favorites store used for
/// post-session history. Playback continues to resolve each item through
/// the current authorized library before placing it in Up Next.
@MainActor
struct KantaPlaylistEditorView: View {
    @ObservedObject var model: HostViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var collectionID: UUID?
    @State private var name = ""
    @State private var query = ""
    @State private var results: [LibrarySong] = []
    @State private var page = 0
    @State private var isSearching = false

    init(model: HostViewModel, collectionID: UUID? = nil) {
        self.model = model
        _collectionID = State(initialValue: collectionID)
    }

    private var collection: SavedKaraokeSet? {
        model.savedFavorites.first(where: { $0.id == collectionID })
    }

    var body: some View {
        NavigationStack {
            List {
                if let collection {
                    Section("Songs in " + collection.name) {
                        if collection.songs.isEmpty {
                            Text("Empty playlist. Add a song below.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(collection.songs.enumerated()),
                                id: \.offset) { pair in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pair.element.title)
                                    if let artist = pair.element.artist {
                                        Text(artist).font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    Task {
                                        await model.reorderPlaylistSong(
                                            from: pair.offset,
                                            to: pair.offset - 1,
                                            collectionID: collection.id
                                        )
                                    }
                                } label: { Image(systemName: "arrow.up") }
                                .disabled(pair.offset == 0)
                                .accessibilityLabel("Move song up")
                                Button {
                                    Task {
                                        await model.reorderPlaylistSong(
                                            from: pair.offset,
                                            to: pair.offset + 1,
                                            collectionID: collection.id
                                        )
                                    }
                                } label: { Image(systemName: "arrow.down") }
                                .disabled(pair.offset == collection.songs.count - 1)
                                .accessibilityLabel("Move song down")
                                Button(role: .destructive) {
                                    Task {
                                        await model.removePlaylistSong(
                                            at: pair.offset,
                                            collectionID: collection.id
                                        )
                                    }
                                } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Remove song")
                            }
                            .buttonStyle(.borderless)
                        }
                        Button {
                            Task { await model.loadFavoritesIntoQueue(collection) }
                        } label: {
                            Label("Load playlist into Up Next", systemImage: "text.badge.plus")
                        }
                    }
                } else {
                    Section("Create Playlist") {
                        TextField("Playlist name", text: $name)
                            .textInputAutocapitalization(.words)
                        Text(
                            "Pick your first playable song below. " +
                            "Additional songs can be added later."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Add songs") {
                    HStack {
                        TextField("Search by title, artist or code", text: $query)
                            .submitLabel(.search)
                            .onSubmit { Task { await search(reset: true) } }
                        Button("Search") {
                            Task { await search(reset: true) }
                        }
                    }
                    if isSearching { ProgressView() }
                    ForEach(results) { song in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.title)
                                if let artist = song.artist {
                                    Text(artist).font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !song.isPlayable {
                                    Text("Catalog only")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                Task { await add(song) }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(!song.isPlayable ||
                                (collectionID == nil &&
                                 name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                            .accessibilityLabel("Add " + song.title)
                        }
                    }
                    HStack {
                        Button("Previous") {
                            Task { await movePage(-1) }
                        }
                        .disabled(page == 0 || isSearching)
                        Spacer()
                        Text("Page \(page + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Next") {
                            Task { await movePage(1) }
                        }
                        .disabled(results.count < 50 || isSearching)
                    }
                }
            }
            .kantaListSurface()
            .navigationTitle(collection == nil ? "New Playlist" : "Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await model.refreshSavedFavorites()
                await search(reset: true)
            }
        }
    }

    private func movePage(_ delta: Int) async {
        page = max(0, page + delta)
        await search(reset: false)
    }

    private func search(reset: Bool) async {
        if reset { page = 0 }
        isSearching = true
        let currentPage = page
        let currentQuery = query
        let found = await model.browseSongsForPlaylist(
            query: currentQuery,
            offset: currentPage * 50
        )
        guard currentPage == page, currentQuery == query else { return }
        results = found
        isSearching = false
    }

    private func add(_ song: LibrarySong) async {
        guard song.isPlayable else { return }
        if let collectionID {
            await model.appendToPlaylist(song: song, collectionID: collectionID)
        } else if let createdID = await model.createPlaylist(
            name: name, firstSong: song
        ) {
            collectionID = createdID
        }
    }
}

