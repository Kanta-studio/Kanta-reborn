import Testing
@testable import GeloKaraokeCore

@Test func youtubeReferenceAcceptsSupportedLinks() {
    for link in [
        "https://youtu.be/dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://m.youtube.com/shorts/dQw4w9WgXcQ",
        "https://youtube.com/embed/dQw4w9WgXcQ"
    ] {
        #expect(YouTubeVideoReference(url: link)?.videoID == "dQw4w9WgXcQ")
    }
}

@Test func youtubeReferenceRejectsUnsafeLinks() {
    for link in [
        "http://youtu.be/dQw4w9WgXcQ",
        "https://youtu.be.evil.com/dQw4w9WgXcQ",
        "https://youtube.com/watch?v=invalid",
        "https://youtube.com/watch?v=dQw4w9WgXcQ&v=dQw4w9WgXcQ",
        "https://user@youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ#fragment"
    ] {
        #expect(YouTubeVideoReference(url: link) == nil)
    }
}
