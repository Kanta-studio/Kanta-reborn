import Foundation

enum AppRole: String, CaseIterable, Hashable, Identifiable {
    case host
    case remote
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .host: "Start Karaoke"
        case .remote: KantaTerminology.control
        case .library: "Song Library"
        }
    }

    var subtitle: String {
        switch self {
        case .host:
            "Sing, search, queue, and control the session on this device."
        case .remote:
            "Optionally use a second device as KANTA control on the local network."
        case .library:
            "Browse imported songs and compatible local libraries."
        }
    }

    var systemImage: String {
        switch self {
        case .host: "music.mic"
        case .remote: "iphone.gen3.radiowaves.left.and.right"
        case .library: "music.note.list"
        }
    }
}

