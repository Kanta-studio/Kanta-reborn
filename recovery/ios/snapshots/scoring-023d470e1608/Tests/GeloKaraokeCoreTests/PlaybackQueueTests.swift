import Foundation
import Testing
@testable import GeloKaraokeCore

private func song(_ id: String) -> LibrarySong {
    LibrarySong(id: SongID(rawValue: id), title: id, mediaKind: .midi)
}

@Test func queuePreservesOrderAndSupportsRemoval() {
    var queue = PlaybackQueue()
    let first = queue.enqueue(song("one"))
    let second = queue.enqueue(song("two"))

    #expect(queue.items.map(\.song.id.rawValue) == ["one", "two"])
    #expect(queue.remove(id: first.id) == first)
    #expect(queue.items == [second])
}

@Test func queueMoveDoesNotLoseItemWhenDestinationIsMissing() {
    var queue = PlaybackQueue()
    let first = queue.enqueue(song("one"))
    _ = queue.enqueue(song("two"))

    #expect(queue.move(id: first.id, before: UUID()) == false)
    #expect(queue.items.count == 2)
    #expect(Set(queue.items.map(\.song.id.rawValue)) == ["one", "two"])
}

