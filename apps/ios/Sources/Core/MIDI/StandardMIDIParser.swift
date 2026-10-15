import Foundation

public enum StandardMIDIParserError: Error, Equatable, Sendable {
    case invalidHeader
    case invalidHeaderLength(UInt32)
    case unsupportedFormat(UInt16)
    case invalidTimeDivision(UInt16)
    case missingTrackChunk(index: Int)
    case truncatedChunk
    case malformedVariableLengthQuantity
    case missingRunningStatus
    case invalidStatus(UInt8)
    case invalidDataByte(UInt8)
    case truncatedEvent
    case absoluteTickOverflow
}

public enum StandardMIDIParser {
    public static func parse(_ data: Data) throws -> StandardMIDIFile {
        var cursor = Cursor(data: data)
        guard try cursor.readASCII(count: 4) == "MThd" else {
            throw StandardMIDIParserError.invalidHeader
        }

        let headerLength = try cursor.readUInt32BE()
        guard headerLength >= 6 else {
            throw StandardMIDIParserError.invalidHeaderLength(headerLength)
        }
        guard UInt64(headerLength) <= UInt64(cursor.remaining) else {
            throw StandardMIDIParserError.truncatedChunk
        }

        let format = try cursor.readUInt16BE()
        guard format <= 2 else {
            throw StandardMIDIParserError.unsupportedFormat(format)
        }
        let trackCount = try cursor.readUInt16BE()
        let divisionRaw = try cursor.readUInt16BE()
        let division = try parseTimeDivision(divisionRaw)

        if headerLength > 6 {
            try cursor.skip(Int(headerLength - 6))
        }

        var tracks: [StandardMIDITrack] = []
        tracks.reserveCapacity(Int(trackCount))

        for trackIndex in 0..<Int(trackCount) {
            guard try cursor.readASCII(count: 4) == "MTrk" else {
                throw StandardMIDIParserError.missingTrackChunk(index: trackIndex)
            }
            let trackLength = try cursor.readUInt32BE()
            guard UInt64(trackLength) <= UInt64(cursor.remaining) else {
                throw StandardMIDIParserError.truncatedChunk
            }
            let trackData = try cursor.readData(count: Int(trackLength))
            tracks.append(try parseTrack(trackData))
        }

        return StandardMIDIFile(
            header: StandardMIDIHeader(
                format: format,
                declaredTrackCount: trackCount,
                timeDivision: division
            ),
            tracks: tracks
        )
    }

    private static func parseTimeDivision(
        _ raw: UInt16
    ) throws -> MIDITimeDivision {
        if raw & 0x8000 == 0 {
            let ticks = raw & 0x7FFF
            guard ticks > 0 else {
                throw StandardMIDIParserError.invalidTimeDivision(raw)
            }
            return .ticksPerQuarterNote(ticks)
        }

        let signedFPS = Int8(bitPattern: UInt8((raw >> 8) & 0xFF))
        let ticksPerFrame = UInt8(raw & 0xFF)
        guard signedFPS < 0, ticksPerFrame > 0 else {
            throw StandardMIDIParserError.invalidTimeDivision(raw)
        }
        return .smpte(
            framesPerSecond: -Int(signedFPS),
            ticksPerFrame: ticksPerFrame
        )
    }

    private static func parseTrack(
        _ data: Data
    ) throws -> StandardMIDITrack {
        var cursor = Cursor(data: data)
        var runningStatus: UInt8?
        var absoluteTicks: UInt64 = 0
        var events: [TimedMIDIEvent] = []

        while cursor.remaining > 0 {
            let delta = try cursor.readVLQ()
            let (newAbsolute, overflow) =
                absoluteTicks.addingReportingOverflow(UInt64(delta))
            guard !overflow else {
                throw StandardMIDIParserError.absoluteTickOverflow
            }
            absoluteTicks = newAbsolute

            let first = try cursor.readByte()
            let message: MIDIMessage

            if first < 0x80 {
                guard let status = runningStatus else {
                    throw StandardMIDIParserError.missingRunningStatus
                }
                message = .channel(
                    try parseChannel(
                        status: status,
                        firstDataByte: first,
                        cursor: &cursor
                    )
                )
            } else if first <= 0xEF {
                runningStatus = first
                message = .channel(
                    try parseChannel(
                        status: first,
                        firstDataByte: nil,
                        cursor: &cursor
                    )
                )
            } else if first == 0xFF {
                message = .meta(try parseMeta(cursor: &cursor))
            } else if first == 0xF0 || first == 0xF7 {
                let length = try cursor.readVLQ()
                message = .systemExclusive(
                    try cursor.readData(count: Int(length))
                )
            } else {
                throw StandardMIDIParserError.invalidStatus(first)
            }

            events.append(
                TimedMIDIEvent(
                    deltaTicks: delta,
                    absoluteTicks: absoluteTicks,
                    message: message
                )
            )
        }

        return StandardMIDITrack(events: events)
    }

