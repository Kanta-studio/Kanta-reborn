import GeloKaraokeCore
import LibraryStorage
import UIKit
import SwiftUI

/// Pages imported song metadata without loading audio payloads.
@MainActor
struct KantaSongbookView: View {
    let library: BookmarkedKaraokeLibrary?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var entries: [LibrarySong] = []
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var exportedCSV: URL?
    @State private var privateBook: KantaPrivateSongbook.Export?
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var totalCount = 0
    @State private var editingArtistFor: LibrarySong?
    @State private var artistInput = ""


    private let pageSize = 100

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(
                        "Imported catalog",
                        value: totalCount.formatted() + " titles"
                    )
                    Text(
                        "Codes are KANTA reference numbers based on the " +
                        "record's order in each imported index. They are not " +
                        "original song-provider codes. If the index is " +
                        "reordered, its codes may change. More than one " +
                        "imported index may use the same code."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Voice Search") {
                    KantaVoiceSearchAccessory(query: $query)
                }

                Section("Songs") {
                    if isLoading && entries.isEmpty {
                        ProgressView("Reading songbook…")
                    } else if entries.isEmpty {
                        ContentUnavailableView(
                            "No songs yet",
                            systemImage: "books.vertical",
                            description: Text(
                                "Import your title index in Song Library, " +
                                "then return here to browse and export it."
                            )
                        )
                    } else {
                        ForEach(entries) { song in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(song.code ?? "—")
                                    .font(.system(
                                        .subheadline, design: .monospaced
                                    ).weight(.bold))
                                    .foregroundStyle(GeloVisualStyle.accent)
                                    .frame(minWidth: 56, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title)
                                        .font(.subheadline)
                                    Text(
                                        song.artist?.isEmpty == false
                                            ? (song.artist ?? "")
                                            : "Artist not provided"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    if !song.isPlayable {
                                        Text("Catalog only")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button {
                                    editingArtistFor = song
                                    artistInput = song.artist ?? ""
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .accessibilityLabel(
                                    "Edit artist for " + song.title
                                )
                                .buttonStyle(.borderless)
                            }
                            .accessibilityElement(children: .contain)
                        }
                        if hasMore {
                            Button {
                                Task { await loadPage(reset: false) }
                            } label: {
                                Label(
                                    "Load more titles",
                                    systemImage: "arrow.down.circle"
                                )
                            }
                            .disabled(isLoading)
                        }
                    }
                }

                Section("Private website Songbook") {
                    Button {
                        Task { await preparePrivateBook() }
                    } label: {
                        Label(
                            "Create private website copy",
                            systemImage: "lock.doc"
                        )
                    }
                    .disabled(isExporting || library == nil || totalCount == 0)

                    if let privateBook {
                        Text("Your private access code:")
                            .font(.caption)
                        Text(groupCode(privateBook.accessCode))
                            .font(.system(.footnote, design: .monospaced).bold())
                            .textSelection(.enabled)
                        Button("Copy access code") {
                            UIPasteboard.general.string =
                                groupCode(privateBook.accessCode)
                        }
                        ShareLink(
                            item: privateBook.url,
                            preview: SharePreview("KANTA Private Songbook")
                        ) {
                            Label(
                                "Share encrypted .kanta-book file",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        Link(
                            "Open private Songbook website",
                            destination: URL(
                                string: "https://kanta-public.vercel.app/songbook"
                            )!
                        )
                    }

                    Text(
                        "Save/share this encrypted file and type its " +
                        "unique access code on the website. Both are " +
                        "required. This is NOT the six-digit LAN Remote " +
                        "PIN. KANTA receives no files or codes. Keep " +
                        "exports and codes private; they do not expire."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Export") {
                    Button {
                        Task { await exportCSV() }
                    } label: {
                        if isExporting {
                            ProgressView("Preparing songbook…")
                        } else {
                            Label(
                                "Prepare complete songbook CSV",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                    .disabled(isExporting || library == nil || totalCount == 0)

                    if let exportedCSV {
                        ShareLink(
                            item: exportedCSV,
                            preview: SharePreview("KANTA Songbook")
                        ) {
                            Label(
                                "Share / Save songbook",
                                systemImage: "doc.text"
                            )
                        }
                    }
                    Text(
                        "Exports song codes, titles, available or manually " +
                        "entered artist names and availability. No music, " +
                        "SoundFonts or source paths are copied."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .kantaListSurface()
            .navigationTitle("KANTA Songbook")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                prompt: "Search song name, artist or code"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let library {
                    totalCount = (await library.loadIfNeeded()).songCount
                    await loadPage(reset: true)
                }
            }
            .onChange(of: query) {
                searchTask?.cancel()
                exportedCSV = nil
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled else { return }
                    await loadPage(reset: true)
                }
            }
            .onDisappear { searchTask?.cancel() }
            .sheet(item: $editingArtistFor) { song in
                NavigationStack {
                    Form {
                        TextField(
                            "Artist (leave blank if unknown)",
                            text: $artistInput
                        )
                        .textInputAutocapitalization(.words)
                        Text(
                            "KANTA stores artist names locally, includes " +
                            "them in searches and Songbook exports, and " +
                            "does not alter your imported index."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .kantaListSurface()
            .navigationTitle("Edit Artist")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editingArtistFor = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let value = artistInput
                                editingArtistFor = nil
                                Task {
                                    guard let library else { return }
                                    do {
                                        try await library.setArtist(
                                            value, for: song.id
                                        )
                                        await loadPage(reset: true)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .alert(
                "Songbook",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func loadPage(reset: Bool) async {
        guard let library else { return }
        if isLoading && !reset { return }
        let submitted = query
        let start = reset ? 0 : entries.count
        isLoading = true
        let batch = await library.searchSongs(
            matching: submitted, limit: pageSize + 1, offset: start
        )
        guard query == submitted else {
            isLoading = false
            return
        }
        let page = Array(batch.prefix(pageSize))
        if reset { entries = page }
        else if entries.count == start { entries.append(contentsOf: page) }
        hasMore = batch.count > pageSize
        isLoading = false
    }

    private func groupCode(_ code: String) -> String {
        let symbols = Array(code)
        return stride(from: 0, to: symbols.count, by: 4)
            .map { String(symbols[$0..<min($0 + 4, symbols.count)]) }
            .joined(separator: "-")
    }

    private func preparePrivateBook() async {
        guard let library, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let csvURL = try await library.exportSongbookCSV()
            privateBook = try await Task.detached(
                priority: .userInitiated
            ) {
                try KantaPrivateSongbook.makeExport(csvURL: csvURL)
            }.value
        } catch {
            errorMessage = "Could not create encrypted Songbook: "
                + error.localizedDescription
        }
    }

    private func exportCSV() async {
        guard let library, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            exportedCSV = try await library.exportSongbookCSV()
        } catch {
            errorMessage = "Could not create the songbook: "
                + error.localizedDescription
        }
    }
}

