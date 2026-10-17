import SwiftUI

/// The same customer-facing Legal & Privacy screen is used by navigation and
/// the LegalDisclosureView sheet. Technical release policy lives in Docs/.
struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(KantaTerminology.displayName)
                        .font(.largeTitle.bold())
                        .accessibilityLabel(KantaTerminology.appName)
                    Text("Your music. Your stage.")
                        .font(.headline)
                    notice(
                        "KANTA is a karaoke player for music you add yourself. " +
                        "Here are the important rules and privacy choices in plain language."
                    )
                }
                .padding(.vertical, 8)

                GeloSectionCard("Your songs belong to you") {
                    notice(
                        "Choose songs, lyrics, pictures, videos, and instrument sounds " +
                        "that you own or have permission to use. KANTA does not sell " +
                        "or provide a library of licensed third-party songs."
                    )
                    notice(
                        "You keep any rights you already have in your files. " +
                        "Playing a file in KANTA does not give you extra permission " +
                        "to share it, stream it, or use it in a public performance."
                    )
                }

                GeloSectionCard("KANTA's original starter songs") {
                    notice(
                        "KANTA includes three short original demonstration songs: " +
                        "Morning Light, Sing Together and Starlight Echo. " +
                        "A simple generated tone lets you try these samples offline."
                    )
                    notice(
                        "They are not licensed third-party recordings or a commercial " +
                        "song catalog. Removing or restoring one affects only KANTA's " +
                        "managed demo copy, never your own imported music or SoundFonts."
                    )
                }

                GeloSectionCard("Singing in public or at a business") {
                    notice(
                        "Parties, businesses, events, live streams, and public performances " +
                        "may require separate music permissions. Lyrics, artwork, and videos " +
                        "may have their own rules too. Check before you use someone else's " +
                        "content in public. KANTA cannot arrange those licenses for you."
                    )
                }

                GeloSectionCard("Other karaoke files and services") {
                    notice(
                        "KANTA can read some file types used by other karaoke programs, " +
                        "but compatibility is not a promise that every file will work " +
                        "or that you have permission to use it. Please respect " +
                        "copyright, provider terms, and access restrictions."
                    )
                    notice(
                        "KANTA is independent. Mentioning another product or file format " +
                        "does not mean its owner sponsors or approves KANTA. " +
                        "Brand names and third-party content belong to their owners."
                    )
                }

                GeloSectionCard("Your library and saved songs") {
                    notice(
                        "KANTA reads folders you select in Apple's Files app. It can save " +
                        "your song titles, artist names, search list, Favorites, playlists, " +
                        "and settings on your device. It may make temporary playback copies. " +
                        "Your original folders stay under your control."
                    )
                    notice(
                        "Removing a library from KANTA does not delete the original songs. " +
                        "Keep a backup of files that matter to you."
                    )
                }

                GeloSectionCard("Live camera background") {
                    notice(
                        "Camera BGV is optional and starts off. With camera permission, " +
                        "your front camera appears behind the lyrics on this device. " +
                        "KANTA does not record, save, upload or back up camera video, " +
                        "and Camera BGV does not capture microphone audio. Tap Stop " +
                        "camera to restore your background. Capture stops when the " +
                        "app goes into the background."
                    )
                }

                GeloSectionCard("Microphone and voice search") {
                    notice(
                        "Singing scores and vocal sound effects are optional. KANTA " +
                        "processes microphone sound on your device and does not save " +
                        "or upload recordings of your singing. Live mic output starts " +
                        "off and needs compatible audio equipment."
                    )
                    notice(
                        "Optional Filipino/Taglish voice search downloads a language pack " +
                        "from an outside provider. A short recording is used on your " +
                        "device to recognize a search and then deleted. The separate " +
                        "English voice search uses Apple's speech service, which may " +
                        "process your voice online. Voice search never plays a song for you."
                    )
                }

                GeloSectionCard("Private Songbook and sharing") {
                    notice(
                        "A private website Songbook needs both an exported file and " +
                        "the code from your phone. KANTA's website does not upload " +
                        "your song list. Someone with both the file and code can open it, " +
                        "and the code does not expire on its own. Downloaded song lists " +
                        "and printed copies are not encrypted."
                    )
                }

                GeloSectionCard("Companion Remote and iCloud") {
                    notice(
                        "The legacy iPhone Companion Remote uses a PIN and plaintext local Wi-Fi. " +
                        "The separate encrypted companion can control Android 0.10 hosts using " +
                        "the full 32-character code. Both share bounded song and queue metadata; " +
                        "neither shares media or sensor recordings. The encrypted connection stops " +
                        "when you leave its screen or the foreground and has no automatic reconnect. " +
                        "Use a trusted network. Physical cross-device testing and independent " +
                        "security review remain pending; encrypted iPhone hosting is not included."
                    )
                    notice(
                        "If you choose iCloud Save, KANTA prepares selected app data " +
                        "for your Apple iCloud account. Apple handles uploads and storage. " +
                        "Deleting a KANTA iCloud backup does not delete your original " +
                        "song folders or unrelated device backups."
                    )
                }

                GeloSectionCard("Open-source vocal effects") {
                    notice(
                        "KANTA's optional experimental vocal tuner includes " +
                        "SoundpipeAudioKit PitchCorrect, built from permissively " +
                        "licensed open-source audio software. SoundpipeAudioKit, " +
                        "AudioKit, AudioKitEX and Tonic use MIT licenses; KissFFT " +
                        "uses the compatible BSD 3-Clause license. The commercial " +
                        "Auto-Tune product is not included."
                    )
                    DisclosureGroup("Read full third-party software notices") {
                        Text(audioSoftwareNotices)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Link(
                        "Audio connection and Soundcard setup guide",
                        destination: URL(string: "https://kanta-public.vercel.app/guide")!
                    )
                }

                GeloSectionCard("Optional diagnostic reports") {
                    notice(
                        "Local diagnostic recording is off by default. If you " +
                        "choose to enable it in Settings, KANTA retains up to " +
                        "200 technical event codes for seven days in protected, " +
                        "backup-excluded device storage. It does not log singing " +
                        "audio, song titles, names, file paths, codes, or raw errors."
                    )
                    notice(
                        "You can inspect and share a technical support report " +
                        "only after choosing Prepare and Share yourself. " +
                        "Recipients may retain anything you send. Disabling " +
                        "diagnostics or choosing Erase removes local history, " +
                        "but not earlier shared copies. Full iOS crash reports " +
                        "are separate and may contain other personal information."
                    )
                }

                GeloSectionCard("Your privacy choices") {
                    notice(
                        "You can turn off scoring and voice search, change microphone " +
                        "or local-network permissions in iPhone or iPad Settings, " +
                        "remove your language pack, manage your saved song lists, " +
                        "and remove library entries. This app currently has no " +
                        "advertising or user-tracking software."
                    )
                    notice(
                        "Visiting the KANTA website sends normal web requests " +
                        "to its hosting provider. If you choose to send TestFlight " +
                        "feedback, Apple may share that feedback with the developer."
                    )
                }

                GeloSectionCard("Policies and support") {
                    Link(
                        "Read the full Privacy Policy",
                        destination: URL(string: "https://kanta-public.vercel.app/privacy")!
                    )
                    Link(
                        "Read Legal & Content Use",
                        destination: URL(string: "https://kanta-public.vercel.app/legal")!
                    )
                    Link(
                        "Get KANTA support",
                        destination: URL(string: "https://kanta-public.vercel.app/support")!
                    )
                }

                Text(
                    "These notices explain how KANTA works and how you may use " +
                    "your own content. They do not remove legal consumer rights " +
                    "or replace permissions required by copyright law."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(GeloVisualStyle.pageBackground)
        .navigationTitle("Legal & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var audioSoftwareNotices: String {
        guard let url = Bundle.main.url(
            forResource: "THIRD_PARTY_AUDIO_NOTICES",
            withExtension: "txt",
            subdirectory: "Licenses"
        ), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Audio software license resource unavailable."
        }
        return text
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

