import SwiftUI

@MainActor
struct RootView: View {
    @ObservedObject var services: AppServices
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheetRoute: Route = .menu
    @State private var isSheetPresented = false
    @State private var navigationDismissing = false

    private enum Route: String, Identifiable {
        case menu, library, remote, settings, legal, icloud, songbook
        var id: String { rawValue }
    }

    init(services: AppServices) {
        self.services = services
        let mode = ProcessInfo.processInfo.environment["GELO_SCREENSHOT_MODE"] ?? ""
        let initialRoute = Route(rawValue: mode)
        _sheetRoute = State(initialValue: initialRoute ?? .menu)
        _isSheetPresented = State(initialValue: initialRoute != nil)
    }

    var body: some View {
        NavigationStack {
            HostView(services: services, navigationSheetPresented: isSheetPresented || navigationDismissing, onOpenNavigation: {
                sheetRoute = .menu
                isSheetPresented = true
            })
                .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(GeloVisualStyle.accent)
        // Navigation stays presented while the playing song updates the host view.
        .sheet(isPresented: $isSheetPresented, onDismiss: {
            sheetRoute = .menu
            navigationDismissing = false
        }) {
            NavigationStack {
                destination(sheetRoute)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                navigationDismissing = true
                                isSheetPresented = false
                            }
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
                    Button("Song Library") { sheetRoute = .library }
                    Button("KANTA Songbook") { sheetRoute = .songbook }
                    Button("Settings") { sheetRoute = .settings }
                    Button("Companion Remote") { sheetRoute = .remote }
                    #if !KANTA_PERSONAL_SIGNING
                    Button("iCloud Save") { sheetRoute = .icloud }
                    #endif
                    Button("Legal & Privacy") { sheetRoute = .legal }
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
