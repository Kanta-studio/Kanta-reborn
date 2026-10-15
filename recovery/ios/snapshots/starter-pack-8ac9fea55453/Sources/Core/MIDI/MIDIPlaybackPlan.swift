import Foundation

public struct ScheduledMIDIMessage: Equatable, Sendable {
    public let milliseconds: Int64
    public let trackIndex: Int
    public let eventIndex: Int
    public let message: MIDIMessage

    public init(
        milliseconds: Int64,
        trackIndex: Int,
        eventIndex: Int,
        message: MIDIMessage
    ) {
        self.milliseconds = milliseconds
        self.trackIndex = trackIndex
        self.eventIndex = eventIndex
        self.message = message
    }
}

public struct MIDIActiveNote: Equatable, Sendable {
    public let channel: UInt8
    public let key: UInt8
    public let velocity: UInt8

    public init(channel: UInt8, key: UInt8, velocity: UInt8) {
        self.channel = channel
        self.key = key
        self.velocity = velocity
    }
}

public struct MIDIResumeState: Equatable, Sendable {
    public let stateMessages: [ScheduledMIDIMessage]
    public let activeNotes: [MIDIActiveNote]

    public init(
        stateMessages: [ScheduledMIDIMessage],
        activeNotes: [MIDIActiveNote]
    ) {
        self.stateMessages = stateMessages
        self.activeNotes = activeNotes
    }
}

public struct MIDIPlaybackPlan: Equatable, Sendable {
    public let messages: [ScheduledMIDIMessage]
    public let lyrics: [KaraokeLyricCue]
    public let durationMilliseconds: Int64

    public init(file: StandardMIDIFile) {
        let timeline = MIDITimeline(file: file)
        var scheduled: [ScheduledMIDIMessage] = []
        var maximumTick: UInt64 = 0

        for (trackIndex, track) in file.tracks.enumerated() {
            for (eventIndex, event) in track.events.enumerated() {
                maximumTick = max(maximumTick, event.absoluteTicks)

                switch event.message {
                case .channel, .systemExclusive:
                    scheduled.append(
                        ScheduledMIDIMessage(
                            milliseconds: timeline.milliseconds(
                                atTick: event.absoluteTicks
                            ),
                            trackIndex: trackIndex,
                            eventIndex: eventIndex,
                            message: event.message
                        )
                    )
                case .meta:
                    break
                }
            }
        }

        messages = scheduled.sorted(by: Self.precedes)
        lyrics = timeline.lyricCues(in: file)
        durationMilliseconds = timeline.milliseconds(atTick: maximumTick)
    }

    public func messageIndex(atOrAfter milliseconds: Int64) -> Int {
        var low = 0
        var high = messages.count

        while low < high {
            let mid = (low + high) / 2
            if messages[mid].milliseconds < milliseconds {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    public func resumeState(before milliseconds: Int64) -> MIDIResumeState {
        var latestProgram: [UInt8: ScheduledMIDIMessage] = [:]
        var latestPitchBend: [UInt8: ScheduledMIDIMessage] = [:]
        var latestChannelPressure: [UInt8: ScheduledMIDIMessage] = [:]
        var latestController: [ControllerKey: ScheduledMIDIMessage] = [:]
        var systemExclusive: [ScheduledMIDIMessage] = []
        var activeNotes: [NoteKey: MIDIActiveNote] = [:]

        for event in messages {
            guard event.milliseconds < milliseconds else { break }

            switch event.message {
            case let .channel(message):
                switch message {
                case let .noteOn(channel, key, velocity):
                    let noteKey = NoteKey(channel: channel, key: key)
                    if velocity == 0 {
                        activeNotes.removeValue(forKey: noteKey)
                    } else {
                        activeNotes[noteKey] = MIDIActiveNote(
                            channel: channel,
                            key: key,
                            velocity: velocity
                        )
                    }

                case let .noteOff(channel, key, _):
                    activeNotes.removeValue(
                        forKey: NoteKey(channel: channel, key: key)
                    )

                case let .controlChange(channel, controller, _):
                    latestController[
                        ControllerKey(
                            channel: channel,
                            controller: controller
                        )
                    ] = event

                case let .programChange(channel, _):
                    latestProgram[channel] = event

                case let .channelPressure(channel, _):
                    latestChannelPressure[channel] = event

                case let .pitchBend(channel, _):
                    latestPitchBend[channel] = event

                case .polyphonicKeyPressure:
                    break
                }

            case .systemExclusive:
                systemExclusive.append(event)

            case .meta:
                break
            }
        }

        var stateMessages = systemExclusive
        stateMessages.append(contentsOf: latestController.values)
        stateMessages.append(contentsOf: latestProgram.values)
        stateMessages.append(contentsOf: latestPitchBend.values)
        stateMessages.append(contentsOf: latestChannelPressure.values)
        stateMessages.sort(by: Self.precedes)

        return MIDIResumeState(
            stateMessages: stateMessages,
            activeNotes: activeNotes.values.sorted {
                if $0.channel != $1.channel {
                    return $0.channel < $1.channel
                }
                return $0.key < $1.key
            }
        )
    }

    private static func precedes(
        _ lhs: ScheduledMIDIMessage,
        _ rhs: ScheduledMIDIMessage
    ) -> Bool {
        if lhs.milliseconds != rhs.milliseconds {
            return lhs.milliseconds < rhs.milliseconds
        }
        if lhs.trackIndex != rhs.trackIndex {
            return lhs.trackIndex < rhs.trackIndex
        }
        return lhs.eventIndex < rhs.eventIndex
    }

    private struct ControllerKey: Hashable {
        let channel: UInt8
        let controller: UInt8
    }

    private struct NoteKey: Hashable {
        let channel: UInt8
        let key: UInt8
    }
}
