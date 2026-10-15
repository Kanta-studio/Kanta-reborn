import Testing
@testable import GeloKaraokeCore

@Test func timelineUsesTempoRateAndClampsToDuration() {
    let timeline = PlaybackTimeline(anchorMilliseconds: 1_000, durationMilliseconds: 5_000, rate: 1.5)
    #expect(timeline.position(afterElapsedMilliseconds: 2_000) == 4_000)
    #expect(timeline.position(afterElapsedMilliseconds: 10_000) == 5_000)
}

@Test func timelineSaturatesExtremeElapsedTimeAndNormalizesNonfiniteRate() {
    let extreme = PlaybackTimeline(anchorMilliseconds: 1, rate: 2)
    #expect(extreme.position(afterElapsedMilliseconds: .max) == .max)
    var timeline = PlaybackTimeline(rate: .infinity)
    #expect(timeline.position(afterElapsedMilliseconds: 10) == 10)
    timeline.rate = .nan
    #expect(timeline.position(afterElapsedMilliseconds: 10) == 10)
    timeline.durationMilliseconds = -1
    #expect(timeline.position(afterElapsedMilliseconds: 10) == 0)
}

