import Foundation
import GeloKaraokeCore
import SQLite3

/// Owned solely by BookmarkedKaraokeLibrary's actor. Persisted metadata is never
/// treated as permission to play media; the library resolves authorized sources.
final class SQLiteSongCatalog {
    private var db: OpaquePointer?
    private var current: [LibrarySong]?
    private enum CatalogError: Error { case database }
    init(fileURL: URL) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }; db = nil; throw CatalogError.database
        }
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("CREATE TABLE IF NOT EXISTS songs (id TEXT PRIMARY KEY, ordinal INTEGER NOT NULL, searchable TEXT NOT NULL, payload TEXT NOT NULL)")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { if let db { sqlite3_close(db) } }
    func replaceIfChanged(_ songs: [LibrarySong]) throws {
        guard current != songs else { return }
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DELETE FROM songs")
            let statement = try prepare("INSERT INTO songs(id,ordinal,searchable,payload) VALUES(?,?,?,?)")
            defer { sqlite3_finalize(statement) }
            for (i, song) in songs.enumerated() {
                sqlite3_reset(statement); sqlite3_clear_bindings(statement)
                try bind(song.id.rawValue, to: statement, at: 1)
                guard sqlite3_bind_int64(statement, 2, Int64(i)) == SQLITE_OK else { throw CatalogError.database }
                try bind(Self.normalize([song.code ?? "", song.title, song.artist ?? ""].joined(separator: " ")), to: statement, at: 3)
                let data = try JSONEncoder().encode(song)
                guard let json = String(data: data, encoding: .utf8) else { throw CatalogError.database }
                try bind(json, to: statement, at: 4)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw CatalogError.database }
            }
            try execute("COMMIT"); current = songs
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func search(_ query: String, limit: Int, offset: Int) throws -> [LibrarySong] {
        let terms = Self.normalize(String(query.prefix(200))).split(whereSeparator: \.isWhitespace).map(String.init)
        let filters = terms.map { _ in "instr(searchable, ?) > 0" }.joined(separator: " AND ")
        let sql = "SELECT payload FROM songs" + (terms.isEmpty ? "" : " WHERE " + filters) + " ORDER BY ordinal LIMIT ? OFFSET ?"
        let statement = try prepare(sql); defer { sqlite3_finalize(statement) }
        for (i, term) in terms.enumerated() { try bind(term, to: statement, at: Int32(i + 1)) }
        sqlite3_bind_int(statement, Int32(terms.count + 1), Int32(min(max(limit, 1), 500)))
        sqlite3_bind_int(statement, Int32(terms.count + 2), Int32(min(max(offset, 0), 500000)))
        var result: [LibrarySong] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { throw CatalogError.database }
            result.append(try JSONDecoder().decode(LibrarySong.self, from: Data(String(cString: text).utf8)))
        }
    }
    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw CatalogError.database }
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw CatalogError.database }
        return statement
    }
    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else { throw CatalogError.database }
    }
}
