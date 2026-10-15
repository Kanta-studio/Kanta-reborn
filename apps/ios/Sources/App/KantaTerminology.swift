import Foundation

enum KantaTerminology {
    static let appName = "KANTA"

    // Keep system chrome Latin-only unless a verified Baybayin font is bundled.
    static let displayName = "KANTA"

    // Use Latin control labels until a consistent Baybayin font is bundled.
    static let mySet = "MY SET"
    static let loop = "LOOP"
    static let scenic = "SCENIC"
    static let realm = "REALM"
    static let control = "CONTROL"

    // Baybayin strings remain available for deliberate artwork or screens that
    // provide a verified supporting font; system navigation uses Latin.
    static let baybayinMySet = "ᜋᜌ᜔ ᜐᜒᜆ᜔"
    static let baybayinLoop = "ᜎᜓᜉ᜔"
    static let baybayinScenic = "ᜐᜒᜈᜒᜃ᜔"
    static let baybayinRealm = "ᜍᜒᜎ᜔ᜋ᜔"
    static let baybayinControl = "ᜃᜓᜈ᜔ᜆ᜔ᜍᜓᜎ᜔"

    // Stable storage paths remain unchanged for compatibility.
    static let visualCategoryMap: [(folder: String, label: String)] = [
        ("USER", mySet),
        ("MOTION", loop),
        ("NATURE", scenic),
        ("3D", realm)
    ]
}

