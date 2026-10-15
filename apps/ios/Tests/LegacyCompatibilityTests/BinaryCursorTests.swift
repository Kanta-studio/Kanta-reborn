import Foundation
import Testing
@testable import LegacyCompatibility

@Test func binaryCursorReadsLittleEndianValues() throws {
    var cursor = try BinaryCursor(data: Data([0x34, 0x12, 0x78, 0x56, 0x34, 0x12]))
    #expect(try cursor.readUInt16LE() == 0x1234)
    #expect(try cursor.readUInt32LE() == 0x12345678)
    #expect(cursor.remaining == 0)
}

@Test func binaryCursorRejectsOutOfBoundsReads() throws {
    var cursor = try BinaryCursor(data: Data([0x01]))
    #expect(throws: BinaryCursorError.self) {
        _ = try cursor.readUInt32LE()
    }
}

@Test func binaryCursorSupportsSlicedData() throws {
    let bytes = Data([0xFF, 0x34, 0x12, 0xAB])
    var cursor = try BinaryCursor(data: bytes.dropFirst())
    #expect(try cursor.readUInt8() == 0x34)
    #expect(try cursor.readUInt16LE() == 0xAB12)
    #expect(cursor.remaining == 0)
}

