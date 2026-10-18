import Foundation
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

@Test func queueMediaSourceDefaultsToLocalForSavedReservations() throws {
    let song = LibrarySong(id: SongID(rawValue: "local-test"), title: "Sample", mediaKind: .kar)
    let item = QueueItem(song: song)
    let encoded = try JSONEncoder().encode(item)
    let restored = try JSONDecoder().decode(QueueItem.self, from: encoded)
    #expect(restored.source == .local)
    #expect(restored.id == item.id)

    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "source")
    let legacy = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(QueueItem.self, from: legacy)
    #expect(decoded.source == .local)
}

@Test func youtubeReservationSourceKeepsItsIdentity() throws {
    let song = LibrarySong(id: SongID(rawValue: "youtube-metadata"), title: "Online video", mediaKind: .unknown, isPlayable: false)
    let video = try #require(YouTubeVideoReference(url: "https://youtu.be/dQw4w9WgXcQ"))
    let first = QueueItem(song: song, source: .youtube(video))
    let second = QueueItem(song: song, source: .youtube(video))
    #expect(first.id != second.id)
    let restored = try JSONDecoder().decode(QueueItem.self, from: JSONEncoder().encode(first))
    #expect(restored.source == .youtube(video))
}
