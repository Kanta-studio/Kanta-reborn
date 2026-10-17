import Foundation

public struct KaraokeLyricItem: Equatable, Sendable {
    public let milliseconds: Int64
    public let text: String

    public init(milliseconds: Int64, text: String) {
        self.milliseconds = max(0, milliseconds)
        self.text = text
    }
}

public struct KaraokeLyricWindow: Equatable, Sendable {
    public let previous: KaraokeLyricItem?
    public let current: KaraokeLyricItem?
    public let next: KaraokeLyricItem?

    public init(
        previous: KaraokeLyricItem? = nil,
        current: KaraokeLyricItem? = nil,
        next: KaraokeLyricItem? = nil
    ) {
        self.previous = previous
        self.current = current
        self.next = next
    }
}

public struct KaraokeLyricSequence: Sendable {
    public let items: [KaraokeLyricItem]

    public init(cues: [KaraokeLyricCue]) {
        items = cues.compactMap(Self.displayItem)
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public func window(
        atMilliseconds position: Int64
    ) -> KaraokeLyricWindow {
        guard !items.isEmpty else {
            return KaraokeLyricWindow()
        }

        let boundedPosition = max(0, position)

        var low = 0
        var high = items.count

        while low < high {
            let mid = (low + high) / 2
            if items[mid].milliseconds <= boundedPosition {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let currentIndex = low - 1

        if currentIndex < 0 {
            return KaraokeLyricWindow(
                next: items[0]
            )
        }

        let previous = currentIndex > 0
            ? items[currentIndex - 1]
            : nil
        let current = items[currentIndex]
        let nextIndex = currentIndex + 1
        let next = nextIndex < items.count
            ? items[nextIndex]
            : nil

        return KaraokeLyricWindow(
            previous: previous,
            current: current,
            next: next
        )
    }

    private static func displayItem(
        from cue: KaraokeLyricCue
    ) -> KaraokeLyricItem? {
        var text = cue.text
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while text.first == "/" || text.first == "\\" {
            text.removeFirst()
            text = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }

        guard !text.isEmpty,
              !text.hasPrefix("@") else {
            return nil
        }

        return KaraokeLyricItem(
            milliseconds: cue.milliseconds,
            text: text
        )
    }
}

