import SwiftUI

@MainActor
struct RootView: View {
    @ObservedObject var services: AppServices
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMenu = false
    @State private var route: Route?

    private enum Route: String, Identifiable {
        case library, remote, settings, legal, icloud, songbook
        var id: String { rawValue }
    }

    init(services: AppServices) {
        self.services = services
        let mode = ProcessInfo.processInfo.environment["GELO_SCREENSHOT_MODE"] ?? ""
        _route = State(initialValue: Route(rawValue: mode))
    }

    var body: some View {
        NavigationStack {
            HostView(services: services, onOpenNavigation: { showingMenu = true })
                .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(GeloVisualStyle.accent)
        .confirmationDialog("KANTA", isPresented: $showingMenu, titleVisibility: .visible) {
            Button("Song Library") { route = .library }
            Button("KANTA Songbook") { route = .songbook }
            Button("Settings") { route = .settings }
            Button("Companion Remote") { route = .remote }
            #if !KANTA_PERSONAL_SIGNING
            Button("iCloud Save") { route = .icloud }
            #endif
            Button("Legal & Privacy") { route = .legal }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $route) { selected in
            NavigationStack {
                destination(selected)
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { route = nil }
                    } }
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
        case .library: LibraryView(services: services)
        case .remote: RemoteView()
        case .settings: KantaSettingsView(services: services)
        case .legal: LegalDisclosureView()
        case .icloud: ICloudBackupView(services: services)
        case .songbook: KantaSongbookView(library: services.library)
        }
    }
}
