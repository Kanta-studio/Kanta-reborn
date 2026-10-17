import Testing
@testable import GeloKaraokeCore

@Test func lyricSequenceNormalizesKARMarkersAndMetadata() {
    let sequence = KaraokeLyricSequence(
        cues: [
            cue(0, "@TTitle"),
            cue(100, "/Hello"),
            cue(200, "\\world"),
            cue(300, "   "),
            cue(400, "again")
        ]
    )

    #expect(
        sequence.items
            == [
                KaraokeLyricItem(
                    milliseconds: 100,
                    text: "Hello"
                ),
                KaraokeLyricItem(
                    milliseconds: 200,
                    text: "world"
                ),
                KaraokeLyricItem(
                    milliseconds: 400,
                    text: "again"
                )
            ]
    )
}

@Test func lyricSequenceResolvesPlaybackWindow() {
    let sequence = KaraokeLyricSequence(
        cues: [
            cue(100, "one"),
            cue(250, "two"),
            cue(500, "three")
        ]
    )

    #expect(
        sequence.window(atMilliseconds: 50)
            == KaraokeLyricWindow(
                next: KaraokeLyricItem(
                    milliseconds: 100,
                    text: "one"
                )
            )
    )

    #expect(
        sequence.window(atMilliseconds: 250)
            == KaraokeLyricWindow(
                previous: KaraokeLyricItem(
                    milliseconds: 100,
                    text: "one"
                ),
                current: KaraokeLyricItem(
                    milliseconds: 250,
                    text: "two"
                ),
                next: KaraokeLyricItem(
                    milliseconds: 500,
                    text: "three"
                )
            )
    )

    #expect(
        sequence.window(atMilliseconds: 999)
            == KaraokeLyricWindow(
                previous: KaraokeLyricItem(
                    milliseconds: 250,
                    text: "two"
                ),
                current: KaraokeLyricItem(
                    milliseconds: 500,
                    text: "three"
                )
            )
    )
}

private func cue(
    _ milliseconds: Int64,
    _ text: String
) -> KaraokeLyricCue {
    KaraokeLyricCue(
        trackIndex: 0,
        eventIndex: Int(milliseconds),
        absoluteTicks: UInt64(max(0, milliseconds)),
        milliseconds: milliseconds,
        text: text
    )
}
