import Foundation
import GeloKaraokeCore
import Network

@MainActor
final class HostRemoteConnection {
    let id = UUID()

    var isPaired: Bool {
        if case .paired = gate.state {
            return true
        }
        return false
    }

    var onClose: ((UUID) -> Void)?
    var onSnapshot: ((KaraokeSnapshot) -> Void)?

    private let connection: NWConnection
    private let controller: any KaraokeController
    private let catalogSearch:
        (@Sendable (String, Int) async -> [LibrarySong])?
    private let queue: DispatchQueue
    private var gate: RemoteHostSessionGate
    private var decoder = RemoteFrameStreamDecoder()
    private var didClose = false

    init(
        connection: NWConnection,
        controller: any KaraokeController,
        catalogSearch:
            (@Sendable (String, Int) async -> [LibrarySong])?,
        expectedPairingCode: PairingCode,
        queue: DispatchQueue
    ) {
        self.connection = connection
        self.controller = controller
        self.catalogSearch = catalogSearch
        self.queue = queue
        self.gate = RemoteHostSessionGate(
            expectedPairingCode: expectedPairingCode
        )
    }

    deinit {
        connection.cancel()
    }

    func start() {
        connection.stateUpdateHandler = {
            [weak self] state in
            Task { @MainActor [weak self] in
                self?.handle(state: state)
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        guard !didClose else { return }
        gate.close()
        didClose = true
        connection.cancel()
        onClose?(id)
    }

    func sendSnapshot(_ snapshot: KaraokeSnapshot) {
        guard isPaired, !didClose else { return }
        send(.snapshot(snapshot))
    }

    private func handle(state: NWConnection.State) {
        switch state {
        case .ready:
            receiveNext()
        case .failed, .cancelled:
            finish()
        default:
            break
        }
    }

    private func receiveNext() {
        guard !didClose else { return }

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1024
        ) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                await self?.handleReceive(
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
    ) async {
        guard !didClose else { return }

        if let data, !data.isEmpty {
            do {
                let envelopes = try decoder.append(data)
                for envelope in envelopes {
                    await process(envelope)
                    if didClose {
                        return
                    }
                }
            } catch {
                sendFailureAndClose(
                    code: "invalid_frame",
                    message:
                        "The remote session sent an invalid frame."
                )
                return
            }
        }

        if error != nil || isComplete {
            finish()
        } else {
            receiveNext()
        }
    }

    private func process(
        _ envelope: RemoteEnvelope
    ) async {
        let action = gate.handle(envelope.body)

        switch action {
        case let .reply(body):
            send(body)

            if case .paired = body {
                let snapshot = await controller.snapshot()
                send(.snapshot(snapshot))
            }

        case let .execute(command):
            do {
                try await controller.send(command)
                let snapshot = await controller.snapshot()
                onSnapshot?(snapshot)
            } catch {
                send(
                    .failure(
                        RemoteFailure(
                            code: "command_failed",
                            message:
                                "The host could not execute that command."
                        )
                    )
                )
            }

        case let .search(request):
            guard let catalogSearch else {
                send(
                    .failure(
                        RemoteFailure(
                            code: "catalog_unavailable",
                            message:
                                "The host song catalog is unavailable."
                        )
                    )
                )
                return
            }

            let songs = await catalogSearch(
                request.query,
                request.limit
            )
            send(
                .searchResults(
                    RemoteSongSearchResults(
                        requestID: request.requestID,
                        songs: Array(
                            songs.prefix(request.limit)
                        )
                    )
                )
            )

        case let .close(failure):
            send(
                .failure(failure),
                closeAfterSend: true
            )
        }
    }

    private func send(
        _ body: RemoteBody,
        closeAfterSend: Bool = false
    ) {
        guard !didClose else { return }

        do {
            let data = try RemoteFrameCodec.encode(
                RemoteEnvelope(body: body)
            )
            connection.send(
                content: data,
                completion: .contentProcessed {
                    [weak self] error in
                    guard closeAfterSend || error != nil else {
                        return
                    }
                    Task { @MainActor [weak self] in
                        self?.finish()
                    }
                }
            )
        } catch {
            finish()
        }
    }

    private func sendFailureAndClose(
        code: String,
        message: String
    ) {
        send(
            .failure(
                RemoteFailure(
                    code: code,
                    message: message
                )
            ),
            closeAfterSend: true
        )
    }

    private func finish() {
        guard !didClose else { return }
        gate.close()
        didClose = true
        connection.cancel()
        onClose?(id)
    }
}

