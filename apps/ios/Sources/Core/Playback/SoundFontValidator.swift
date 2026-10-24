import Foundation

public enum SoundFontValidator {
    private static let maxFileSize: UInt64 = 100 * 1024 * 1024 // 100 MB limit

    public static func validateSoundFontFile(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? UInt64,
              fileSize <= maxFileSize else {
            print("SoundFontValidator: File exceeds max size or attributes unreadable.")
            return false
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            print("SoundFontValidator: Failed to open file handle.")
            return false
        }
        defer { try? handle.close() }

        let headerData = handle.readData(ofLength: 12)
        guard headerData.count == 12 else {
            print("SoundFontValidator: File too small.")
            return false
        }

        let riffString = String(data: headerData.subdata(in: 0..<4), encoding: .ascii)
        let sfbkString = String(data: headerData.subdata(in: 8..<12), encoding: .ascii)

        if riffString == "RIFF" && sfbkString == "sfbk" {
            print("SoundFontValidator: Valid SoundFont (SFBK) header.")
            return true
        } else {
            print("SoundFontValidator: Invalid header RIFF/sfbk.")
            return false
        }
    }
}
