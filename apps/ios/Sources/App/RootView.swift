import SwiftUI

// Serializes top-level presentation requests across stage, host and navigation.
@MainActor
final class KantaPresentationGate: ObservableObject {
    enum Owner: Equatable { case navigation, host, stage, fullscreen }
    @Published private(set) var owner: Owner?
    @Published private(set) var dismissing = false

    func acquire(_ requested: Owner) -> Bool {
        guard owner == nil && !dismissing else { return false }
        owner = requested
        return true
    }

    func beginDismissal(_ requested: Owner) {
        guard owner == requested else { return }
        dismissing = true
    }

    func completeDismissal(_ requested: Owner) {
        guard owner == requested else { return }
        owner = nil
        dismissing = false
    }
}

@MainActor
struct RootView: View {
    @ObservedObject var services: AppServices
    @StateObject private var presentationGate = KantaPresentationGate()
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheetRoute: Route = .menu
    @State private var activeNavigation: NavigationSheet? = nil
    @State private var navigationDismissing = false

    private enum NavigationSheet: String, Identifiable {
        case navigation
        var id: String { rawValue }
    }

    private enum Route: String, Identifiable {
        case menu, library, remote, settings, legal, icloud, songbook
        var id: String { rawValue }
    }

    init(services: AppServices) {
        self.services = services
        let mode = ProcessInfo.processInfo.environment["GELO_SCREENSHOT_MODE"] ?? ""
        let initialRoute = Route(rawValue: mode)
        _sheetRoute = State(initialValue: initialRoute ?? .menu)
        _activeNavigation = State(initialValue: initialRoute == nil ? nil : .navigation)
    }

    var body: some View {
        NavigationStack {
            HostView(services: services, presentationGate: presentationGate, navigationSheetPresented: activeNavigation != nil, onOpenNavigation: {
                guard activeNavigation == nil && !navigationDismissing else { return }
                guard presentationGate.acquire(.navigation) else { return }
                sheetRoute = .menu
                activeNavigation = .navigation
            })
                .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(GeloVisualStyle.accent)
        // One optional sheet identity owns presentation and dismissal.
        .sheet(item: $activeNavigation, onDismiss: {
            sheetRoute = .menu
            navigationDismissing = false
            presentationGate.completeDismissal(.navigation)
        }) {
            _ in
            NavigationStack {
                destination(sheetRoute)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                guard !navigationDismissing else { return }
                                navigationDismissing = true
                                presentationGate.beginDismissal(.navigation)
                                activeNavigation = nil
                            }
                            .accessibilityIdentifier("navigation.done")
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
