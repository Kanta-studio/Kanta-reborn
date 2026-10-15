import Foundation
import Testing
@testable import LibraryStorage

@Test func backupReplacesVerifiedBytesAndKeepsPreviousOnReadFailure() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let source = root.appendingPathComponent("song.wav")
    let destination = root.appendingPathComponent("backup/song.wav")
    try Data([1, 2, 3]).write(to: source)
    #expect(try VerifiedLibraryBackup.copy(source: source, destination: destination) == 3)
    // Deliberately warm metadata on the same URL reused by the next backup.
    let originalMetadata = try source.resourceValues(
        forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
    )
    #expect(originalMetadata.fileSize == 3)
    try Data([4, 5]).write(to: source)
    #expect(try VerifiedLibraryBackup.copy(source: source, destination: destination) == 2)
    #expect(try Data(contentsOf: destination) == Data([4, 5]))
    try manager.removeItem(at: source)
    #expect(throws: (any Error).self) {
        try VerifiedLibraryBackup.copy(source: source, destination: destination)
    }
    #expect(try Data(contentsOf: destination) == Data([4, 5]))
    #expect(try manager.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path) == ["song.wav"])
}

@Test func backupRejectsTraversalAndSymlinkEscape() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let library = root.appendingPathComponent("library")
    try manager.createDirectory(at: library, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let outside = root.appendingPathComponent("private.wav")
    try Data([1]).write(to: outside)
    try manager.createSymbolicLink(at: library.appendingPathComponent("escape.wav"), withDestinationURL: outside)
    for path in ["../private.wav", "escape.wav", "/private.wav"] {
        #expect(throws: (any Error).self) {
            try VerifiedLibraryBackup.sourceURL(root: library, relativePath: path)
        }
    }
}

@Test func backupRefreshesCachedModificationDateForSameSizeRewrite() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let source = root.appendingPathComponent("song.wav")
    let destination = root.appendingPathComponent("backup/song.wav")
    let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
    let changedDate = originalDate.addingTimeInterval(60)
    try Data([1, 2, 3]).write(to: source)
    try manager.setAttributes([.modificationDate: originalDate], ofItemAtPath: source.path)
    #expect(try VerifiedLibraryBackup.copy(source: source, destination: destination) == 3)
    let cached = try source.resourceValues(forKeys: [.contentModificationDateKey])
    #expect(cached.contentModificationDate == originalDate)

    try Data([7, 8, 9]).write(to: source)
    try manager.setAttributes([.modificationDate: changedDate], ofItemAtPath: source.path)
    #expect(try VerifiedLibraryBackup.copy(source: source, destination: destination) == 3)
    #expect(try Data(contentsOf: destination) == Data([7, 8, 9]))
}

