import Foundation

public enum MIDIMelodyTargetEvidence:
    String,
    Equatable,
    Codable,
    Sendable
{
    case lyricBearingTrack
    case explicitVocalTrackName
}

public struct MIDIMelodyTarget:
    Equatable,
    Codable,
    Sendable
{
    public let trackIndex: Int
    public let channel: UInt8
    public let evidence: MIDIMelodyTargetEvidence
    public let windows: [TargetPitchWindow]

    public init(
        trackIndex: Int,
        channel: UInt8,
        evidence: MIDIMelodyTargetEvidence,
        windows: [TargetPitchWindow]
    ) {
        self.trackIndex = trackIndex
        self.channel = channel
        self.evidence = evidence
        self.windows = windows
    }
}

public enum MIDIMelodyTargetUnavailableReason:
    Equatable,
    Codable,
    Sendable
{
    case noStrongCandidate
    case multipleStrongCandidates
    case candidateIsPolyphonic
    case candidateUsesPitchBend
    case malformedNoteLifecycle
    case noTargetNotes
}

public enum MIDIMelodyTargetExtraction:
    Equatable,
    Codable,
    Sendable
{
    case resolved(MIDIMelodyTarget)
    case unavailable(MIDIMelodyTargetUnavailableReason)
}

public enum MIDIMelodyTargetExtractor {
    private struct Candidate: Equatable, Sendable {
        let trackIndex: Int
        let channel: UInt8
        let evidence: MIDIMelodyTargetEvidence
    }

    private static let explicitVocalNames: Set<String> = [
        "melody",
        "vocal",
        "vocals",
        "voice",
        "guide vocal",
        "guide vocals",
        "guide melody",
        "melody guide",
        "lead vocal",
        "lead vocals"
    ]

    public static func extract(
        from file: StandardMIDIFile
    ) -> MIDIMelodyTargetExtraction {
        let candidates = strongCandidates(in: file)

        guard candidates.count == 1,
              let candidate = candidates.first else {
            return .unavailable(
                candidates.isEmpty
                    ? .noStrongCandidate
                    : .multipleStrongCandidates
            )
        }

        return extract(
            from: file,
            trackIndex: candidate.trackIndex,
            channel: candidate.channel,
            evidence: candidate.evidence
        )
    }

    public static func extract(
        from file: StandardMIDIFile,
        trackIndex: Int,
        channel: UInt8,
        evidence: MIDIMelodyTargetEvidence
    ) -> MIDIMelodyTargetExtraction {
        guard file.tracks.indices.contains(trackIndex),
              channel <= 15,
              channel != 9 else {
            return .unavailable(.noStrongCandidate)
        }

        let track = file.tracks[trackIndex]
        let timeline = MIDITimeline(file: file)

        var active: [UInt8: UInt64] = [:]
        var windows: [TargetPitchWindow] = []

        for event in track.events {
            guard case let .channel(message) = event.message else {
                continue
            }

            switch message {
            case let .noteOn(eventChannel, key, velocity)
                where eventChannel == channel:
                if velocity == 0 {
                    guard let start = active.removeValue(
                        forKey: key
                    ) else {
                        return .unavailable(
                            .malformedNoteLifecycle
                        )
                    }

                    guard let window = pitchWindow(
                        key: key,
                        startTick: start,
                        endTick: event.absoluteTicks,
                        timeline: timeline
                    ) else {
                        return .unavailable(
                            .malformedNoteLifecycle
                        )
                    }
                    windows.append(window)
                } else {
                    guard active.isEmpty,
                          active[key] == nil else {
                        return .unavailable(
                            .candidateIsPolyphonic
                        )
                    }
                    active[key] = event.absoluteTicks
                }

            case let .noteOff(eventChannel, key, _)
                where eventChannel == channel:
                guard let start = active.removeValue(
                    forKey: key
                ) else {
                    return .unavailable(
                        .malformedNoteLifecycle
                    )
                }

                guard let window = pitchWindow(
                    key: key,
                    startTick: start,
                    endTick: event.absoluteTicks,
                    timeline: timeline
                ) else {
                    return .unavailable(
                        .malformedNoteLifecycle
                    )
                }
                windows.append(window)

            case let .pitchBend(eventChannel, value14)
                where eventChannel == channel
                    && value14 != 8_192:
                return .unavailable(.candidateUsesPitchBend)

            default:
                break
            }
        }

        guard active.isEmpty else {
            return .unavailable(.malformedNoteLifecycle)
        }
        guard !windows.isEmpty else {
            return .unavailable(.noTargetNotes)
        }

        windows.sort {
            if $0.startMilliseconds
                != $1.startMilliseconds {
                return $0.startMilliseconds
                    < $1.startMilliseconds
            }
            if $0.endMilliseconds
                != $1.endMilliseconds {
                return $0.endMilliseconds
                    < $1.endMilliseconds
            }
            return $0.midiNote < $1.midiNote
        }

        return .resolved(
            MIDIMelodyTarget(
                trackIndex: trackIndex,
                channel: channel,
                evidence: evidence,
                windows: windows
            )
        )
    }

    private static func strongCandidates(
        in file: StandardMIDIFile
    ) -> [Candidate] {
        var result: [Candidate] = []

        for (trackIndex, track) in file.tracks.enumerated() {
            let channels = noteBearingChannels(in: track)
                .filter { $0 != 9 }

            guard channels.count == 1,
                  let channel = channels.first else {
                continue
            }

            if containsLyrics(track) {
                result.append(
                    Candidate(
                        trackIndex: trackIndex,
                        channel: channel,
                        evidence: .lyricBearingTrack
                    )
                )
                continue
            }

            if hasExplicitVocalName(track) {
                result.append(
                    Candidate(
                        trackIndex: trackIndex,
                        channel: channel,
                        evidence: .explicitVocalTrackName
                    )
                )
            }
        }

        return result
    }

    private static func noteBearingChannels(
        in track: StandardMIDITrack
    ) -> Set<UInt8> {
        var channels: Set<UInt8> = []

        for event in track.events {
            guard case let .channel(message) = event.message else {
                continue
            }

            if case let .noteOn(channel, _, velocity) = message,
               velocity > 0 {
                channels.insert(channel)
            }
        }

        return channels
    }

    private static func containsLyrics(
        _ track: StandardMIDITrack
    ) -> Bool {
        track.events.contains { event in
            guard case let .meta(
                .text(kind: kind, value: value, raw: _)
            ) = event.message else {
                return false
            }

            return kind == .lyric
                && !value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
        }
    }

    private static func hasExplicitVocalName(
        _ track: StandardMIDITrack
    ) -> Bool {
        for event in track.events {
            guard case let .meta(
                .text(kind: kind, value: value, raw: _)
            ) = event.message,
            kind == .trackName
                || kind == .instrumentName else {
                continue
            }

            let normalized = value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

            if explicitVocalNames.contains(normalized) {
                return true
            }
        }

        return false
    }

    private static func pitchWindow(
        key: UInt8,
        startTick: UInt64,
        endTick: UInt64,
        timeline: MIDITimeline
    ) -> TargetPitchWindow? {
        guard endTick > startTick else {
            return nil
        }

        let start = timeline.milliseconds(
            atTick: startTick
        )
        let end = timeline.milliseconds(
            atTick: endTick
        )

        guard end > start else {
            return nil
        }

        return TargetPitchWindow(
            startMilliseconds: start,
            endMilliseconds: end,
            midiNote: Int(key)
        )
    }
}

