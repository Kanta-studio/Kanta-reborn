import Foundation

public struct PlaybackQueue: Equatable, Sendable {
    public private(set) var items: [QueueItem]

    public init(items: [QueueItem] = []) {
        self.items = items
    }

    @discardableResult
    public mutating func enqueue(_ song: LibrarySong, requestedBy: String? = nil) -> QueueItem {
        let item = QueueItem(song: song, requestedBy: requestedBy)
        items.append(item)
        return item
    }

    public mutating func prepend(_ item: QueueItem) {
        items.insert(item, at: 0)
    }

    @discardableResult
    public mutating func remove(id: UUID) -> QueueItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    @discardableResult
    public mutating func popNext() -> QueueItem? {
        guard !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    public mutating func move(id: UUID, before destinationID: UUID?) -> Bool {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return false }
        let item = items.remove(at: sourceIndex)

        guard let destinationID else {
            items.append(item)
            return true
        }

        guard let destinationIndex = items.firstIndex(where: { $0.id == destinationID }) else {
            items.insert(item, at: min(sourceIndex, items.count))
            return false
        }

        items.insert(item, at: destinationIndex)
        return true
    }
}

