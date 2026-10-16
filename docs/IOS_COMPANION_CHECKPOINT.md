# iOS KCP1 Android-host controller

## Implemented scope

PR #31 adds iPhone/iPad controller → Android 0.10 host using the existing KCP1 protocol. CryptoKit performs mutual PSK authentication, direction-separated HKDF and ordered AES-GCM records. Network.framework connects only to explicitly entered private IPv4 addresses on 45731 through the public API. There is no plaintext fallback, DNS/discovery extension, automatic reconnect or cloud service.

Commands are bounded metadata search, distinct singer reservations, reservation cancellation and Play/Pause/Next. Android SessionController/FIFO remains authoritative. Sensor activation, media import/export, microphone/camera capture, effects and full-catalog transfer are absent from the command list. Typed replies enforce request UUID, eight-level JSON depth, strict UTF-8, bounded strings and up to ten distinct songs/reservations before publication.

Only one exchange is allowed at a time. Generation checks fence every network suspension. Explicit disconnect, screen closure and foreground loss revoke the connection and release snapshots/channel state; a lost response is not retried across sessions. Connect/handshake have five-second deadlines, exchanges fifteen seconds, polling five seconds, sessions ten minutes/512 commands. The host's random 128-bit code is entered through SecureField and cleared after submission. Memory release is not a promise of guaranteed key zeroization.

## Evidence

Source 82c337588ef9f81339580ade90dc7845502ca984 passed all 166 Swift package tests in run 38892123483. This includes eight new tests: exact independent Python cryptography vectors; wrong code/proof; tamper/replay/reflection/closed state; record/command bounds; private-address validation; hostile JSON/correlation; disconnect during connection; and the actual Swift Network.framework client exchanging with the unchanged production Java Android protocol over loopback TCP and a synthetic queue. The 158 existing tests remain enabled.

The Java peer compiled with pinned Java 17. Separately, a Python cryptography client authenticated and exchanged Unicode search, distinct repeated reservations, cancellation and Play/Pause with that peer over TCP. This is wire/transport evidence, not an actual Android/iOS physical-device pair.

The later candidate app/UI changes cover app privacy/accessibility/keyboard handling UI walkthrough tests, independent List button targets and owned fullscreen-modal dismissal; package production/test source is unchanged. It adds a pairing-screen walkthrough and rejects a public IPv4 address before opening a connection. Changed-head app/UI compilation, iPhone/iPad execution and unsigned device packaging remain pending. The first runtime trigger captured the earlier revision. Its demo and six-destination menu walkthrough passed, but the starter test's initial automated More tap did not present the menu; the captured accessibility hierarchy remained on the stage. The UI harness now waits for stable rendered More geometry and observed destination presentation, with at most three retries while the stage remains hittable. RootView's action sets presentation to true, so those retries are idempotent. All real starter playback assertions remain. Only artifacts verified against the final revision may be published.

## Open gates

Encrypted iOS hosting is not implemented: recovered Bonjour/PIN iOS hosting is separate, plaintext and explicitly legacy. This client does not upgrade it. Physical two-device networking, output audio, independent protocol security review, forward secrecy and Apple production signing remain open. Current public downloads are unchanged until successful changed-head runtime evidence and original-byte verified packaging.

## Presentation diagnosis

The failed starter-menu interaction also led to a production presentation audit. SingingModalPresenter previously called dismiss whenever presentedViewController was nonnil with fullscreen off. Apple's API may report an ancestor's modal, so this could dismiss an unrelated SwiftUI menu or sheet. It now tracks and dismisses only its own karaoke player. The actual-playback UI test checks menu persistence across redraws and enters/exits Library using the same route on iPhone and iPad. This is a source-confirmed ownership defect; the final runtime run must establish that the repair resolves observed behavior. No claim of a locally replayed iOS simulator is made.

## Takeover checkpoint — October 16, 2026

The last complete iOS runtime workflow attempt, [38895372779](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38895372779), finished red on a prior PR revision: iPhone UI tests failed, and iPad `xcodebuild test-without-building` exceeded the helper's 660-second outer deadline, leaving an incomplete `.xcresult` (the app/UI target had already compiled). Existing screenshots and recordings are diagnostic artifacts, not acceptance or a releasable IPA.

The subsequent branch includes the owned-fullscreen-presenter repair, bounded idempotent More-menu checks, and a runner repair: 1,080-second complete-suite deadline, last-100-log-line failure output, and no attachment export for incomplete result bundles. All four walkthrough tests remain enabled with their original XCTest per-case deadlines. Root `docs/TESTING.md` records the limits. These changes are committed but **not validated by a final-head CI run**; final Swift/UI acceptance, unsigned device archive, checksum-verified download publication and physical pairing remain open. Do not merge or advertise an updated iOS binary on this evidence alone.

## Navigation and pairing input repair — October 16, 2026

Following final-head runtime [38917110001](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38917110001), the iPhone and iPad XCTest walkthroughs still failed although app/UI compilation passed. iPhone attachments showed repeated queries against the pairing address field; active-playback captures showed a transient More menu that did not remain presented. The former confirms the input interaction was unreliable, not a network authentication failure; the latter is a presentation lifecycle failure rather than a karaoke decoder failure.

The candidate source now replaces the transient root confirmation dialog and competing destination sheet with a single state-owned sheet for Menu and destination content. Song playback no longer participates in the menu presentation lifecycle. The encrypted pairing screen moves its input fields above the long instructions, provides a punctuation-capable IPv4 keyboard, and disables Connect until the address is a permitted private IPv4 and the exact 32-character code is hexadecimal. The client retains authoritative duplicate validation before opening a socket. UI coverage rejects public addresses before any connection attempt. No audio engine, queue, saved catalog, remote wire framing or website bytes were modified.

These are committed candidate source repairs; **new-head iPhone and iPad simulator tests and packaging are not yet accepted**. The prior artifact is diagnostic evidence only. Preserve all four UI walkthroughs and do not release an IPA until final-head validation is green.
