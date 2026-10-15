import Foundation
import GeloKaraokeCore
import LegacyCompatibility

public struct IndexedContainerSourceFiles:
    Equatable,
    Sendable
{
    public let indexRelativePath: String
    public let blobRelativePath: String
    public let soundFontRelativePath: String?
}

public struct IndexedContainerCatalogEntry:
    Sendable
{
    public let sourceID: UUID
    public let song: LibrarySong
    public let recordIndex: Int
    public let payloadSpan: ContainerPayloadSpan
    public let indexRelativePath: String
    public let blobRelativePath: String
    public let soundFontRelativePath: String?
}

public enum IndexedContainerCatalogError:
    Error,
    Equatable,
    Sendable
{
    case missingContainerPair
    case malformedTitleIndex
    case offsetCorrelationRejected
}

public enum IndexedContainerCatalog {
    public static func sourceFiles(
        for source: LibrarySourceRecord
    ) -> IndexedContainerSourceFiles? {
        guard let assets =
                source.lastScan?.assets else {
            return nil
        }

        let indexPath = firstPath(
            of: .libraryIndex,
            in: assets
        )
        let blobPath = firstPath(
            of: .libraryContainer,
            in: assets
        )

        guard let indexPath,
              let blobPath else {
            return nil
        }

        return IndexedContainerSourceFiles(
            indexRelativePath: indexPath,
            blobRelativePath: blobPath,
            soundFontRelativePath:
                LooseMediaCatalog
                    .preferredSoundFont(
                        in: assets,
                        preferredRelativePath:
                            source.preferredSoundFontRelativePath
                    )
        )
    }

    public static func entries(
        for source: LibrarySourceRecord,
        indexData: Data,
        containerURL: URL
    ) throws -> [IndexedContainerCatalogEntry] {
        guard let files =
                sourceFiles(for: source) else {
            throw IndexedContainerCatalogError
                .missingContainerPair
        }

        let report = IndexedLibraryProbe.inspect(
            indexData,
            sampleLimit: 0
        )

        guard report.titleIndexRecordCount > 0,
              report
                .trailingBytesPerTitleRecord
                == 4 else {
            throw IndexedContainerCatalogError
                .malformedTitleIndex
        }

        let records =
            IndexedLibraryProbe
                .decodeTitleRecords(
                    indexData
                )
        guard records.count
                == report.titleIndexRecordCount else {
            throw IndexedContainerCatalogError
                .malformedTitleIndex
        }

        let spans: [ContainerPayloadSpan]
        do {
            spans =
                try ContainerSpanIndex.spans(
                    indexData: indexData,
                    containerURL: containerURL
                )
        } catch {
            throw IndexedContainerCatalogError
                .offsetCorrelationRejected
        }

        guard spans.count
                == records.count else {
            throw IndexedContainerCatalogError
                .offsetCorrelationRejected
        }

        return records.enumerated().map {
            recordIndex,
            record in

            let normalizedTitle =
                record.title
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
            let title =
                normalizedTitle.isEmpty
                ? "Legacy Song \(recordIndex + 1)"
                : normalizedTitle

            return IndexedContainerCatalogEntry(
                sourceID: source.id,
                song: LibrarySong(
                    id: SongID(
                        rawValue:
                            "indexed:"
                            + source.id
                                .uuidString
                                .lowercased()
                            + ":"
                            + String(
                                recordIndex
                            )
                    ),
                    title: title,
                    mediaKind:
                        .legacyContainer
                ),
                recordIndex: recordIndex,
                payloadSpan:
                    spans[recordIndex],
                indexRelativePath:
                    files.indexRelativePath,
                blobRelativePath:
                    files.blobRelativePath,
                soundFontRelativePath:
                    files.soundFontRelativePath
            )
        }
    }

    private static func firstPath(
        of kind: LibraryAssetKind,
        in assets: [DiscoveredLibraryAsset]
    ) -> String? {
        assets
            .filter { $0.kind == kind }
            .compactMap {
                LooseMediaCatalog
                    .normalizedRelativePath(
                        $0.relativePath
                    )
            }
            .sorted {
                $0.localizedStandardCompare($1)
                    == .orderedAscending
            }
            .first
    }
}

