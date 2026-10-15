import Foundation

/// Turns spoken Filipino/English search commands into a title, artist, or code
/// query without modifying catalog metadata.
public enum KantaSpeechQueryNormalizer {
    public static func normalized(_ transcription: String) -> String {
        let spoken = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return "" }

        let prefixes = [
            "hanapin ang kanta na ", "hanapin yung kantang ",
            "hanapin ang kantang ", "hanapin ang kanta ",
            "hanapin yung kanta ", "hanapin ang awit ",
            "find the song called ", "search for the song ",
            "search for song ", "find the song ",
            "patugtugin ang kanta ", "patugtugin ang ",
            "paki play ang ", "please play the song ",
            "please play ", "play song ",
            "search for ", "find song ",
            "hanapin ang ", "hanapin yung ", "hanapin ",
            "pakihanap ", "search song ", "song title ",
            "title of the song ", "title "
        ]

        var candidate = spoken
        let lowered = spoken.lowercased()
        if let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) {
            candidate = String(spoken.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Spoken numeric song references can be Filipino or English.
        // Never interpret arbitrary titles as codes without an explicit
        // prefix, so "One Two Three" remains a valid song title.
        let codePrefixes = [
            "song code ", "song number ", "code number ",
            "kanta number ", "code ", "numero ", "number ",
            "bilang ", "kodigo "
        ]
        let candidateLower = candidate.lowercased()
        guard let codePrefix = codePrefixes.first(where: {
            candidateLower.hasPrefix($0)
        }) else {
            return candidate.isEmpty ? spoken : candidate
        }
        let spokenCode = String(candidate.dropFirst(codePrefix.count))
        let words = spokenCode.lowercased().split {
            !$0.isLetter && !$0.isNumber
        }
        let numericWords: [String: String] = [
            "zero": "0", "oh": "0", "sero": "0",
            "one": "1", "isa": "1",
            "two": "2", "dalawa": "2",
            "three": "3", "tatlo": "3",
            "four": "4", "apat": "4",
            "five": "5", "lima": "5",
            "six": "6", "anim": "6",
            "seven": "7", "pito": "7",
            "eight": "8", "walo": "8",
            "nine": "9", "siyam": "9"
        ]
        let digits = words.compactMap { word -> String? in
            let token = String(word)
            if token.allSatisfy(\.isNumber) { return token }
            return numericWords[token]
        }

        guard digits.count == words.count, !digits.isEmpty else {
            return candidate
        }
        return digits.joined()
    }
}

