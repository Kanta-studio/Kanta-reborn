import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func midiParserReadsTempoNotesLyricsAndEndOfTrack() throws {
    let track: [UInt8] = [
        0x00, 0xFF, 0x03, 0x04, 0x54, 0x65, 0x73, 0x74,
        0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
        0x00, 0x90, 0x3C, 0x64,
        0x78, 0x80, 0x3C, 0x00,
        0x00, 0xFF, 0x05, 0x02, 0x48, 0x69,
        0x00, 0xFF, 0x2F, 0x00
    ]

    let parsed = try StandardMIDIParser.parse(
        midiFile(
            format: 0,
            division: 120,
            tracks: [track]
        )
    )

    #expect(parsed.header.format == 0)
    #expect(
        parsed.header.timeDivision
            == .ticksPerQuarterNote(120)
    )
    #expect(parsed.tracks.count == 1)
    #expect(parsed.tracks[0].events.count == 6)
    #expect(parsed.tracks[0].events[3].absoluteTicks == 120)
    #expect(
        parsed.tracks[0].events[1].message
            == .meta(
                .tempo(
                    microsecondsPerQuarterNote: 500_000
                )
            )
    )
    #expect(
        parsed.tracks[0].events[4].message
            == .meta(
                .text(
                    kind: .lyric,
                    value: "Hi",
                    raw: Data("Hi".utf8)
                )
            )
    )
    #expect(
        parsed.tracks[0].events[5].message
            == .meta(.endOfTrack)
    )
}

@Test func midiParserSupportsRunningStatus() throws {
    let track: [UInt8] = [
        0x00, 0x90, 0x3C, 0x64,
        0x0A, 0x3D, 0x5A,
        0x00, 0xFF, 0x2F, 0x00
    ]

    let parsed = try StandardMIDIParser.parse(
        midiFile(
            format: 0,
            division: 96,
            tracks: [track]
        )
    )

    #expect(
        parsed.tracks[0].events[1].message
            == .channel(
                .noteOn(
                    channel: 0,
                    key: 61,
                    velocity: 90
                )
            )
    )
    #expect(parsed.tracks[0].events[1].absoluteTicks == 10)
}

@Test func midiParserRejectsDataWithoutRunningStatus() {
    let track: [UInt8] = [0x00, 0x3C, 0x64]

    #expect(
        throws: StandardMIDIParserError.missingRunningStatus
    ) {
        _ = try StandardMIDIParser.parse(
            midiFile(
                format: 0,
                division: 96,
                tracks: [track]
            )
        )
    }
}

private func midiFile(
    format: UInt16,
    division: UInt16,
    tracks: [[UInt8]]
) -> Data {
    var bytes: [UInt8] = Array("MThd".utf8)
    bytes += [0, 0, 0, 6]
    bytes += be16(format)
    bytes += be16(UInt16(tracks.count))
    bytes += be16(division)

    for track in tracks {
        bytes += Array("MTrk".utf8)
        bytes += be32(UInt32(track.count))
        bytes += track
    }

    return Data(bytes)
}

private func be16(_ value: UInt16) -> [UInt8] {
    [
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
}

private func be32(_ value: UInt32) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
}

@Test func midiParserSupportsSlicedData() throws {
    let file = midiFile(format: 0, division: 120, tracks: [[0, 0xFF, 0x2F, 0]])
    var prefixed = Data([0xAB])
    prefixed.append(file)
    let parsed = try StandardMIDIParser.parse(prefixed.dropFirst())
    #expect(parsed.tracks.count == 1)
    #expect(parsed.tracks[0].events.count == 1)
}