    private static func parseChannel(
        status: UInt8,
        firstDataByte: UInt8?,
        cursor: inout Cursor
    ) throws -> MIDIChannelMessage {
        let command = status & 0xF0
        let channel = status & 0x0F
        let dataLength: Int

        switch command {
        case 0xC0, 0xD0:
            dataLength = 1
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0:
            dataLength = 2
        default:
            throw StandardMIDIParserError.invalidStatus(status)
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(dataLength)

        if let firstDataByte {
            guard firstDataByte < 0x80 else {
                throw StandardMIDIParserError.invalidDataByte(firstDataByte)
            }
            bytes.append(firstDataByte)
        }

        while bytes.count < dataLength {
            let byte = try cursor.readByte()
            guard byte < 0x80 else {
                throw StandardMIDIParserError.invalidDataByte(byte)
            }
            bytes.append(byte)
        }

        switch command {
        case 0x80:
            return .noteOff(
                channel: channel,
                key: bytes[0],
                velocity: bytes[1]
            )
        case 0x90:
            return .noteOn(
                channel: channel,
                key: bytes[0],
                velocity: bytes[1]
            )
        case 0xA0:
            return .polyphonicKeyPressure(
                channel: channel,
                key: bytes[0],
                pressure: bytes[1]
            )
        case 0xB0:
            return .controlChange(
                channel: channel,
                controller: bytes[0],
                value: bytes[1]
            )
        case 0xC0:
            return .programChange(
                channel: channel,
                program: bytes[0]
            )
        case 0xD0:
            return .channelPressure(
                channel: channel,
                pressure: bytes[0]
            )
        case 0xE0:
            let value = UInt16(bytes[0]) | (UInt16(bytes[1]) << 7)
            return .pitchBend(
                channel: channel,
                value14: value
            )
        default:
            throw StandardMIDIParserError.invalidStatus(status)
        }
    }

    private static func parseMeta(
        cursor: inout Cursor
    ) throws -> MIDIMetaEvent {
        let type = try cursor.readByte()
        let length = try cursor.readVLQ()
        let payload = try cursor.readData(count: Int(length))

        if let textKind = MIDITextKind(rawValue: type) {
            return .text(
                kind: textKind,
                value: decodeText(payload),
                raw: payload
            )
        }

        switch type {
        case 0x2F:
            guard payload.isEmpty else {
                return .raw(type: type, payload: payload)
            }
            return .endOfTrack

        case 0x51 where payload.count == 3:
            let value =
                UInt32(payload[payload.startIndex]) << 16
                | UInt32(payload[payload.startIndex + 1]) << 8
                | UInt32(payload[payload.startIndex + 2])
            return .tempo(
                microsecondsPerQuarterNote: value
            )

        case 0x58 where payload.count == 4:
            return .timeSignature(
                numerator: payload[payload.startIndex],
                denominatorPower: payload[payload.startIndex + 1],
                clocksPerClick: payload[payload.startIndex + 2],
                thirtySecondsPerQuarter: payload[payload.startIndex + 3]
            )

        case 0x59 where payload.count == 2:
            return .keySignature(
                sharpsFlats: Int8(
                    bitPattern: payload[payload.startIndex]
                ),
                isMinor: payload[payload.startIndex + 1] != 0
            )

        default:
            return .raw(type: type, payload: payload)
        }
    }

    private static func decodeText(_ payload: Data) -> String {
        if let utf8 = String(data: payload, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: payload, encoding: .isoLatin1) {
            return latin1
        }
        return ""
    }

    private struct Cursor {
        let data: Data
        var offset = 0

        var remaining: Int { data.count - offset }

        mutating func readByte() throws -> UInt8 {
            guard remaining >= 1 else {
                throw StandardMIDIParserError.truncatedEvent
            }
            defer { offset += 1 }
            return data[data.startIndex + offset]
        }

        mutating func readUInt16BE() throws -> UInt16 {
            let bytes = try readData(count: 2)
            return UInt16(bytes[bytes.startIndex]) << 8
                | UInt16(bytes[bytes.startIndex + 1])
        }

        mutating func readUInt32BE() throws -> UInt32 {
            let bytes = try readData(count: 4)
            return UInt32(bytes[bytes.startIndex]) << 24
                | UInt32(bytes[bytes.startIndex + 1]) << 16
                | UInt32(bytes[bytes.startIndex + 2]) << 8
                | UInt32(bytes[bytes.startIndex + 3])
        }

        mutating func readASCII(count: Int) throws -> String {
            let bytes = try readData(count: count)
            return String(decoding: bytes, as: UTF8.self)
        }

        mutating func readData(count: Int) throws -> Data {
            guard count >= 0, count <= remaining else {
                throw StandardMIDIParserError.truncatedChunk
            }
            defer { offset += count }
            let start = data.startIndex + offset
            return data.subdata(in: start..<(start + count))
        }

        mutating func skip(_ count: Int) throws {
            guard count >= 0, count <= remaining else {
                throw StandardMIDIParserError.truncatedChunk
            }
            offset += count
        }

        mutating func readVLQ() throws -> UInt32 {
            var value: UInt32 = 0
            for index in 0..<4 {
                let byte = try readByte()
                value = (value << 7) | UInt32(byte & 0x7F)
                if byte & 0x80 == 0 {
                    return value
                }
                if index == 3 {
                    throw StandardMIDIParserError
                        .malformedVariableLengthQuantity
                }
            }
            throw StandardMIDIParserError
                .malformedVariableLengthQuantity
        }
    }
}


