// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GeloKaraoke",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GeloKaraokeCore", targets: ["GeloKaraokeCore"]),
        .library(name: "LegacyCompatibility", targets: ["LegacyCompatibility"]),
        .library(name: "LibraryStorage", targets: ["LibraryStorage"]),
        .library(name: "AVFoundationPlayback", targets: ["AVFoundationPlayback"]),
        .library(name: "AVFoundationMIDIPlayback", targets: ["AVFoundationMIDIPlayback"]),
        .library(name: "LocalNetworkControl", targets: ["LocalNetworkControl"]),
        .library(name: "MicrophoneScoring", targets: ["MicrophoneScoring"]),
        .executable(name: "kanta-container-probe", targets: ["ContainerProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/SoundpipeAudioKit.git", exact: "5.7.4"),
        .package(url: "https://github.com/AudioKit/AudioKit.git", exact: "5.7.2")
    ],
    targets: [
        .target(
            name: "GeloKaraokeCore",
            path: "Sources/Core"
        ),
        .target(
            name: "GeloLegacyCompression",
            path: "Sources/Infrastructure/LegacyCompression",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("z")]
        ),
        .target(
            name: "LegacyCompatibility",
            dependencies: ["GeloKaraokeCore", "GeloLegacyCompression"],
            path: "Sources/Infrastructure/LegacyCompatibility"
        ),
        .target(
            name: "LibraryStorage",
            dependencies: ["GeloKaraokeCore", "LegacyCompatibility"],
            path: "Sources/Infrastructure/LibraryStorage",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "AVFoundationPlayback",
            dependencies: ["GeloKaraokeCore"],
            path: "Sources/Infrastructure/AVFoundationPlayback"
        ),
        .target(
            name: "AVFoundationMIDIPlayback",
            dependencies: ["GeloKaraokeCore"],
            path: "Sources/Infrastructure/AVFoundationMIDIPlayback"
        ),
        .target(
            name: "LocalNetworkControl",
            dependencies: ["GeloKaraokeCore"],
            path: "Sources/Infrastructure/LocalNetworkControl"
        ),
        .target(
            name: "MicrophoneScoring",
            dependencies: [
                "GeloKaraokeCore",
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit"),
                .product(name: "AudioKit", package: "AudioKit")
            ],
            path: "Sources/Infrastructure/MicrophoneScoring"
        ),
        .executableTarget(
            name: "ContainerProbe",
            dependencies: ["LegacyCompatibility"],
            path: "Tools/ContainerProbe"
        ),
        .testTarget(
            name: "GeloKaraokeCoreTests",
            dependencies: ["GeloKaraokeCore"],
            path: "Tests/GeloKaraokeCoreTests"
        ),
        .testTarget(
            name: "LegacyCompatibilityTests",
            dependencies: ["LegacyCompatibility"],
            path: "Tests/LegacyCompatibilityTests"
        ),
        .testTarget(
            name: "LibraryStorageTests",
            dependencies: ["LibraryStorage"],
            path: "Tests/LibraryStorageTests"
        ),
        .testTarget(
            name: "AVFoundationPlaybackTests",
            dependencies: ["AVFoundationPlayback", "GeloKaraokeCore"],
            path: "Tests/AVFoundationPlaybackTests"
        ),
        .testTarget(
            name: "AVFoundationMIDIPlaybackTests",
            dependencies: ["AVFoundationMIDIPlayback", "GeloKaraokeCore"],
            path: "Tests/AVFoundationMIDIPlaybackTests"
        ),
        .testTarget(
            name: "LocalNetworkControlTests",
            dependencies: ["LocalNetworkControl", "GeloKaraokeCore"],
            path: "Tests/LocalNetworkControlTests"
        ),
        .testTarget(
            name: "MicrophoneScoringTests",
            dependencies: ["MicrophoneScoring", "GeloKaraokeCore"],
            path: "Tests/MicrophoneScoringTests"
        )
    ]
)

