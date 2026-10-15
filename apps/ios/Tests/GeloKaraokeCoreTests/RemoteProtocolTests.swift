import Foundation
import Testing
@testable import GeloKaraokeCore

@Test func remoteCommandRoundTripsThroughStableEnvelope() throws {
    let command = KaraokeCommand.setPitch(semitones: -3)
    let envelope = RemoteEnvelope(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        body: .command(RemoteCommand(command: command))
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(envelope)
    let decoded = try JSONDecoder().decode(RemoteEnvelope.self, from: data)

    #expect(decoded == envelope)
    guard case let .command(remoteCommand) = decoded.body else {
        Issue.record("Expected command body")
        return
    }
    #expect(try remoteCommand.domainCommand() == command)
}

@Test func snapshotClampsUnsafeControlValues() {
    let snapshot = KaraokeSnapshot(
        positionMilliseconds: -10,
        volume: 3,
        pitchSemitones: 99,
        tempoRatio: 0.1
    )

    #expect(snapshot.positionMilliseconds == 0)
    #expect(snapshot.volume == 1)
    #expect(snapshot.pitchSemitones == 12)
    #expect(snapshot.tempoRatio == 0.5)
}

@Test func remoteCommandRejectsOutOfRangeControlValues() {
    let invalidVolume = RemoteCommand(action: .setVolume, floatValue: 4)
    #expect(throws: RemoteProtocolError.invalidField("floatValue")) {
        _ = try invalidVolume.domainCommand()
    }

    let invalidTempo = RemoteCommand(action: .setTempo, doubleValue: 0)
    #expect(throws: RemoteProtocolError.invalidField("doubleValue")) {
        _ = try invalidTempo.domainCommand()
    }
}


@Test func pairingMessagesRoundTripThroughProtocolV2() throws {
    let sessionID = UUID(
        uuidString:
            "00000000-0000-0000-0000-000000000303"
    )!

    let envelopes = [
        RemoteEnvelope(
            body: .pair(
                RemotePairingRequest(code: "123456")
            )
        ),
        RemoteEnvelope(
            body: .paired(
                RemotePairingAccepted(
                    sessionID: sessionID
                )
            )
        )
    ]

    for envelope in envelopes {
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(
            RemoteEnvelope.self,
            from: data
        )
        #expect(decoded == envelope)
        #expect(
            decoded.protocolVersion
                == GeloRemoteProtocol.currentVersion
        )
    }
}


@Test func remoteCatalogSearchMessagesRoundTrip() throws {
    let requestID = UUID(
        uuidString:
            "44444444-5555-6666-7777-888888888888"
    )!
    let song = LibrarySong(
        id: SongID(rawValue: "song:test"),
        title: "Test Song",
        artist: "Test Artist",
        mediaKind: .midi
    )

    let envelopes = [
        RemoteEnvelope(
            body: .search(
                RemoteSongSearchRequest(
                    requestID: requestID,
                    query: "test",
                    limit: 25
                )
            )
        ),
        RemoteEnvelope(
            body: .searchResults(
                RemoteSongSearchResults(
                    requestID: requestID,
                    songs: [song]
                )
            )
        )
    ]

    for envelope in envelopes {
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(
            RemoteEnvelope.self,
            from: data
        )
        #expect(decoded == envelope)
    }
}

