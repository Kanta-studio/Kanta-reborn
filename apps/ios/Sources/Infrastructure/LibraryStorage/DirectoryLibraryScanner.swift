import Foundation
import GeloKaraokeCore
import LegacyCompatibility

public enum LibraryAssetKind: Codable, Hashable, Sendable {
    case libraryIndex
    case libraryContainer
    case soundFont
    case midi
    case kar
    case mp3
    case wav
    case backgroundVideo
    case backgroundImage
    case other

    public var rawValue: String { storageValue }

    private var storageValue: String {
        switch self {
        case .libraryIndex: "libraryIndex"
        case .libraryContainer: "libraryContainer"
        case .soundFont: "soundFont"
        case .midi: "midi"
        case .kar: "kar"
        case .mp3: "mp3"
        case .wav: "wav"
        case .backgroundVideo: "backgroundVideo"
        case .backgroundImage: "backgroundImage"
        case .other: "other"
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
            .decode(String.self)

        switch value {
        case "libraryIndex":
            self = .libraryIndex
        case "libraryContainer":
            self = .libraryContainer
        case "soundFont":
            self = .soundFont
        case "midi":
            self = .midi
        case "kar":
            self = .kar
        case "mp3":
            self = .mp3
        case "wav":
            self = .wav
        case "backgroundVideo":
            self = .backgroundVideo
        case "backgroundImage":
            self = .backgroundImage

        // Preserve existing user registries created by older scanner
        // schemas. These persisted values are migrated into neutral
        // categories and are never shown in the UI.
        case "shubIndex":
            self = .libraryIndex
        case "shubBlob":
            self = .libraryContainer
        case "megIndex", "megMidi", "megVolume":
            self = .other

        default:
            self = .other
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

public struct DiscoveredLibraryAsset: Hashable, Codable, Sendable {
    public let relativePath: String
    public let sizeBytes: Int64
    public let kind: LibraryAssetKind

    public init(
        relativePath: String,
        sizeBytes: Int64,
        kind: LibraryAssetKind
    ) {
        self.relativePath = relativePath
        self.sizeBytes = sizeBytes
        self.kind = kind
    }
}

public struct LibraryScanResult: Equatable, Codable, Sendable {
    public let rootDisplayName: String
    public let assets: [DiscoveredLibraryAsset]

    public init(
        rootDisplayName: String,
        assets: [DiscoveredLibraryAsset]
    ) {
        self.rootDisplayName = rootDisplayName
        self.assets = assets.sorted {
            $0.relativePath.localizedStandardCompare(
                $1.relativePath
            ) == .orderedAscending
        }
    }

    public var hasLibraryIndex: Bool {
        assets.contains { $0.kind == .libraryIndex }
    }

    public var hasLibraryContainer: Bool {
        assets.contains { $0.kind == .libraryContainer }
    }

    public var hasIndexedLibrary: Bool {
        hasLibraryIndex && hasLibraryContainer
    }

    public var looseSongCount: Int {
        assets.count {
            [.midi, .kar, .mp3, .wav].contains($0.kind)
        }
    }

    public var soundFontCount: Int {
        assets.count { $0.kind == .soundFont }
    }

    public var backgroundVideoCount: Int {
        assets.count { $0.kind == .backgroundVideo }
    }

    public var backgroundImageCount: Int {
        assets.count { $0.kind == .backgroundImage }
    }

    public var recognizedAssetCount: Int {
        assets.count { $0.kind != .other }
    }
}

public struct DirectoryLibraryScanner: Sendable {
    private static let maximumIndexProbeBytes: Int64 =
        32 * 1024 * 1024

    private struct ScanFile {
        let url: URL
        let relativePath: String
        let sizeBytes: Int64
        var kind: LibraryAssetKind
    }

    public init() {}

    public func scan(root: URL) throws -> LibraryScanResult {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [
                .skipsHiddenFiles,
                .skipsPackageDescendants
            ],
            errorHandler: { _, _ in true }
        ) else {
            throw LibraryScanError.cannotEnumerate(root)
        }

        var files: [ScanFile] = []
        let canonicalRoot = root
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPrefix = canonicalRoot.path.hasSuffix("/")
            ? canonicalRoot.path
            : canonicalRoot.path + "/"

        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: keys
            )
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                continue
            }

            let canonicalURL = url
                .standardizedFileURL
                .resolvingSymlinksInPath()
            guard canonicalURL.path.hasPrefix(rootPrefix) else {
                continue
            }
            let relativePath = String(
                canonicalURL.path.dropFirst(rootPrefix.count)
            )
            files.append(
                ScanFile(
                    url: canonicalURL,
                    relativePath: relativePath,
                    sizeBytes: Int64(
                        values.fileSize ?? 0
                    ),
                    kind: Self.classify(url)
                )
            )
        }

        Self.identifyIndexedLibraryPairs(
            in: &files
        )

        return LibraryScanResult(
            rootDisplayName: root.lastPathComponent,
            assets: files.map {
                DiscoveredLibraryAsset(
                    relativePath:
                        $0.relativePath,
                    sizeBytes: $0.sizeBytes,
                    kind: $0.kind
                )
            }
        )
    }

