import Foundation

public struct LibrarySourceRecord: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var displayName: String
    public var bookmarkData: Data
    public var addedAt: Date
    public var lastScan: LibraryScanResult?
    public var preferredSoundFontRelativePath: String?

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmarkData: Data,
        addedAt: Date = Date(),
        lastScan: LibraryScanResult? = nil,
        preferredSoundFontRelativePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
        self.lastScan = lastScan
        self.preferredSoundFontRelativePath =
            preferredSoundFontRelativePath
    }
}

public struct LibraryRegistryRecoveryNotice:
    Equatable,
    Sendable
{
    public let backupFileName: String

    public init(backupFileName: String) {
        self.backupFileName = backupFileName
    }
}

public actor LibrarySourceRegistry {
    public nonisolated let recoveryNotice:
        LibraryRegistryRecoveryNotice?

    private let fileURL: URL
    private var records: [LibrarySourceRecord]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)

            do {
                records = try JSONDecoder().decode(
                    [LibrarySourceRecord].self,
                    from: data
                )
                guard Set(records.map(\.id)).count == records.count else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                recoveryNotice = nil
            } catch {
                let backupFileName =
                    fileURL.lastPathComponent
                    + ".corrupt-"
                    + UUID().uuidString.lowercased()
                let backupURL = fileURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(backupFileName)

                try fileManager.moveItem(
                    at: fileURL,
                    to: backupURL
                )

                records = []
                recoveryNotice = LibraryRegistryRecoveryNotice(
                    backupFileName: backupFileName
                )
            }
        } else {
            records = []
            recoveryNotice = nil
        }
    }

    public func all() -> [LibrarySourceRecord] {
        records.sorted { $0.addedAt < $1.addedAt }
    }

    @discardableResult
    public func upsert(
        _ record: LibrarySourceRecord
    ) throws -> LibrarySourceRecord {
        var updated = records
        if let index = updated.firstIndex(
            where: { $0.id == record.id }
        ) {
            updated[index] = record
        } else {
            updated.append(record)
        }

        try persist(updated)
        records = updated
        return record
    }

    public func remove(id: UUID) throws {
        let updated = records.filter { $0.id != id }
        try persist(updated)
        records = updated
    }

    public func refreshBookmark(id: UUID, bookmarkData: Data) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        var updated = records
        updated[index].bookmarkData = bookmarkData
        try persist(updated)
        records = updated
    }

    private func persist(_ records: [LibrarySourceRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(
            to: fileURL,
            options: .atomic
        )
    }
}


