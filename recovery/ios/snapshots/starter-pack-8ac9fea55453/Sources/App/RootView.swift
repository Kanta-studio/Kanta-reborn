import SwiftUI

@MainActor
struct RootView: View {
    @ObservedObject var services: AppServices
    @StateObject private var favoritesModel: HostViewModel
    @State private var showingFavorites = false
    @State private var selectedRole: AppRole?
    @State private var showingLegal: Bool
    @State private var showingICloud: Bool
    @State private var showingSettings: Bool
    @State private var showingSongbook = false

    init(services: AppServices) {
        self.services = services
        _favoritesModel = StateObject(wrappedValue: HostViewModel(
            controller: services.controller,
            library: services.library,
            savedSets: services.savedSets
        ))

        let screenshotMode =
            ProcessInfo.processInfo.environment[
                "GELO_SCREENSHOT_MODE"
            ]

        _selectedRole = State(
            initialValue:
                screenshotMode == "library"
                ? .library
                : screenshotMode == "host"
                    ? .host
                    : screenshotMode == "remote"
                        ? .remote
                        : nil
        )
        _showingLegal = State(
            initialValue: screenshotMode == "legal"
        )
        _showingICloud = State(
            initialValue: screenshotMode == "icloud"
        )
        _showingSettings = State(
            initialValue: screenshotMode == "settings"
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .tint(GeloVisualStyle.accent)
        .sheet(isPresented: $showingLegal) {
            LegalDisclosureView()
        }
        .sheet(isPresented: $showingICloud) {
            ICloudBackupView(services: services)
        }
        .sheet(isPresented: $showingSettings) {
            KantaSettingsView(services: services)
        }
        .sheet(isPresented: $showingFavorites) {
            SavedFavoritesView(model: favoritesModel)
        }
        .sheet(isPresented: $showingSongbook) {
            KantaSongbookView(library: services.library)
        }
        .task {
            await services.prepare()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedRole) {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    KantaBrandLockup(compact: true)

                    Text(
                        "Offline-first karaoke for iPhone and iPad."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Karaoke") {
                ForEach(AppRole.allCases) { role in
                    NavigationLink(value: role) {
                        Label {
                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(role.title)
                                    .font(.headline)
                                Text(role.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        } icon: {
                            Image(systemName: role.systemImage)
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityHint(role.subtitle)
                }
            }

            Section("Songbook") {
                Button {
                    showingSongbook = true
                } label: {
                    Label(
                        "KANTA Songbook",
                        systemImage: "books.vertical"
                    )
                }
                .accessibilityHint(
                    "Browse imported song codes and export your songbook."
                )
            }

            if let startupMessage = services.startupMessage {
                Section("Library access") {
                    Label {
                        Text(startupMessage)
                            .font(.footnote)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Section("Your Favorites") {
                Button {
                    showingFavorites = true
                } label: {
                    Label("Saved Favorites", systemImage: "heart.text.square")
                }
                .accessibilityHint(
                    "Load, rename or delete previously saved karaoke sessions."
                )
            }

            Section("About") {
                Button {
                    showingSettings = true
                } label: {
                    Label(
                        "Settings",
                        systemImage: "gearshape"
                    )
                }

                Button {
                    showingICloud = true
                } label: {
                    Label(
                        "iCloud Save",
                        systemImage: "icloud.and.arrow.up"
                    )
                }

                Button {
                    showingLegal = true
                } label: {
                    Label(
                        "Legal & Privacy",
                        systemImage: "checkmark.shield"
                    )
                }

                Label(
                    "Core playback works offline",
                    systemImage: "wifi.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .kantaListSurface()
        .navigationTitle("KANTA")
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedRole {
            destination(for: selectedRole)
        } else {
            ZStack {
                GeloVisualStyle.pageGradient
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    KantaBrandMark(size: 82)

                    Text("Ready when you are")
                        .font(.largeTitle.bold())

                    Text(
                        "Start singing, open Controls on this device, " +
                        "or prepare your local song library. A second-device " +
                        "Companion Remote is optional."
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                    HStack(spacing: 10) {
                        GeloStatusPill(
                            title: "Offline-first",
                            systemImage: "wifi.slash"
                        )
                        GeloStatusPill(
                            title: "Local media",
                            systemImage: "externaldrive"
                        )
                    }
                }
                .padding(32)
            }
            .navigationTitle("KANTA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLegal = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Legal and privacy")
                }
            }
        }
    }

    @ViewBuilder
    private func destination(
        for role: AppRole
    ) -> some View {
        switch role {
        case .host:
            HostView(services: services)
        case .remote:
            RemoteView()
        case .library:
            LibraryView(services: services)
        }
    }
}