    public static func classify(
        _ url: URL
    ) -> LibraryAssetKind {
        switch url.pathExtension.lowercased() {
        case "sf2":
            return isValidSF2(at: url)
                ? .soundFont
                : .other
        case "sfz":
            return .soundFont
        case "mid", "midi":
            return .midi
        case "kar":
            return .kar
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        case "mp4", "mov", "m4v":
            return .backgroundVideo
        case "jpg", "jpeg", "png", "heic", "webp":
            return .backgroundImage
        default:
            return .other
        }
    }

    private static func isValidSF2(
        at url: URL
    ) -> Bool {
        guard let handle = try? FileHandle(
            forReadingFrom: url
        ) else {
            return false
        }
        defer { try? handle.close() }

        guard let header = try? handle.read(
            upToCount: 12
        ),
        header.count >= 12 else {
            return false
        }

        return header.prefix(4)
            == Data("RIFF".utf8)
            && header.subdata(in: 8..<12)
                == Data("sfbk".utf8)
    }

    private static func identifyIndexedLibraryPairs(
        in files: inout [ScanFile]
    ) {
        let indexCandidates = files.indices.filter {
            files[$0].kind == .other
                && files[$0].sizeBytes > 0
                && files[$0].sizeBytes
                    <= maximumIndexProbeBytes
        }

        for indexPosition in indexCandidates {
            guard files[indexPosition].kind == .other,
                  let indexData = try? Data(
                    contentsOf:
                        files[indexPosition].url,
                    options: [.mappedIfSafe]
                  ) else {
                continue
            }

            let report = IndexedLibraryProbe.inspect(
                indexData,
                sampleLimit: 1
            )
            guard report.metadataTableOffset != nil,
                  report.titleIndexRecordCount > 0,
                  report.trailingBytesPerTitleRecord == 4,
                  report.titleIndexSamples.first?.title != "<binary>" else {
                continue
            }

            let offsets =
                IndexedLibraryProbe
                    .trailingUInt32Values(
                        in: indexData
                    )
            guard offsets.count
                    == report
                        .titleIndexRecordCount else {
                continue
            }

            let matchingContainers =
                files.indices.filter { position in
                    guard position
                            != indexPosition,
                          files[position].kind
                            == .other,
                          files[position].sizeBytes
                            > 0,
                          files[position].sizeBytes
                            <= Int64(Int.max) else {
                        return false
                    }

                    let correlation =
                        ContainerOffsetCorrelator
                            .correlate(
                                trailingValues:
                                    offsets,
                                expectedTitleCount:
                                    report
                                        .titleIndexRecordCount,
                                containerByteCount:
                                    Int(
                                        files[position]
                                            .sizeBytes
                                    ),
                                sampleLimit: 0
                            )
                    guard correlation.verdict
                            == .structurallyPlausible
                    else {
                        return false
                    }

                    return ContainerPayloadProbe
                        .containsRecognizedPayload(
                            indexData: indexData,
                            containerURL:
                                files[position].url,
                            sampleLimit:
                                min(
                                    8,
                                    report
                                        .titleIndexRecordCount
                                )
                        )
                }

            files[indexPosition].kind = .libraryIndex
            if matchingContainers.count == 1,
               let containerPosition = matchingContainers.first {
                files[containerPosition].kind = .libraryContainer
            }
        }
    }
}

public enum LibraryScanError:
    Error,
    Equatable,
    Sendable
{
    case cannotEnumerate(URL)
}
