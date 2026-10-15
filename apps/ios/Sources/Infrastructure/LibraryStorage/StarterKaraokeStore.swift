import Foundation
import GeloKaraokeCore

/// One instance per app, owned by BookmarkedKaraokeLibrary. Only private copies
/// are mutable; bundled originals and imported folders never enter this store.
public actor StarterKaraokeStore {
    public enum StoreError: LocalizedError, Equatable {
        public var errorDescription: String? {
            switch self {
            case .unknownSong: "This starter song is not part of the installed pack."
            case .invalidBundledFile: "The bundled starter song is missing or invalid. Reinstall or update KANTA to repair the pack."
            case .unsafeStorage: "Starter storage contains an unsafe path. Your imported music has not been changed."
            }
        }

        case unknownSong
        case invalidBundledFile
        case unsafeStorage
    }

    public struct Snapshot: Sendable {
        public let revision: UInt64
        public let urls: [String: URL]
        public let removed: Set<String>
    }

    public static let identifiers = ["morning-light", "sing-together", "starlight-echo"]
    public static func song(_ identifier: String) -> LibrarySong {
        LibrarySong(id: SongID(rawValue: "starter:" + identifier),
                    title: identifier.replacingOccurrences(of: "-", with: " ").capitalized,
                    artist: "KANTA Originals", mediaKind: .kar)
    }

    private let originals: URL
    private let managed: URL
    private let stateURL: URL
    private let fileManager: FileManager
    private var removed: Set<String>
    private var revision: UInt64 = 0

    public init(originals: URL, managed: URL, fileManager: FileManager = .default) throws {
        let source = originals.standardizedFileURL.resolvingSymlinksInPath()
        let target = managed.standardizedFileURL.resolvingSymlinksInPath()
        guard source.path != target.path,
              !target.path.hasPrefix(source.path + "/"),
              !source.path.hasPrefix(target.path + "/") else { throw StoreError.unsafeStorage }
        self.originals = source
        self.managed = target
        self.stateURL = target.appendingPathComponent("removed-starters.json")
        self.fileManager = fileManager
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: stateURL.path) {
            // Fail closed on corruption/read errors: never forget explicit removal.
            guard stateURL.resolvingSymlinksInPath().path == stateURL.path else { throw StoreError.unsafeStorage }
            let data = try Data(contentsOf: stateURL)
            self.removed = Set(try JSONDecoder().decode([String].self, from: data))
                .intersection(Self.identifiers)
        } else {
            self.removed = []
        }
    }

    public func snapshot() -> Snapshot {
        var urls: [String: URL] = [:]
        for identifier in Self.identifiers where !removed.contains(identifier) {
            let url = destination(for: identifier)
            if fileManager.fileExists(atPath: url.path), url.resolvingSymlinksInPath().path == url.path {
                urls[identifier] = url
            }
        }
        return Snapshot(revision: revision, urls: urls, removed: removed)
    }

    public func installedURL(for identifier: String) throws -> URL? {
        try validate(identifier)
        return snapshot().urls[identifier]
    }

    @discardableResult
    public func installIfAllowed(_ identifier: String) throws -> URL? {
        try Task.checkCancellation()
        defer { revision &+= 1 }
        try validate(identifier)
        guard !removed.contains(identifier) else { return nil }
        let url = try copyIfMissing(identifier)
        return url
    }

    public func remove(_ identifier: String) throws {
        try Task.checkCancellation()
        defer { revision &+= 1 }
        try validate(identifier)
        let newState = removed.union([identifier])
        try persist(newState)
        removed = newState
        let url = destination(for: identifier)
        // Tombstone is authoritative even if cleanup fails; retry is safe.
        if fileManager.fileExists(atPath: url.path) {
            guard url.resolvingSymlinksInPath().path == url.path else { throw StoreError.unsafeStorage }
            try fileManager.removeItem(at: url)
        }
    }

    @discardableResult
    public func restore(_ identifier: String) throws -> URL {
        try Task.checkCancellation()
        defer { revision &+= 1 }
        try validate(identifier)
        let url = try copyIfMissing(identifier)
        let newState = removed.subtracting([identifier])
        try persist(newState)
        removed = newState
        return url
    }

    public func restoreAll() throws {
        try Task.checkCancellation()
        defer { revision &+= 1 }
        // No await/cancellation between copying and durable publication. If a
        // copy fails, prior tombstones still hide any partially prepared copies.
        for identifier in Self.identifiers { _ = try copyIfMissing(identifier) }
        try persist([])
        removed = []
    }

    public func installAvailableSongs() throws -> [URL] {
        try Task.checkCancellation()
        defer { revision &+= 1 }
        var urls: [URL] = []
        for identifier in Self.identifiers where !removed.contains(identifier) {
            urls.append(try copyIfMissing(identifier))
        }
        return urls
    }

    public func removedIdentifiers() -> Set<String> { removed }

    private func validate(_ identifier: String) throws {
        guard Self.identifiers.contains(identifier) else { throw StoreError.unknownSong }
    }

    private func destination(for identifier: String) -> URL {
        managed.appendingPathComponent(identifier + ".kar")
    }

    private func copyIfMissing(_ identifier: String) throws -> URL {
        let destination = destination(for: identifier)
        guard managed.resolvingSymlinksInPath().path == managed.path,
              destination.resolvingSymlinksInPath().path == destination.path else { throw StoreError.unsafeStorage }
        let source = originals.appendingPathComponent(identifier + ".kar")
        guard source.resolvingSymlinksInPath().path == source.path,
              fileManager.fileExists(atPath: source.path) else { throw StoreError.invalidBundledFile }
        let data = try Data(contentsOf: source)
        let file = try StandardMIDIParser.parse(data)
        guard !MIDITimeline(file: file).lyricCues(in: file).isEmpty else { throw StoreError.invalidBundledFile }
        if let existing = try? Data(contentsOf: destination), existing == data { return destination }
        // Small bounded originals: atomic replacement repairs interrupted/corrupt
        // managed copies without ever rewriting the read-only source.
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func persist(_ state: Set<String>) throws {
        guard managed.resolvingSymlinksInPath().path == managed.path,
              stateURL.resolvingSymlinksInPath().path == stateURL.path else { throw StoreError.unsafeStorage }
        try JSONEncoder().encode(state.sorted()).write(to: stateURL, options: .atomic)
    }
}
