import Foundation
import GeloKaraokeCore

public struct LooseMediaCatalogEntry: Equatable, Sendable {
    public let sourceID: UUID
    public let song: LibrarySong
    public let relativePath: String
    public let soundFontRelativePath: String?
    public let backgroundRelativePath: String?
    public let backgroundKind: KaraokeBackgroundKind?

    public init(
        sourceID: UUID,
        song: LibrarySong,
        relativePath: String,
        soundFontRelativePath: String?,
        backgroundRelativePath: String? = nil,
        backgroundKind: KaraokeBackgroundKind? = nil
    ) {
        self.sourceID = sourceID
        self.song = song
        self.relativePath = relativePath
        self.soundFontRelativePath = soundFontRelativePath
        self.backgroundRelativePath = backgroundRelativePath
        self.backgroundKind = backgroundKind
    }
}

public enum LooseMediaCatalog {
    public static func entries(
        for source: LibrarySourceRecord
    ) -> [LooseMediaCatalogEntry] {
        guard let scan = source.lastScan else { return [] }

        let soundFont = preferredSoundFont(
            in: scan.assets,
            preferredRelativePath:
                source.preferredSoundFontRelativePath
        )
        let backgrounds = backgroundCandidates(
            in: scan.assets,
            rootDisplayName: scan.rootDisplayName
        )

        return scan.assets.compactMap { asset in
            guard let mediaKind = mediaKind(for: asset.kind),
                  let relativePath = normalizedRelativePath(
                    asset.relativePath
                  ) else {
                return nil
            }

            let filename = URL(
                fileURLWithPath: relativePath
            )
            .deletingPathExtension()
            .lastPathComponent

            guard !filename.isEmpty else { return nil }

            let songID = SongID(
                rawValue:
                    "file:\(source.id.uuidString.lowercased()):" +
                    relativePath
            )

            let background = preferredBackground(
                forSongRelativePath: relativePath,
                in: backgrounds
            )

            return LooseMediaCatalogEntry(
                sourceID: source.id,
                song: LibrarySong(
                    id: songID,
                    title: filename,
                    mediaKind: mediaKind
                ),
                relativePath: relativePath,
                soundFontRelativePath:
                    mediaKind == .midi || mediaKind == .kar
                    ? soundFont
                    : nil,
                backgroundRelativePath: background?.relativePath,
                backgroundKind: background?.kind
            )
        }
        .sorted {
            let titleOrder = $0.song.title.localizedStandardCompare(
                $1.song.title
            )
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            return $0.relativePath.localizedStandardCompare(
                $1.relativePath
            ) == .orderedAscending
        }
    }

    private struct BackgroundCandidate {
        let relativePath: String
        let directory: String
        let stem: String
        let kind: KaraokeBackgroundKind
        let isLibraryPoolAsset: Bool
    }

    private static func backgroundCandidates(
        in assets: [DiscoveredLibraryAsset],
        rootDisplayName: String
    ) -> [BackgroundCandidate] {
        assets.compactMap { asset in
            let kind: KaraokeBackgroundKind
            switch asset.kind {
            case .backgroundVideo:
                kind = .video
            case .backgroundImage:
                kind = .image
            default:
                return nil
            }

            guard let relativePath = normalizedRelativePath(
                asset.relativePath
            ) else {
                return nil
            }

            return BackgroundCandidate(
                relativePath: relativePath,
                directory: directory(of: relativePath),
                stem: stem(of: relativePath),
                kind: kind,
                isLibraryPoolAsset: isBackgroundLibraryPath(
                    relativePath,
                    rootDisplayName: rootDisplayName,
                    kind: kind
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .video
            }
            return lhs.relativePath.localizedStandardCompare(
                rhs.relativePath
            ) == .orderedAscending
        }
    }

    private static func preferredBackground(
        forSongRelativePath relativePath: String,
        in candidates: [BackgroundCandidate]
    ) -> BackgroundCandidate? {
        let songDirectory = directory(of: relativePath)
        let songStem = stem(of: relativePath)

        if let exact = candidates.first(where: {
            $0.directory == songDirectory
                && $0.stem == songStem
        }) {
            return exact
        }

        if let localDefault = candidates.first(where: {
            $0.directory == songDirectory
                && $0.stem == "background"
        }) {
            return localDefault
        }

        if let rootDefault = candidates.first(where: {
            $0.directory.isEmpty
                && $0.stem == "background"
        }) {
            return rootDefault
        }

        return candidates.first {
            $0.isLibraryPoolAsset
        }
    }

    private static func isBackgroundLibraryPath(
        _ relativePath: String,
        rootDisplayName: String,
        kind: KaraokeBackgroundKind
    ) -> Bool {
        let normalizedRoot = rootDisplayName.lowercased()

        if kind == .video, normalizedRoot == "bgv" {
            return true
        }

        if kind == .image,
           normalizedRoot == "bg"
            || normalizedRoot == "bgphoto" {
            return true
        }

        guard let first = relativePath
            .lowercased()
            .split(separator: "/")
            .first else {
            return false
        }

        switch kind {
        case .video:
            return first == "bgv"
        case .image:
            return first == "bg" || first == "bgphoto"
        }
    }

    private static func directory(of relativePath: String) -> String {
        let directory = (relativePath as NSString)
            .deletingLastPathComponent
        return directory == "." ? "" : directory.lowercased()
    }

    private static func stem(of relativePath: String) -> String {
        let filename = (relativePath as NSString).lastPathComponent
        return (filename as NSString)
            .deletingPathExtension
            .lowercased()
    }

    public static func normalizedRelativePath(
        _ rawPath: String
    ) -> String? {
        let slashNormalized = rawPath.replacingOccurrences(
            of: "\\",
            with: "/"
        )

        guard !slashNormalized.hasPrefix("/"), !slashNormalized.contains("\0") else {
            return nil
        }

        let components = slashNormalized.split(
            separator: "/",
            omittingEmptySubsequences: true
        )

        guard !components.isEmpty,
              components.allSatisfy({
                  $0 != "." && $0 != ".."
              }) else {
            return nil
        }

        return components.joined(separator: "/")
    }

    private static func mediaKind(
        for kind: LibraryAssetKind
    ) -> MediaKind? {
        switch kind {
        case .midi:
            return .midi
        case .kar:
            return .kar
        case .mp3:
            return .mp3
        case .wav:
            return .wav
        default:
            return nil
        }
    }

    static func preferredSoundFont(
        in assets: [DiscoveredLibraryAsset],
        preferredRelativePath: String? = nil
    ) -> String? {
        let sf2Assets = assets.compactMap { asset -> String? in
            guard asset.kind == .soundFont,
                  asset.relativePath
                    .lowercased()
                    .hasSuffix(".sf2"),
                  let normalized = normalizedRelativePath(
                    asset.relativePath
                  ) else {
                return nil
            }
            return normalized
        }
        .sorted {
            $0.localizedStandardCompare($1)
                == .orderedAscending
        }

        if let preferredRelativePath,
           let normalizedPreferred =
            normalizedRelativePath(
                preferredRelativePath
            ),
           sf2Assets.contains(where: {
               $0.caseInsensitiveCompare(
                   normalizedPreferred
               ) == .orderedSame
           }) {
            return sf2Assets.first {
                $0.caseInsensitiveCompare(
                    normalizedPreferred
                ) == .orderedSame
            }
        }

        // No vendor-specific filename preference: any valid .sf2 can be
        // selected explicitly, otherwise deterministic path order wins.
        return sf2Assets.first
    }
}


