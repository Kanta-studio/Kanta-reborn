import Foundation
import GeloKaraokeCore

public enum SavedKaraokeSetKind: String, Codable, Sendable { case session, playlist }
public struct SavedKaraokeSet: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var songs: [LibrarySong]
    public let createdAt: Date
    public var kind: SavedKaraokeSetKind
    public let idempotencyKey: UUID?
    public init(id: UUID = UUID(), name: String, songs: [LibrarySong], createdAt: Date = .now,
                kind: SavedKaraokeSetKind = .session, idempotencyKey: UUID? = nil) {
        self.id = id; self.name = name; self.songs = songs; self.createdAt = createdAt
        self.kind = kind; self.idempotencyKey = idempotencyKey
    }
    private enum CodingKeys: String, CodingKey { case id, name, songs, createdAt, kind, idempotencyKey }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        songs = try c.decode([LibrarySong].self, forKey: .songs)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        kind = try c.decodeIfPresent(SavedKaraokeSetKind.self, forKey: .kind) ?? .session
        idempotencyKey = try c.decodeIfPresent(UUID.self, forKey: .idempotencyKey)
    }
}

/// All read-modify-write transactions complete without suspension. The durable
/// operation key makes a successful Save retry harmless even after reopening.
public actor SavedKaraokeSetStore {
    public enum StoreError: Error { case invalidName, missingCollection, invalidPosition, capacity }
    private let fileURL: URL
    private var sets: [SavedKaraokeSet]
    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 16 * 1024 * 1024 else { throw StoreError.capacity }
            sets = try JSONDecoder().decode([SavedKaraokeSet].self, from: Data(contentsOf: fileURL))
        } else { sets = [] }
        guard sets.count <= 1000, Set(sets.map(\.id)).count == sets.count,
              sets.allSatisfy({ $0.songs.count <= 10000 }) else { throw StoreError.capacity }
    }
    public func all() -> [SavedKaraokeSet] { sets.sorted { $0.createdAt > $1.createdAt } }
    @discardableResult
    public func save(name: String, songs: [LibrarySong], kind: SavedKaraokeSetKind = .session,
                     idempotencyKey: UUID? = nil) throws -> SavedKaraokeSet {
        if let key = idempotencyKey, let old = sets.first(where: { $0.idempotencyKey == key }) { return old }
        let name = try validatedName(name)
        guard sets.count < 1000, songs.count <= 10000 else { throw StoreError.capacity }
        let value = SavedKaraokeSet(id: UUID(), name: name, songs: songs,
                                   createdAt: .now, kind: kind, idempotencyKey: idempotencyKey)
        try commit(sets + [value]); return value
    }
    public func rename(id: UUID, to name: String) throws {
        var next = sets; next[try index(id)].name = try validatedName(name); try commit(next)
    }
    public func delete(id: UUID) throws { try commit(sets.filter { $0.id != id }) }
    public func append(song: LibrarySong, to id: UUID) throws {
        var next = sets; let i = try index(id)
        guard next[i].songs.count < 10000 else { throw StoreError.capacity }
        next[i].songs.append(song); try commit(next)
    }
    public func removeSong(at position: Int, from id: UUID) throws {
        var next = sets; let i = try index(id)
        guard next[i].songs.indices.contains(position) else { throw StoreError.invalidPosition }
        next[i].songs.remove(at: position); try commit(next)
    }
    public func moveSong(in id: UUID, from: Int, to: Int) throws {
        var next = sets; let i = try index(id)
        guard next[i].songs.indices.contains(from), next[i].songs.indices.contains(to) else {
            throw StoreError.invalidPosition
        }
        let song = next[i].songs.remove(at: from); next[i].songs.insert(song, at: to); try commit(next)
    }
    private func index(_ id: UUID) throws -> Int {
        guard let i = sets.firstIndex(where: { $0.id == id }) else { throw StoreError.missingCollection }
        return i
    }
    private func validatedName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 120 else { throw StoreError.invalidName }; return value
    }
    private func commit(_ next: [SavedKaraokeSet]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = try JSONEncoder().encode(next)
        guard bytes.count <= 16 * 1024 * 1024 else { throw StoreError.capacity }
        try bytes.write(to: fileURL, options: .atomic)
        sets = next // Never publish a mutation whose durable write failed.
    }
}
