import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func melodyExtractorResolvesMonophonicLyricTrack() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    lyricEvent("Hello", tick: 0),
                    noteOn(key: 60, tick: 0),
                    noteOff(key: 60, tick: 120),
                    noteOn(key: 62, tick: 120),
                    noteOff(key: 62, tick: 240)
                ]
            )
        ]
    )

    let result = MIDIMelodyTargetExtractor.extract(
        from: file
    )

    guard case let .resolved(target) = result else {
        Issue.record("Expected lyric-bearing melody target")
        return
    }

    #expect(target.trackIndex == 0)
    #expect(target.channel == 0)
    #expect(target.evidence == .lyricBearingTrack)
    #expect(
        target.windows == [
            TargetPitchWindow(
                startMilliseconds: 0,
                endMilliseconds: 500,
                midiNote: 60
            ),
            TargetPitchWindow(
                startMilliseconds: 500,
                endMilliseconds: 1_000,
                midiNote: 62
            )
        ]
    )
}

@Test func melodyExtractorDoesNotGuessGenericInstrumentTrack() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    noteOn(key: 60, tick: 0),
                    noteOff(key: 60, tick: 120)
                ]
            )
        ]
    )

    #expect(
        MIDIMelodyTargetExtractor.extract(from: file)
            == .unavailable(.noStrongCandidate)
    )
}

@Test func melodyExtractorAcceptsExplicitVocalTrackName() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    textEvent(
                        kind: .trackName,
                        value: "Lead Vocal",
                        tick: 0
                    ),
                    noteOn(key: 64, tick: 0),
                    noteOff(key: 64, tick: 120)
                ]
            )
        ]
    )

    guard case let .resolved(target) =
        MIDIMelodyTargetExtractor.extract(from: file) else {
        Issue.record("Expected explicit vocal target")
        return
    }

    #expect(target.evidence == .explicitVocalTrackName)
    #expect(target.windows.map(\.midiNote) == [64])
}

@Test func melodyExtractorRejectsCompetingStrongCandidates() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    lyricEvent("A", tick: 0),
                    noteOn(key: 60, tick: 0),
                    noteOff(key: 60, tick: 120)
                ]
            ),
            StandardMIDITrack(
                events: [
                    lyricEvent("B", tick: 0),
                    noteOn(
                        channel: 1,
                        key: 67,
                        tick: 0
                    ),
                    noteOff(
                        channel: 1,
                        key: 67,
                        tick: 120
                    )
                ]
            )
        ]
    )

    #expect(
        MIDIMelodyTargetExtractor.extract(from: file)
            == .unavailable(.multipleStrongCandidates)
    )
}

@Test func melodyExtractorRejectsPolyphonicCandidate() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    lyricEvent("Chord", tick: 0),
                    noteOn(key: 60, tick: 0),
                    noteOn(key: 64, tick: 10),
                    noteOff(key: 60, tick: 120),
                    noteOff(key: 64, tick: 130)
                ]
            )
        ]
    )

    #expect(
        MIDIMelodyTargetExtractor.extract(from: file)
            == .unavailable(.candidateIsPolyphonic)
    )
}

@Test func melodyExtractorRejectsNonCenterPitchBend() {
    let file = scoringMIDIFile(
        tracks: [
            StandardMIDITrack(
                events: [
                    lyricEvent("Bend", tick: 0),
                    noteOn(key: 60, tick: 0),
                    TimedMIDIEvent(
                        deltaTicks: 60,
                        absoluteTicks: 60,
                        message: .channel(
                            .pitchBend(
                                channel: 0,
                                value14: 9_000
                            )
                        )
                    ),
                    noteOff(key: 60, tick: 120)
                ]
            )
        ]
    )

    #expect(
        MIDIMelodyTargetExtractor.extract(from: file)
            == .unavailable(.candidateUsesPitchBend)
    )
}

private func scoringMIDIFile(
    tracks: [StandardMIDITrack]
) -> StandardMIDIFile {
    StandardMIDIFile(
        header: StandardMIDIHeader(
            format: tracks.count > 1 ? 1 : 0,
            declaredTrackCount: UInt16(tracks.count),
            timeDivision: .ticksPerQuarterNote(120)
        ),
        tracks: tracks
    )
}

private func lyricEvent(
    _ text: String,
    tick: UInt64
) -> TimedMIDIEvent {
    textEvent(
        kind: .lyric,
        value: text,
        tick: tick
    )
}

private func textEvent(
    kind: MIDITextKind,
    value: String,
    tick: UInt64
) -> TimedMIDIEvent {
    TimedMIDIEvent(
        deltaTicks: 0,
        absoluteTicks: tick,
        message: .meta(
            .text(
                kind: kind,
                value: value,
                raw: Data(value.utf8)
            )
        )
    )
}

private func noteOn(
    channel: UInt8 = 0,
    key: UInt8,
    tick: UInt64
) -> TimedMIDIEvent {
    TimedMIDIEvent(
        deltaTicks: 0,
        absoluteTicks: tick,
        message: .channel(
            .noteOn(
                channel: channel,
                key: key,
                velocity: 100
            )
        )
    )
}

private func noteOff(
    channel: UInt8 = 0,
    key: UInt8,
    tick: UInt64
) -> TimedMIDIEvent {
    TimedMIDIEvent(
        deltaTicks: 0,
        absoluteTicks: tick,
        message: .channel(
            .noteOff(
                channel: channel,
                key: key,
                velocity: 0
            )
        )
    )
}

