import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func playbackPlanOrdersMessagesAndCalculatesDuration() {
    let file = StandardMIDIFile(
        header: StandardMIDIHeader(
            format: 1,
            declaredTrackCount: 2,
            timeDivision: .ticksPerQuarterNote(480)
        ),
        tracks: [
            StandardMIDITrack(
                events: [
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .meta(
                            .tempo(
                                microsecondsPerQuarterNote: 500_000
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 480,
                        absoluteTicks: 480,
                        message: .channel(
                            .noteOn(
                                channel: 0,
                                key: 60,
                                velocity: 100
                            )
                        )
                    )
                ]
            ),
            StandardMIDITrack(
                events: [
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .channel(
                            .programChange(
                                channel: 0,
                                program: 10
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 960,
                        absoluteTicks: 960,
                        message: .meta(.endOfTrack)
                    )
                ]
            )
        ]
    )

    let plan = MIDIPlaybackPlan(file: file)

    #expect(plan.messages.count == 2)
    #expect(plan.messages[0].milliseconds == 0)
    #expect(plan.messages[1].milliseconds == 500)
    #expect(plan.durationMilliseconds == 1_000)
}

@Test func resumeStateRestoresChannelStateAndHeldNotes() {
    let file = StandardMIDIFile(
        header: StandardMIDIHeader(
            format: 0,
            declaredTrackCount: 1,
            timeDivision: .ticksPerQuarterNote(480)
        ),
        tracks: [
            StandardMIDITrack(
                events: [
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .channel(
                            .programChange(
                                channel: 1,
                                program: 12
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .channel(
                            .controlChange(
                                channel: 1,
                                controller: 7,
                                value: 100
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .channel(
                            .noteOn(
                                channel: 1,
                                key: 64,
                                velocity: 90
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 960,
                        absoluteTicks: 960,
                        message: .channel(
                            .noteOff(
                                channel: 1,
                                key: 64,
                                velocity: 0
                            )
                        )
                    )
                ]
            )
        ]
    )

    let plan = MIDIPlaybackPlan(file: file)
    let state = plan.resumeState(before: 500)

    #expect(state.stateMessages.count == 2)
    #expect(
        state.activeNotes == [
            MIDIActiveNote(
                channel: 1,
                key: 64,
                velocity: 90
            )
        ]
    )
}

@Test func messageIndexUsesLowerBoundSemantics() {
    let file = StandardMIDIFile(
        header: StandardMIDIHeader(
            format: 0,
            declaredTrackCount: 1,
            timeDivision: .ticksPerQuarterNote(480)
        ),
        tracks: [
            StandardMIDITrack(
                events: [
                    TimedMIDIEvent(
                        deltaTicks: 0,
                        absoluteTicks: 0,
                        message: .channel(
                            .programChange(
                                channel: 0,
                                program: 0
                            )
                        )
                    ),
                    TimedMIDIEvent(
                        deltaTicks: 480,
                        absoluteTicks: 480,
                        message: .channel(
                            .noteOn(
                                channel: 0,
                                key: 60,
                                velocity: 100
                            )
                        )
                    )
                ]
            )
        ]
    )

    let plan = MIDIPlaybackPlan(file: file)
    #expect(plan.messageIndex(atOrAfter: 0) == 0)
    #expect(plan.messageIndex(atOrAfter: 1) == 1)
    #expect(plan.messageIndex(atOrAfter: 500) == 1)
    #expect(plan.messageIndex(atOrAfter: 501) == 2)
}

