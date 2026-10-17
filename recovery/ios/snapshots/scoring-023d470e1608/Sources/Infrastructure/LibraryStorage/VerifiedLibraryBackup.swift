import Foundation

/// Files remain byte-preserved. The caller coordinates provider/iCloud access.
public enum VerifiedLibraryBackup {
    public static func sourceURL(root: URL, relativePath: String) throws -> URL {
        guard let path = LooseMediaCatalog.normalizedRelativePath(relativePath) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let source = root.appendingPathComponent(path)
            .resolvingSymlinksInPath().standardizedFileURL
        guard source.path.hasPrefix(resolvedRoot.path + "/") else {
            throw CocoaError(.fileReadNoPermission)
        }
        return source
    }

    /// Verify a sibling temporary copy before atomically replacing the prior backup.
    /// A read/copy/verification failure leaves the existing destination untouched.
    @discardableResult
    public static func copy(source: URL, destination: URL) throws -> Int64 {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let before = try freshResourceValues(at: source, forKeys: keys)
        guard before.isRegularFile == true, let size = before.fileSize else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let parent = destination.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = parent.appendingPathComponent(".kanta-copy-" + UUID().uuidString)
        defer { try? manager.removeItem(at: temporary) }
        try manager.copyItem(at: source, to: temporary)
        let after = try freshResourceValues(at: source, forKeys: keys)
        let copied = try freshResourceValues(at: temporary, forKeys: [.fileSizeKey])
        guard after.fileSize == size,
              after.contentModificationDate == before.contentModificationDate else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "The source file changed while its backup was being copied."
            ])
        }
        guard copied.fileSize == size else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "The temporary backup size does not match the source file."
            ])
        }
        if manager.fileExists(atPath: destination.path) {
            _ = try manager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: destination)
        }
        return Int64(size)
    }

    /// A reused URL can retain metadata from the preceding copy, even when the
    /// underlying file has changed. Clear both cached and temporary values before
    /// EVERY read, including the starting snapshot; refreshing only afterward
    /// incorrectly compares a stale baseline against the current file.
    private static func freshResourceValues(
        at url: URL,
        forKeys keys: Set<URLResourceKey>
    ) throws -> URLResourceValues {
        var uncachedURL = url
        uncachedURL.removeAllCachedResourceValues()
        return try uncachedURL.resourceValues(forKeys: keys)
    }
}

