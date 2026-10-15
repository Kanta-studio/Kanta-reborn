import Testing
@testable import GeloKaraokeCore

@Test func lyricPagePreservesTimedSyllablesAndLineBreaks() {
    let sequence = KaraokeLyricPageSequence(cues: [
        pageCue(0, "@TMetadata"), pageCue(100, "/Peo"),
        pageCue(200, "ple "), pageCue(400, "sing"),
        pageCue(800, "\\Together"), pageCue(1_200, "/Again")
    ])
    #expect(sequence.lines.map(\.text) == ["People sing", "Together", "Again"])
    let page = sequence.page(atMilliseconds: 250)
    #expect(page.lines.count == 3)
    #expect(page.lines[0].fragments.filter {
        $0.milliseconds <= page.positionMilliseconds
    }.map(\.text).joined() == "People ")
    #expect(page.lines[0].fragments.last?.milliseconds == 400)
}

@Test func lyricPageUsesStablePagesAndRewindsOnSeek() {
    let sequence = KaraokeLyricPageSequence(cues: [
        pageCue(100, "one"), pageCue(200, "two"), pageCue(300, "three"),
        pageCue(400, "four"), pageCue(500, "five"), pageCue(600, "six")
    ])
    #expect(sequence.page(atMilliseconds: 399).lines.map(\.text) == ["one", "two", "three"])
    #expect(sequence.page(atMilliseconds: 400).lines.map(\.text) == ["four", "five", "six"])
    #expect(sequence.page(atMilliseconds: 150).lines.map(\.text) == ["one", "two", "three"])
    #expect(sequence.page(atMilliseconds: 150) == sequence.page(atMilliseconds: 150))
    #expect(sequence.page(atMilliseconds: 250, lineCount: 2).lines.count == 2)
}

@Test func lyricPagePreviewsBeforeFirstCueWithoutEarlyHighlight() {
    let page = KaraokeLyricPageSequence(cues: [pageCue(1_000, "hello")])
        .page(atMilliseconds: -500)
    #expect(page.positionMilliseconds == 0)
    #expect(page.lines.first?.fragments.first?.milliseconds == 1_000)
}

@Test func lyricPageHandlesUnicodeNewlinesAndBlankMarkers() {
    let sequence = KaraokeLyricPageSequence(cues: [
        pageCue(100, "/Kumusta "), pageCue(200, "ka 🇵🇭"),
        pageCue(300, "\r\n"), pageCue(400, "Awit"),
        pageCue(500, "/"), pageCue(600, "   ")
    ])
    #expect(sequence.lines.map(\.text) == ["Kumusta ka 🇵🇭", "Awit"])
}

@Test func lyricPageSortsCueTimesWithoutReorderingEqualTimeFragments() {
    let sequence = KaraokeLyricPageSequence(cues: [
        pageCue(300, "/last"), pageCue(100, "/first "), pageCue(100, "part")
    ])
    #expect(sequence.lines.map(\.text) == ["first part", "last"])
    #expect(sequence.page(atMilliseconds: 100).lines[0].fragments.count == 2)
}

@Test func lyricPageEmptyAndMetadataOnlyStayEmpty() {
    #expect(KaraokeLyricPageSequence(cues: []).page(atMilliseconds: 500).lines.isEmpty)
    #expect(KaraokeLyricPageSequence(cues: [pageCue(0, "@Ttitle")]).lines.isEmpty)
}

private func pageCue(_ time: Int64, _ text: String) -> KaraokeLyricCue {
    KaraokeLyricCue(trackIndex: 0, eventIndex: 0, absoluteTicks: 0,
                   milliseconds: time, text: text)
}
