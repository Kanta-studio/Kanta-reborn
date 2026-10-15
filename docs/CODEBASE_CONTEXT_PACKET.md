# Codebase Context Packet — KANTA Reborn

Snapshot: 2026-10-15, working tree on `recovery/platform-separated-import`; post-import reconstruction is in progress and is not yet a published release. The last published foundation is commit `332eb5bdad133c2240637276b0c252761dfc0574` / draft PR #1.

## Android stack

- Root: `apps/android/`; AGP **8.13.2**, compileSdk/targetSdk **36**, minSdk **26**, Java **17** source/target. Gradle 8.13 wrapper is included and its JAR/distribution hashes are verified.
- Native Android Views built in Java; no Compose, Hilt, Koin, Room, Kotlin or external audio dependency has been added.
- `LibraryRepository.java`: app-private media copies plus versioned JSON metadata committed through `AtomicFile`. This is the current implementation, not a SQL/Room schema.
- Song fields: stable ID, title, artist, code, safe app-private filename, first-party starter flag. Content SHA-256 identifies imported files; starter IDs are allowlisted.
- Queue fields: distinct reservation UUID, song ID, optional singer. Saved sets contain ID, name and ordered song IDs. Starter removals are persistent tombstones.
- Search currently uses all query terms against cached normalized title/artist/code in the `Song.matchesTerms` domain helper. It is not FTS. Search runs off-main over immutable snapshots; results and reservation rows are paginated.

## Playback and timing

- `SessionController.java` is the one app-lifetime Android owner, composed by `KantaApplication`.
- All `MediaPlayer` instances and callbacks are accessed on the main Looper. File import, hashing, catalog persistence, image decoding and MIDI parsing use one serial IO executor.
- Android's built-in MIDI decoder handles `.mid` and byte-identical `.kar` copies stored with `.mid` filenames. MP3/WAV also use MediaPlayer. A custom SF2 renderer has not been reconstructed; importing a SoundFont must not be advertised as changing the instrument bank.
- `core/MidiLyrics.java` parses SMF format 0/1, merges tempo events across tracks and derives lyric-line start times. SMPTE/format 2 and malformed/unbounded inputs fail explicitly.
- Prepare-before-commit keeps reservations in Up Next until media preparation succeeds. A generation token suppresses stale prepare callbacks; queue entries have distinct identities even for repeated songs.
- Audio focus and unplug handling pause playback. Front-camera, microphone scoring/DSP, video stages and hardware audio acceptance are not yet reconstructed on Android.

## Network / remote

The recovered iOS baseline contains optional PIN-authorized plaintext LAN control. Pagination and singer reservation interfaces are being reconciled with newer UI. It must not be described as encrypted. Android companion transport has not been reconstructed; no Android server/socket implementation exists yet. The website's newer encrypted-Android/cross-platform claims are requirements/evidence, not this reconstruction's shipping capabilities.

## iOS recovery

`apps/ios/` retains SwiftUI/AVFoundation architecture, SwiftPM modules and XcodeGen configuration. The original stage UI snapshot has been supplemented with 78 individually selected missing paths, including 60 Swift files, from the historical snapshots. No existing baseline file was overwritten during that restoration.

Missing Favorites storage, SQLite catalog, CSV/private Songbook export, SFX engine and C compression bridge are newly reconstructed code, not recovered originals. Their Swift compile/runtime acceptance is pending. The AES-GCM Songbook envelope follows the captured browser reader; new tests cover durable Save retries, failed writes, literal/Unicode search, CSV quoting and encryption round-trip.

## Current risks and bottlenecks

No device performance measurements exist for the reconstruction. Source-review risks include linear Android catalog search, whole MIDI reads bounded to 16 MiB, one IO executor shared by imports and ancillary work, JSON catalog rewrite cost, and platform/lifecycle behavior requiring device checks. These are potential bottlenecks, not measured lag. Prioritize playback/control responsiveness before visuals or background jobs.

## Checks so far

- 50 recovered Python release-tooling tests passed.
- Four starter-generation/fixture tests and the starter resource guard passed.
- C bridge compiled with warnings treated as errors for its Linux unsupported-codec branch; Apple CommonCrypto path still requires Apple compilation.
- All nine runtime Java files compiled against official Android API 36 references and Java 17 host libraries. Forty-six core regression checks passed. Cloud run 38742284862 also passed Gradle APK/lint and captured browser interoperability; device launch/runtime acceptance remain pending.
- Swift compiler/Xcode are not present on this server. New Swift tests have been written but not executed.
- Two consolidated cloud runs have executed. Android passed on the second run; iOS test compilation found a missing replay-cache type, now reconstructed pending fresh validation. No merge, signing or deployment.
