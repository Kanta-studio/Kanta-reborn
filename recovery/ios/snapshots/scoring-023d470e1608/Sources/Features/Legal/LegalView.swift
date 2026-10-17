import SwiftUI

/// Canonical notice for both navigation and the app's Legal & Licenses sheet.
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
                    Text(
                        "KANTA is an independent karaoke player and compatibility tool. " +
                        "It does not supply or license a third-party karaoke catalog."
                    )
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                GeloSectionCard("Bring Your Own Library") {
                    notice(
                        "Only add and use songs, lyrics, SoundFonts, images, videos, and " +
                        "libraries when you hold the necessary rights, have permission, " +
                        "or your use is otherwise permitted by applicable law. Possessing " +
                        "or buying a file does not by itself transfer its copyright."
                    )
                    notice(
                        "You retain any rights you hold in your content. Using KANTA " +
                        "does not transfer those rights to the app's developer or give " +
                        "you additional rights in someone else's content."
                    )
                }

                GeloSectionCard("Playback is not a content license") {
                    notice(
                        "Importing, decoding, copying, or playing a file does not grant " +
                        "permission to redistribute it, show lyrics or images publicly, " +
                        "perform music publicly, stream or broadcast it, or combine it " +
                        "with video. Depending on your use and location, separate " +
                        "permissions or licenses may be required."
                    )
                    notice(
                        "Check the terms for your media and SoundFonts before venue, " +
                        "business, public, or online use. KANTA does not verify your " +
                        "content licenses or obtain those permissions for you."
                    )
                }

                GeloSectionCard("Independent compatibility") {
                    notice(
                        "Third-party names, formats, and trademarks are referenced " +
                        "only when needed to describe compatibility or required notices. " +
                        "KANTA is independent and is not affiliated with, sponsored by, " +
                        "or endorsed by third-party library or media providers. " +
                        "Third-party trademarks and content remain subject to their owners' rights."
                    )
                    notice(
                        "Format support is a technical capability, not proof of lawful " +
                        "access or rights clearance. It does not authorize unauthorized " +
                        "access, circumvention of access restrictions, or infringement. " +
                        "Compatibility varies by file, device, and software version."
                    )
                }

                GeloSectionCard("Privacy: files and microphone") {
                    notice(
                        "KANTA reads libraries from folders you select in Files. " +
                        "Background and SoundFont imports make byte-preserving copies; " +
                        "they do not transcode, resize, or recompress your originals. " +
                        "Legacy playback may create a temporary decoded copy of the " +
                        "selected song on the device. Keep your own backups."
                    )
                    notice(
                        "Optional microphone scoring is off by default. When enabled " +
                        "with microphone permission, KANTA analyzes audio in memory on " +
                        "your device; it does not save microphone recordings or upload " +
                        "microphone audio. Core playback does not require an account " +
                        "with KANTA's developer."
                    )
                }

                GeloSectionCard("Privacy: iCloud and local network") {
                    notice(
                        "If you use iCloud Save, KANTA prepares the settings and media " +
                        "categories you select for your Apple iCloud account. Apple " +
                        "manages transfer and storage; completion of a local copy does " +
                        "not confirm upload. Files providers may also sync selected " +
                        "folders under their own settings and terms. Only back up " +
                        "content you are entitled to copy."
                    )
                    notice(
                        "The optional paired remote exchanges song metadata, playback " +
                        "state, searches, and controls over your local network. The " +
                        "current connection uses a pairing PIN but is not encrypted. " +
                        "Use it only on a network you trust."
                    )
                }

                GeloSectionCard("Privacy: saved data and your choices") {
                    notice(
                        "KANTA saves your preferences, selected-folder access references, " +
                        "and scan metadata such as filenames, paths, sizes, and media " +
                        "types on your device so it can reopen and browse your library. " +
                        "Pitch observations, scores, searches, and playback state are " +
                        "held in memory for the current session. This build has no " +
                        "advertising or analytics SDK and sends no telemetry to a " +
                        "developer-operated service."
                    )
                    notice(
                        "You can turn scoring off in Settings and revoke microphone or " +
                        "local-network access in iOS Settings. Removing a library removes " +
                        "its active saved entry; it does not delete original files, " +
                        "imported copies, or existing iCloud backups. Recovery copies of " +
                        "the library list may remain in app data. Temporary playback " +
                        "files are cleared when the library reloads or closes."
                    )
                    notice(
                        "In iCloud Save, Delete KANTA iCloud Backup removes KANTA's " +
                        "private iCloud Save files and saved KANTA settings. It does " +
                        "not delete the original folders or files you selected in " +
                        "Files. iCloud deletion can take time to propagate across " +
                        "devices, and provider or device backups are managed separately."
                    )
                }

                GeloSectionCard("Policy and support") {
                    Link(
                        "Privacy Policy",
                        destination: URL(
                            string: "https://kanta-public.vercel.app/privacy"
                        )!
                    )
                    Link(
                        "Support",
                        destination: URL(
                            string: "https://kanta-public.vercel.app/support"
                        )!
                    )
                }

                GeloSectionCard("Third-party components and media") {
                    notice(
                        "This build uses Apple-provided frameworks and system libraries, " +
                        "including system zlib and CommonCrypto. It does not bundle a " +
                        "third-party karaoke catalog or SoundFont. User-supplied assets " +
                        "remain subject to their own licenses and attribution requirements."
                    )
                    notice(
                        "Media distributed with KANTA must have documented distribution " +
                        "rights and any required notices. A compatibility check does not " +
                        "certify ownership, licensing, or permission to distribute content."
                    )
                }

                Text(
                    "This notice explains KANTA's content and privacy boundaries. " +
                    "It does not replace the applicable app license, provider terms, " +
                    "or law, and does not limit consumer or other rights that cannot " +
                    "lawfully be excluded."
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

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

