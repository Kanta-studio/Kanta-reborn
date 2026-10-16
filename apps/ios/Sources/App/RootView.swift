import SwiftUI

@MainActor
struct RootView: View {
    @ObservedObject var services: AppServices
    @Environment(\.scenePhase) private var scenePhase
    @State private var route: Route?

    private enum Route: String, Identifiable {
        case menu, library, remote, settings, legal, icloud, songbook
        var id: String { rawValue }
    }

    init(services: AppServices) {
        self.services = services
        let mode = ProcessInfo.processInfo.environment["GELO_SCREENSHOT_MODE"] ?? ""
        _route = State(initialValue: Route(rawValue: mode))
    }

    var body: some View {
        NavigationStack {
            HostView(services: services, onOpenNavigation: { route = .menu })
                .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(GeloVisualStyle.accent)
        // Navigation stays presented while the playing song updates the host view.
        .sheet(isPresented: Binding(
            get: { route != nil },
            set: { if !$0 { route = nil } }
        )) {
            NavigationStack {
                destination(route ?? .menu)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { route = nil }
                        }
                    }
            }
        }
        .task {
            services.diagnostics.beginSession()
            await services.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: services.diagnostics.setForeground(true)
            case .background: services.diagnostics.setForeground(false)
            default: break
            }
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .menu:
            List {
                Section("KANTA") {
                    Button("Song Library") { self.route = .library }
                    Button("KANTA Songbook") { self.route = .songbook }
                    Button("Settings") { self.route = .settings }
                    Button("Companion Remote") { self.route = .remote }
                    #if !KANTA_PERSONAL_SIGNING
                    Button("iCloud Save") { self.route = .icloud }
                    #endif
                    Button("Legal & Privacy") { self.route = .legal }
                }
            }
            .navigationTitle("More")
        case .library: LibraryView(services: services)
        case .remote: RemoteView()
        case .settings: KantaSettingsView(services: services)
        case .legal: LegalDisclosureView()
        case .icloud: ICloudBackupView(services: services)
        case .songbook: KantaSongbookView(library: services.library)
        }
    }
}
