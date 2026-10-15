import Foundation

/// A source-timed fragment. No estimated word durations are invented.
public struct KaraokeLyricFragment: Equatable, Sendable {
    public let milliseconds: Int64
    public let text: String

    public init(milliseconds: Int64, text: String) {
        self.milliseconds = max(0, milliseconds)
        self.text = text
    }
}

public struct KaraokeLyricLine: Equatable, Sendable {
    public let fragments: [KaraokeLyricFragment]
    public var text: String { fragments.map(\.text).joined() }
    public var milliseconds: Int64 { fragments.first?.milliseconds ?? 0 }
}

public struct KaraokeLyricPage: Equatable, Sendable {
    public let lines: [KaraokeLyricLine]
    public let positionMilliseconds: Int64

    public init(lines: [KaraokeLyricLine] = [], positionMilliseconds: Int64 = 0) {
        self.lines = lines
        self.positionMilliseconds = max(0, positionMilliseconds)
    }
}

/// Groups KAR fragments by explicit source line markers. Unmarked cues retain
/// line-level timing. Pages use the playback position, never a separate timer.
public struct KaraokeLyricPageSequence: Sendable {
    public let lines: [KaraokeLyricLine]

    public init(cues: [KaraokeLyricCue]) {
        let ordered = cues.enumerated().sorted {
            if $0.element.milliseconds == $1.element.milliseconds {
                return $0.offset < $1.offset
            }
            return $0.element.milliseconds < $1.element.milliseconds
        }.map(\.element).filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("@")
        }
        let marked = ordered.contains {
            $0.text.contains("/") || $0.text.contains("\\")
                || $0.text.contains("\n") || $0.text.contains("\r")
        }
        var result: [KaraokeLyricLine] = []
        var fragments: [KaraokeLyricFragment] = []
        func flush() {
            if !fragments.map(\.text).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(KaraokeLyricLine(fragments: fragments))
            }
            fragments.removeAll(keepingCapacity: true)
        }
        for cue in ordered {
            if !marked { flush() }
            var text = ""
            func appendFragment() {
                if !text.isEmpty {
                    fragments.append(KaraokeLyricFragment(
                        milliseconds: cue.milliseconds, text: text
                    ))
                    text = ""
                }
            }
            for character in cue.text {
                if character == "/" || character == "\\"
                    || character == "\n" || character == "\r" || character == "\r\n" {
                    appendFragment()
                    flush()
                } else {
                    text.append(character)
                }
            }
            appendFragment()
        }
        flush()
        lines = result
    }

    public func page(atMilliseconds position: Int64, lineCount: Int = 3) -> KaraokeLyricPage {
        guard !lines.isEmpty else { return KaraokeLyricPage() }
        let count = min(max(lineCount, 2), 3)
        let bounded = max(0, position)
        var low = 0
        var high = lines.count
        while low < high {
            let middle = (low + high) / 2
            if lines[middle].milliseconds <= bounded { low = middle + 1 }
            else { high = middle }
        }
        let active = max(0, low - 1)
        let start = (active / count) * count
        return KaraokeLyricPage(
            lines: Array(lines[start..<min(start + count, lines.count)]),
            positionMilliseconds: bounded
        )
    }
}
