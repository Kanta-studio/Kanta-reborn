# Codebase context packet

## Current source and evidence boundary — October 24, 2026

Canonical repository: [usermalik20-del/Kanta-reborn](https://github.com/usermalik20-del/Kanta-reborn). The requested [kanta-gelo/Kanta-reborn](https://github.com/kanta-gelo/Kanta-reborn) path resolves to this repository. Main is `227b03defb82b7baa35f37b25c53f5120f05e988`, a documentation-only context update; the latest product-code commit on main is [`afd83e5`](https://github.com/usermalik20-del/Kanta-reborn/commit/afd83e52530811679bda3730945b7dd03f421bd8). Reconstruction [#40064491977](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40064491977), website validation [#40064491975](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40064491975), and unsigned iOS build [#40064491908](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40064491908) passed on `afd83e5`; production deployment [#40065675075](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065675075) succeeded on `227b03d`. The documentation-only main commit has no full source-validation run of its own.

## Stack and module boundaries

- **iOS:** Swift tools 6.2, iOS 17 minimum, macOS 14 package test support. The app project is generated with XcodeGen from `apps/ios/project.yml`. SwiftPM modules include `GeloKaraokeCore`, `LibraryStorage`, `AVFoundationPlayback`, `AVFoundationMIDIPlayback`, `LocalNetworkControl`, and `MicrophoneScoring`. Pinned dependencies include AudioKit 5.7.2, SoundpipeAudioKit 5.7.4, and ArgmaxSpeech 1.1.0. The app uses SwiftUI for navigation/Host UI and UIKit for the owned fullscreen player.
- **Android:** Java 17, AGP 8.13.2, Gradle 8.13 wrapper, compile/target SDK 36, minSdk 26, NDK 27.2.12479018, CMake 3.22.1. Native Android Views are used; CameraX 1.5.3 provides camera preview. The reconstructed application ID is `ph.kanta.reborn`; original Android signing identity was not recovered.
- **Domain ownership:** iOS `LocalKaraokeController` is the authoritative actor for local playback and FIFO reservations. Android `SessionController` owns the single session/FIFO and delegates bounded app-private library operations to `LibraryRepository`. Views project controller state; they must not create alternate queues or playback owners.

## Storage, search and media

- **iOS:** `LibraryStorage` provides metadata/catalog persistence using SQLite. User-selected media remains byte-preserved and app-private copies are used where required. MIDI/KAR lyric timing and playback preparation belong to the existing controller/engine path; a metadata-only catalog entry is not proof of playable media.
- **Android:** `LibraryRepository` maintains app-private media, catalog metadata, saved sets and starter-removal state; atomic state persistence uses Android `AtomicFile`. Folder imports run on a dedicated worker with bounds/cancellation. The core accepts supported MIDI/KAR, SF2 and MP3/WAV inputs under explicit validation limits.
- No user library, microphone recording, signing material or commercial songbook belongs in Git or the public site.

## Audio and network boundaries

- **iOS audio:** AVFoundation owns local audio/MIDI playback; the optional vocal monitoring/correction path uses the existing microphone engine with AudioKit/Soundpipe integration. The dry scoring tap remains separate. **FluidSynth is the chosen cross-platform synthesis direction, not proof of current integration**; the actual platform engines still differ.
- **Android audio:** MIDI/SF2 synthesis uses the bundled TinySoundFont native library via JNI/NDK; MP3/WAV use the platform media path. Monitor capture/output and karaoke synthesis are separate. Physical audio quality, feedback, scoring calibration and latency remain device-acceptance items.
- **Remote:** Android's KCP1 host uses high-entropy 32-hex pairing codes and bounded AES-GCM records. The reconstructed iOS encrypted companion client is a separate path; the older Bonjour/PIN host remains a distinct plaintext legacy protocol. Do not claim cross-platform physical interoperability or independent security audit without the dedicated tests and device evidence.
- **Performance evidence:** the source uses actors/executors for serialized playback and I/O, but this packet contains no new measured latency or memory benchmark.

## Current iOS presentation blocker and candidate repair

PR [#64](https://github.com/usermalik20-del/Kanta-reborn/pull/64) is the active candidate. Parent source [`5865e14`](https://github.com/usermalik20-del/Kanta-reborn/commit/5865e142da2bb6fc8dbb528ed79cb3dc0fd7cf97) passed reconstruction [#40065088592](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088592), unsigned artifact build [#40065088603](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088603), download contract tests [#40065088602](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088602), and focused iPhone smoke [#40065088607](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088607). Full walkthrough [#40065088612](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088612) passed iPhone but failed iPad in three tests because `stage.keypad.0` never appeared; the retained hierarchy shows the Host stage and Search button without a presented Stage sheet.

The prior Host-sheet consolidation removed the duplicate embedded sheet but left RootView's navigation sheet attached to the ancestor NavigationStack that contains HostView. This commit moves the root navigation sheet to a sibling background anchor and extends the source-contract guard. That source diagnosis is a hypothesis until runtime validation passes. No retries, fixed sleeps or weakened UI assertions are introduced. Reconstruction and the complete iPhone/iPad walkthrough must pass on the resulting exact candidate SHA before merge or release acceptance.

## Artifact and release state

Candidate unsigned artifact [#12548708773](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40065088603/artifacts/12548708773) belongs to parent SHA `5865e14`, is 24,925,131 bytes, and has SHA-256 `953ecf394aab2ef050fa302ae2e47483cc6176dcd74f3973fc91e80faa7e129c`. It expires October 31, 2026 at 05:12 UTC. It is an unsigned personal-signing input, not a directly installable release. Exact-SHA packaging requires successful reconstruction, unsigned iOS archive, and full iPhone/iPad walkthrough evidence for one accepted main SHA; PR checks do not publish packages. No signed iOS release or published GitHub Release is currently verified.
