import Foundation

public struct StandardMIDIFile: Equatable, Sendable {
    public let header: StandardMIDIHeader
    public let tracks: [StandardMIDITrack]

    public init(header: StandardMIDIHeader, tracks: [StandardMIDITrack]) {
        self.header = header
        self.tracks = tracks
    }
}

public struct StandardMIDIHeader: Equatable, Sendable {
    public let format: UInt16
    public let declaredTrackCount: UInt16
    public let timeDivision: MIDITimeDivision

    public init(
        format: UInt16,
        declaredTrackCount: UInt16,
        timeDivision: MIDITimeDivision
    ) {
        self.format = format
        self.declaredTrackCount = declaredTrackCount
        self.timeDivision = timeDivision
    }
}

public enum MIDITimeDivision: Equatable, Sendable {
    case ticksPerQuarterNote(UInt16)
    case smpte(framesPerSecond: Int, ticksPerFrame: UInt8)
}

public struct StandardMIDITrack: Equatable, Sendable {
    public let events: [TimedMIDIEvent]

    public init(events: [TimedMIDIEvent]) {
        self.events = events
    }
}

public struct TimedMIDIEvent: Equatable, Sendable {
    public let deltaTicks: UInt32
    public let absoluteTicks: UInt64
    public let message: MIDIMessage

    public init(
        deltaTicks: UInt32,
        absoluteTicks: UInt64,
        message: MIDIMessage
    ) {
        self.deltaTicks = deltaTicks
        self.absoluteTicks = absoluteTicks
        self.message = message
    }
}

public enum MIDIMessage: Equatable, Sendable {
    case channel(MIDIChannelMessage)
    case meta(MIDIMetaEvent)
    case systemExclusive(Data)
}

public enum MIDIChannelMessage: Equatable, Sendable {
    case noteOff(channel: UInt8, key: UInt8, velocity: UInt8)
    case noteOn(channel: UInt8, key: UInt8, velocity: UInt8)
    case polyphonicKeyPressure(channel: UInt8, key: UInt8, pressure: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)
    case channelPressure(channel: UInt8, pressure: UInt8)
    case pitchBend(channel: UInt8, value14: UInt16)
}

public enum MIDITextKind: UInt8, Equatable, Sendable {
    case text = 0x01
    case copyright = 0x02
    case trackName = 0x03
    case instrumentName = 0x04
    case lyric = 0x05
    case marker = 0x06
    case cuePoint = 0x07
    case programName = 0x08
    case deviceName = 0x09
}

public enum MIDIMetaEvent: Equatable, Sendable {
    case text(kind: MIDITextKind, value: String, raw: Data)
    case tempo(microsecondsPerQuarterNote: UInt32)
    case timeSignature(
        numerator: UInt8,
        denominatorPower: UInt8,
        clocksPerClick: UInt8,
        thirtySecondsPerQuarter: UInt8
    )
    case keySignature(sharpsFlats: Int8, isMinor: Bool)
    case endOfTrack
    case raw(type: UInt8, payload: Data)
}

