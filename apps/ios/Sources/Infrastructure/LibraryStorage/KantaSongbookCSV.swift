import Foundation
import GeloKaraokeCore

public enum KantaSongbookCSV {
    /// Metadata only; quoting also neutralizes spreadsheet formula prefixes.
    public static func encode(_ songs: [LibrarySong]) -> Data {
        func cell(_ value: String) -> String {
            let dangerous = value.trimmingCharacters(in: .whitespacesAndNewlines).first
                .map { "=+-@\t\r".contains($0) } ?? false
            let safe = (dangerous ? "'" : "") + value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var rows = ["KANTA Code,Song Title,Artist,Availability"]
        rows += songs.map { song in
            [song.code ?? "", song.title, song.artist ?? "",
             song.isPlayable ? "Playable" : "Catalog only"].map(cell).joined(separator: ",")
        }
        return Data((rows.joined(separator: "\r\n") + "\r\n").utf8)
    }
}
