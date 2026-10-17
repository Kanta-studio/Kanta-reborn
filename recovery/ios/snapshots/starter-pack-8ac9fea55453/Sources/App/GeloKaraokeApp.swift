import SwiftUI

@main
@MainActor
struct GeloKaraokeApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}
