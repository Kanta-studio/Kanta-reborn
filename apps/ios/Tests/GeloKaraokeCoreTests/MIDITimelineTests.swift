import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func midiTimelineAppliesTempoChangesAndTimesLyrics() {
    let file = StandardMIDIFile(
        header: StandardMIDIHeader(
            format: 1,
            declaredTrackCount: 1,
            timeDivision: .ticksPerQuarterNote(120)
        ),
        tracks: [
            StandardMIDITrack(
                events: [
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .meta(
                            .tempo(
                                microsecondsPerQuarterNote:
                                    500_000
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 120,
                        absoluteTicks: 120,
                        message: .meta(
                            .tempo(
                                microsecondsPerQuarterNote:
                                    250_000
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 120,
                        absoluteTicks: 240,
                        message: .meta(
                            .text(
                                kind: .lyric,
                                value: "Hello",
                                raw: Data("Hello".utf8)
                            )
                        )
                    )
                ]
            )
        ]
    )

    let timeline = MIDITimeline(file: file)
    #expect(timeline.milliseconds(atTick: 120) == 500)
    #expect(timeline.milliseconds(atTick: 240) == 750)
    #expect(
        timeline.lyricCues(in: file).map(\.milliseconds)
            == [750]
    )
}

@Test func midiTimelineSupportsSMPTETimeDivision() {
    let file = StandardMIDIFile(
        header: StandardMIDIHeader(
            format: 0,
            declaredTrackCount: 1,
            timeDivision: .smpte(
                framesPerSecond: 25,
                ticksPerFrame: 40
            )
        ),
        tracks: []
    )

    let timeline = MIDITimeline(file: file)
    #expect(timeline.milliseconds(atTick: 1_000) == 1_000)
}

