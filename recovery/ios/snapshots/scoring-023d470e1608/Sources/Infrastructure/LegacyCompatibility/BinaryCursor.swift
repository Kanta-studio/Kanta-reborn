import Foundation

public enum BinaryCursorError: Error, Equatable, Sendable {
    case outOfBounds(offset: Int, requested: Int, available: Int)
    case invalidSeek(Int)
}

public struct BinaryCursor: Sendable {
    public let data: Data
    public private(set) var offset: Int

    public init(data: Data, offset: Int = 0) throws {
        guard offset >= 0, offset <= data.count else { throw BinaryCursorError.invalidSeek(offset) }
        self.data = data
        self.offset = offset
    }

    public var remaining: Int { data.count - offset }

    public mutating func seek(to newOffset: Int) throws {
        guard newOffset >= 0, newOffset <= data.count else { throw BinaryCursorError.invalidSeek(newOffset) }
        offset = newOffset
    }

    public mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0 else { throw BinaryCursorError.outOfBounds(offset: offset, requested: count, available: remaining) }
        guard count <= remaining else {
            throw BinaryCursorError.outOfBounds(offset: offset, requested: count, available: remaining)
        }
        let start = data.startIndex + offset
        let range = start..<(start + count)
        offset += count
        return data.subdata(in: range)
    }

    public mutating func readUInt8() throws -> UInt8 {
        guard remaining >= 1 else {
            throw BinaryCursorError.outOfBounds(offset: offset, requested: 1, available: remaining)
        }
        defer { offset += 1 }
        return data[data.startIndex + offset]
    }

    public mutating func readUInt16LE() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return UInt16(bytes[bytes.startIndex])
            | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }

    public mutating func readUInt32LE() throws -> UInt32 {
        let bytes = try readBytes(count: 4)
        var value: UInt32 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt32(byte) << UInt32(index * 8)
        }
        return value
    }

    public mutating func readUInt64LE() throws -> UInt64 {
        let bytes = try readBytes(count: 8)
        var value: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt64(byte) << UInt64(index * 8)
        }
        return value
    }
}


