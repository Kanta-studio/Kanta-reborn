import Foundation

public struct KaraokeLyricCue: Equatable, Sendable {
    public let trackIndex: Int
    public let eventIndex: Int
    public let absoluteTicks: UInt64
    public let milliseconds: Int64
    public let text: String

    public init(
        trackIndex: Int,
        eventIndex: Int,
        absoluteTicks: UInt64,
        milliseconds: Int64,
        text: String
    ) {
        self.trackIndex = trackIndex
        self.eventIndex = eventIndex
        self.absoluteTicks = absoluteTicks
        self.milliseconds = milliseconds
        self.text = text
    }
}

public struct MIDITimeline: Sendable {
    private struct TempoSegment: Sendable {
        let startTick: UInt64
        let startMicroseconds: Double
        let microsecondsPerQuarterNote: UInt32
    }

    public let timeDivision: MIDITimeDivision
    private let tempoSegments: [TempoSegment]

    public init(file: StandardMIDIFile) {
        timeDivision = file.header.timeDivision

        guard case let .ticksPerQuarterNote(ticksPerQuarter) =
            timeDivision else {
            tempoSegments = []
            return
        }

        var tempoEvents: [
            (tick: UInt64, order: Int, tempo: UInt32)
        ] = []
        var order = 0

        for track in file.tracks {
            for event in track.events {
                if case let .meta(
                    .tempo(microsecondsPerQuarterNote: tempo)
                ) = event.message,
                   tempo > 0 {
                    tempoEvents.append(
                        (event.absoluteTicks, order, tempo)
                    )
                }
                order += 1
            }
        }

        tempoEvents.sort {
            if $0.tick != $1.tick {
                return $0.tick < $1.tick
            }
            return $0.order < $1.order
        }

        var segments = [
            TempoSegment(
                startTick: 0,
                startMicroseconds: 0,
                microsecondsPerQuarterNote: 500_000
            )
        ]

        for tempoEvent in tempoEvents {
            let previous = segments[segments.count - 1]

            if tempoEvent.tick == previous.startTick {
                segments[segments.count - 1] = TempoSegment(
                    startTick: previous.startTick,
                    startMicroseconds: previous.startMicroseconds,
                    microsecondsPerQuarterNote: tempoEvent.tempo
                )
                continue
            }

            let elapsedTicks =
                tempoEvent.tick - previous.startTick
            let elapsedMicroseconds =
                Double(elapsedTicks)
                * Double(previous.microsecondsPerQuarterNote)
                / Double(ticksPerQuarter)

            segments.append(
                TempoSegment(
                    startTick: tempoEvent.tick,
                    startMicroseconds:
                        previous.startMicroseconds
                        + elapsedMicroseconds,
                    microsecondsPerQuarterNote: tempoEvent.tempo
                )
            )
        }

        tempoSegments = segments
    }

    public func microseconds(atTick tick: UInt64) -> Double {
        switch timeDivision {
        case let .ticksPerQuarterNote(ticksPerQuarter):
            let segment = tempoSegment(atTick: tick)
            let ticksIntoSegment = tick - segment.startTick

            return segment.startMicroseconds
                + Double(ticksIntoSegment)
                    * Double(segment.microsecondsPerQuarterNote)
                    / Double(ticksPerQuarter)

        case let .smpte(framesPerSecond, ticksPerFrame):
            let fps = framesPerSecond == 29
                ? 29.97
                : Double(framesPerSecond)

            return Double(tick)
                / (fps * Double(ticksPerFrame))
                * 1_000_000
        }
    }

    public func milliseconds(atTick tick: UInt64) -> Int64 {
        let value = microseconds(atTick: tick) / 1_000
        if value >= Double(Int64.max) {
            return Int64.max
        }
        return Int64(max(0, value.rounded(.towardZero)))
    }

    public func lyricCues(
        in file: StandardMIDIFile
    ) -> [KaraokeLyricCue] {
        var result: [KaraokeLyricCue] = []

        for (trackIndex, track) in file.tracks.enumerated() {
            for (eventIndex, event) in track.events.enumerated() {
                guard case let .meta(
                    .text(kind: .lyric, value: text, raw: _)
                ) = event.message else {
                    continue
                }

                result.append(
                    KaraokeLyricCue(
                        trackIndex: trackIndex,
                        eventIndex: eventIndex,
                        absoluteTicks: event.absoluteTicks,
                        milliseconds:
                            milliseconds(
                                atTick: event.absoluteTicks
                            ),
                        text: text
                    )
                )
            }
        }

        return result.sorted {
            if $0.absoluteTicks != $1.absoluteTicks {
                return $0.absoluteTicks < $1.absoluteTicks
            }
            if $0.trackIndex != $1.trackIndex {
                return $0.trackIndex < $1.trackIndex
            }
            return $0.eventIndex < $1.eventIndex
        }
    }

    private func tempoSegment(
        atTick tick: UInt64
    ) -> TempoSegment {
        var low = 0
        var high = tempoSegments.count

        while low < high {
            let mid = (low + high) / 2
            if tempoSegments[mid].startTick <= tick {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return tempoSegments[max(0, low - 1)]
    }
}

