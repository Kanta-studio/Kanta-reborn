import Foundation
import GeloKaraokeCore

/// Connection-scoped retry suppression. Active commands remain pinned until completion.
struct RemoteCommandReplayCache: Sendable {
    enum Result: Equatable, Sendable {
        case inFlight
        case succeeded
        case failed(RemoteFailure)
    }

    private let capacity: Int
    private var order: [UUID] = []
    private var results: [UUID: Result] = [:]

    init(capacity: Int = 512) {
        self.capacity = min(4096, max(1, capacity))
    }

    mutating func begin(_ id: UUID) -> Bool {
        guard results[id] == nil else { return false }
        if results.count >= capacity {
            guard let index = order.firstIndex(where: { results[$0] != .inFlight }) else {
                return false
            }
            results.removeValue(forKey: order.remove(at: index))
        }
        order.append(id)
        results[id] = .inFlight
        return true
    }

    func result(for id: UUID) -> Result? {
        results[id]
    }

    mutating func finish(_ id: UUID, result: Result) {
        guard results[id] == .inFlight, result != .inFlight else { return }
        results[id] = result
    }
}
