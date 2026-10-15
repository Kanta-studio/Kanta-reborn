import Combine
import Foundation
import GeloKaraokeCore
import Network

public enum RemoteHostClientStatus:
    Equatable,
    Sendable
{
    case idle
    case connecting
    case pairing
    case paired(UUID)
    case failed(String)
}

@MainActor
public final class RemoteHostClient: ObservableObject {
    @Published public private(set) var status:
        RemoteHostClientStatus = .idle
    @Published public private(set) var snapshot =
        KaraokeSnapshot()
    @Published public private(set) var lastError: String?
    @Published public private(set) var catalogSongs:
        [LibrarySong] = []
    @Published public private(set) var isSearching = false

    private var latestSearchRequestID: UUID?
    private var connection: NWConnection?
    private var connectionGeneration = UUID()
    private var decoder = RemoteFrameStreamDecoder()
    private let queue = DispatchQueue(
        label: "com.gelo.karaoke.remote.client"
    )

    public init() {}

    deinit {
        connection?.cancel()
    }

    public func connect(
        to host: DiscoveredKaraokeHost,
        pairingCode rawCode: String
    ) {
        guard let pairingCode = PairingCode(rawCode) else {
            status = .failed(
                "Enter the six-digit pairing PIN shown by the host."
            )
            return
        }

        disconnect()
        status = .connecting
        lastError = nil
        decoder = RemoteFrameStreamDecoder()

        let endpoint = NWEndpoint.service(
            name: host.name,
            type: GeloBonjour.serviceType,
            domain: host.domain,
            interface: nil
        )
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let connection = NWConnection(
            to: endpoint,
            using: parameters
        )
        self.connection = connection

        let generation = connectionGeneration
        connection.stateUpdateHandler = {
            [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.connectionGeneration == generation else { return }
                self.handle(
                    state: state,
                    pairingCode: pairingCode
                )
            }
        }
        connection.start(queue: queue)
    }

    public func disconnect() {
        connectionGeneration = UUID()
        connection?.cancel()
        connection = nil
        decoder = RemoteFrameStreamDecoder()
        latestSearchRequestID = nil
        catalogSongs = []
        isSearching = false
        snapshot = KaraokeSnapshot()
        lastError = nil
        status = .idle
    }

    public func send(_ command: KaraokeCommand) {
        guard case .paired = status else {
            lastError = "Pair with the host before sending controls."
            return
        }

        send(
            .command(
                RemoteCommand(command: command)
            )
        )
    }

    public func search(
        _ query: String,
        limit: Int = 100
    ) {
        guard case .paired = status else {
            lastError = "Pair with the host before searching songs."
            return
        }

        let normalized = String(
            query
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .prefix(200)
        )
        let boundedLimit = min(max(limit, 1), 100)
        let requestID = UUID()

        latestSearchRequestID = requestID
        isSearching = true

        send(
            .search(
                RemoteSongSearchRequest(
                    requestID: requestID,
                    query: normalized,
                    limit: boundedLimit
                )
            )
        )
    }

    public func enqueue(_ song: LibrarySong) {
        send(.enqueue(songID: song.id))
    }

    private func handle(
        state: NWConnection.State,
        pairingCode: PairingCode
    ) {
        switch state {
        case .ready:
            status = .pairing
            send(
                .hello(
                    RemoteHello(
                        appVersion: "2",
                        role: .controller
                    )
                )
            )
            send(
                .pair(
                    RemotePairingRequest(
                        code: pairingCode.value
                    )
                )
            )
            receiveNext()

        case let .failed(error):
            fail(error.localizedDescription)

        case .cancelled:
            if case .failed = status {
                break
            }
            disconnect()

        default:
            break
        }
    }

    private func receiveNext() {
        guard let connection else { return }

        let generation = connectionGeneration
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1024
        ) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self, self.connectionGeneration == generation else { return }
                self.handleReceive(
                    data: data,
                    isComplete: isComplete,
                    error: error
                )
            }
        }
    }

    private func handleReceive(
        data: Data?,
        isComplete: Bool,
        error: NWError?
    ) {
        if let data, !data.isEmpty {
            do {
                let envelopes = try decoder.append(data)
                let generation = connectionGeneration
                for envelope in envelopes {
                    handle(envelope.body)
                    guard generation == connectionGeneration else { return }
                }
            } catch {
                fail(
                    "The host sent an invalid remote-control frame."
                )
                return
            }
        }

        if let error {
            fail(error.localizedDescription)
        } else if isComplete {
            if case .failed = status {
                return
            }
            disconnect()
        } else {
            receiveNext()
        }
    }

    private func handle(_ body: RemoteBody) {
        switch body {
        case let .paired(accepted):
            guard status == .pairing else { return }
            status = .paired(accepted.sessionID)
            lastError = nil

        case let .snapshot(snapshot):
            guard case .paired = status else { return }
            self.snapshot = snapshot

        case let .searchResults(results):
            guard results.requestID
                    == latestSearchRequestID else {
                return
            }
            catalogSongs = results.songs
            isSearching = false

        case let .failure(failure):
            lastError = failure.message
            isSearching = false
            if case .paired = status {
                return
            }
            fail(failure.message)

        case .ping:
            send(.pong)

        default:
            break
        }
    }

    private func send(_ body: RemoteBody) {
        guard let connection else { return }

        let generation = connectionGeneration
        do {
            let data = try RemoteFrameCodec.encode(
                RemoteEnvelope(body: body)
            )
            connection.send(
                content: data,
                completion: .contentProcessed {
                    [weak self] error in
                    guard let error else { return }
                    Task { @MainActor [weak self] in
                        guard let self, self.connectionGeneration == generation else { return }
                        self.fail(error.localizedDescription)
                    }
                }
            )
        } catch {
            fail(
                "The remote-control message could not be encoded."
            )
        }
    }

    private func fail(_ message: String) {
        disconnect()
        lastError = message
        isSearching = false
        status = .failed(message)
        connection?.cancel()
        connection = nil
    }
}


