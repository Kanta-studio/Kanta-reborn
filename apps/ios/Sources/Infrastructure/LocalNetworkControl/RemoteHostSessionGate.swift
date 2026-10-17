import Foundation
import GeloKaraokeCore

public enum RemoteHostSessionState:
    Equatable,
    Sendable
{
    case awaitingHello
    case awaitingPair
    case paired(UUID)
    case closed
}

public enum RemoteHostSessionAction:
    Equatable,
    Sendable
{
    case reply(RemoteBody)
    case execute(KaraokeCommand)
    case search(RemoteSongSearchRequest)
    case close(RemoteFailure)
}

public struct RemoteHostSessionGate: Sendable {
    public private(set) var state:
        RemoteHostSessionState = .awaitingHello

    private let expectedPairingCode: PairingCode
    private let sessionID: UUID

    public init(
        expectedPairingCode: PairingCode,
        sessionID: UUID = UUID()
    ) {
        self.expectedPairingCode = expectedPairingCode
        self.sessionID = sessionID
    }

    public mutating func handle(
        _ body: RemoteBody
    ) -> RemoteHostSessionAction {
        switch state {
        case .awaitingHello:
            guard case let .hello(hello) = body,
                  hello.role == .controller else {
                return reject(
                    code: "controller_hello_required",
                    message:
                        "A controller hello is required before pairing."
                )
            }

            state = .awaitingPair
            return .reply(
                .hello(
                    RemoteHello(
                        appVersion: "2",
                        role: .host
                    )
                )
            )

        case .awaitingPair:
            guard case let .pair(request) = body else {
                return reject(
                    code: "pairing_required",
                    message:
                        "Pairing is required before remote control."
                )
            }

            guard request.code == expectedPairingCode.value else {
                return reject(
                    code: "invalid_pairing_code",
                    message: "The pairing PIN is incorrect."
                )
            }

            state = .paired(sessionID)
            return .reply(
                .paired(
                    RemotePairingAccepted(
                        sessionID: sessionID
                    )
                )
            )

        case .paired:
            switch body {
            case let .command(remoteCommand):
                do {
                    return .execute(
                        try remoteCommand.domainCommand()
                    )
                } catch {
                    return .reply(
                        .failure(
                            RemoteFailure(
                                code: "invalid_command",
                                message:
                                    "The remote command is invalid."
                            )
                        )
                    )
                }

            case let .search(request):
                let normalized = request.query.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard normalized.count <= 200,
                      (1...100).contains(request.limit),
                      (0...500_000).contains(request.offset ?? 0) else {
                    return .reply(
                        .failure(
                            RemoteFailure(
                                code: "invalid_search",
                                message:
                                    "The remote catalog search is invalid."
                            )
                        )
                    )
                }

                return .search(
                    RemoteSongSearchRequest(
                        requestID: request.requestID,
                        query: normalized,
                        limit: request.limit,
                        offset: request.offset ?? 0
                    )
                )

            case .ping:
                return .reply(.pong)

            default:
                return .reply(
                    .failure(
                        RemoteFailure(
                            code: "unexpected_message",
                            message:
                                "That message is not valid for a paired session."
                        )
                    )
                )
            }

        case .closed:
            return .close(
                RemoteFailure(
                    code: "session_closed",
                    message: "The remote session is closed."
                )
            )
        }
    }

    public mutating func close() {
        state = .closed
    }

    private mutating func reject(
        code: String,
        message: String
    ) -> RemoteHostSessionAction {
        state = .closed
        return .close(
            RemoteFailure(
                code: code,
                message: message
            )
        )
    }
}

