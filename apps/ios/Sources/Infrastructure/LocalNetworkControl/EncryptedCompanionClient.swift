import Combine
import CryptoKit
import Foundation
import Network

/// A foreground-only controller. The paired Android host remains the queue authority.
@MainActor
public final class EncryptedCompanionClient: ObservableObject {
    @Published public private(set) var status = "Not connected"
    @Published public private(set) var paired = false
    @Published public private(set) var busy = false
    @Published public private(set) var snapshot: CompanionSnapshot?
    private var connection: NWConnection?
    private var channel: CompanionProtocol.Channel?
    private var generation = UUID()
    private var exchange = UUID()
    private var pollTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var commands = 0
    private let networkQueue = DispatchQueue(label: "ph.kanta.companion.client")

    public init() {}
    deinit {
        connection?.cancel()
        pollTask?.cancel(); expiryTask?.cancel(); timeoutTask?.cancel()
    }

    public func disconnect() {
        generation = UUID(); exchange = UUID()
        pollTask?.cancel(); pollTask = nil
        expiryTask?.cancel(); expiryTask = nil
        timeoutTask?.cancel(); timeoutTask = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel(); connection = nil; channel = nil
        paired = false; busy = false; commands = 0; snapshot = nil
        status = "Not connected"
    }

    public func connect(address: String, code: String) {
        disconnect()
        let endpointAddress: String
        do {
            endpointAddress = try CompanionProtocol.privateAddress(address)
            _ = try CompanionProtocol.secret(code)
        } catch {
            status = "Enter the host's private IPv4 address and full 32-character code."
            return
        }
        connectToEndpoint(host: NWEndpoint.Host(endpointAddress), port: 45731, code: code)
    }

    // The public entry point validates addresses; loopback endpoints support transport regression tests.
    func connectToEndpoint(host: NWEndpoint.Host, port: NWEndpoint.Port, code: String) {
        disconnect()
        let run = generation
        let connection = NWConnection(host: host, port: port, using: .tcp)
        self.connection = connection
        busy = true; status = "Connecting"
        armTimeout(run: run, seconds: 5)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run else { return }
                switch state {
                case .ready:
                    self.connection?.stateUpdateHandler = nil
                    await self.authenticate(code: code, run: run)
                case .failed, .cancelled:
                    self.fail(run)
                default: break
                }
            }
        }
        connection.start(queue: networkQueue)
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(600)) } catch { return }
            guard let self, self.generation == run else { return }
            self.disconnect(); self.status = "Session expired. Pair again."
        }
    }

    public func send(action: String, argument: String = "", singer: String = "") {
        guard paired, !busy else { return }
        guard commands < 512 else {
            disconnect(); status = "Session command limit reached. Pair again."; return
        }
        let id = UUID()
        let plain: Data
        do { plain = try CompanionProtocol.request(id: id, action: action, argument: argument, singer: singer) }
        catch { status = "The search or singer name is too long."; return }
        busy = true
        commands += 1
        let run = generation
        armTimeout(run: run, seconds: 15)
        Task { [weak self] in
            guard let self else { return }
            do {
                guard var channel = self.channel else { throw CompanionError.closed }
                let record = try channel.seal(plain)
                self.channel = channel
                try await self.write(record, run: run)
                let header = try await self.read(12, run: run)
                let size = try CompanionProtocol.recordLength(header)
                let body = try await self.read(size, run: run)
                guard self.generation == run, var current = self.channel else { throw CompanionError.closed }
                let decoded = try current.open(header + body)
                self.channel = current
                var response = try CompanionProtocol.response(decoded, request: id)
                if action != "search", let old = self.snapshot { response.songs = old.songs }
                self.snapshot = response
                self.timeoutTask?.cancel(); self.timeoutTask = nil
                self.busy = false; self.status = "Connected · encrypted Android host"
            } catch { self.fail(run) }
        }
    }

    private func authenticate(code: String, run: UUID) async {
        do {
            status = "Authenticating"
            armTimeout(run: run, seconds: 5)
            let hello = try await read(36, run: run)
            let nonce = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            let handshake = try CompanionProtocol.Handshake(code: code, hostHello: hello, clientNonce: nonce)
            try await write(handshake.clientHello, run: run)
            let proof = try await read(32, run: run)
            let authenticated = try handshake.authenticate(proof)
            guard generation == run else { throw CompanionError.closed }
            channel = authenticated; paired = true; busy = false
            timeoutTask?.cancel(); timeoutTask = nil
            status = "Connected · encrypted Android host"
            send(action: "snapshot")
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    guard let self, self.generation == run else { return }
                    self.send(action: "snapshot")
                }
            }
        } catch { fail(run) }
    }

    private func read(_ count: Int, run: UUID) async throws -> Data {
        guard generation == run, let connection else { throw CompanionError.closed }
        var accumulated = Data()
        while accumulated.count < count {
            let remaining = count - accumulated.count
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, isComplete, error in
                    guard error == nil, !isComplete, let data, !data.isEmpty else {
                        continuation.resume(throwing: CompanionError.closed)
                        return
                    }
                    continuation.resume(returning: data)
                }
            }
            guard generation == run else { throw CompanionError.closed }
            accumulated.append(chunk)
        }
        return accumulated
    }

    private func write(_ data: Data, run: UUID) async throws {
        guard generation == run, let connection else { throw CompanionError.closed }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if error != nil { continuation.resume(throwing: CompanionError.closed) }
                else { continuation.resume() }
            })
        }
        guard generation == run else { throw CompanionError.closed }
    }

    private func armTimeout(run: UUID, seconds: Int) {
        timeoutTask?.cancel()
        let ticket = UUID(); exchange = ticket
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, self.generation == run, self.exchange == ticket else { return }
            self.fail(run)
        }
    }
    private func fail(_ run: UUID) {
        guard generation == run else { return }
        disconnect()
        status = "Disconnected or pairing rejected. Check the code and shared Wi-Fi, then pair again."
    }
}
