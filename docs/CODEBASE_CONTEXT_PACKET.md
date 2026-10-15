# Codebase Context Packet — KANTA Reborn

Snapshot: 2026-10-15, PR #1 merged at `1720a54f31123f2ef59d41383dc41ef06c5855d5`; current Android media work on `feature/native-media-parity` (uncommitted source). Source, tests and workflow are published; this is not a signed or device-accepted release.

## Android stack

- Root: `apps/android/`; AGP **8.13.2**, compileSdk/targetSdk **36**, minSdk **26**, Java **17** source/target. Gradle 8.13 wrapper is included and its JAR/distribution hashes are verified.
- Native Android Views built in Java; no Compose, Hilt, Koin, Room or Kotlin. MIDI synthesis uses revision-pinned MIT TinySoundFont via C11/JNI, NDK 27.2.12479018 and CMake 3.22.1.
- `LibraryRepository.java`: app-private media copies plus versioned JSON metadata committed through `AtomicFile`. This is the current implementation, not a SQL/Room schema.
- Song fields: stable ID, title, artist, code, safe app-private filename, first-party starter flag. Content SHA-256 identifies imported files; starter IDs are allowlisted.
- Queue fields: distinct reservation UUID, song ID, optional singer. Saved sets contain ID, name and ordered song IDs. Starter removals are persistent tombstones.
- Search currently uses all query terms against cached normalized title/artist/code in the `Song.matchesTerms` domain helper. It is not FTS. Search runs off-main over immutable snapshots; results and reservation rows are paginated.

## Playback and timing

- `SessionController.java` is the one app-lifetime Android owner, composed by `KantaApplication`.
- All `MediaPlayer` instances and callbacks are accessed on the main Looper. File import, hashing, catalog persistence and image decoding use a serial IO executor. A separate preparation executor reads MIDI, and a folder worker scans selected SAF trees. These do not block Next behind a bulk import.
- MIDI/KAR channel events feed a dedicated worker owning TinySoundFont and streaming PCM_FLOAT AudioTrack. Imported SF2 replaces the bank for subsequent songs; original bytes are preserved. MP3/WAV use main-Looper MediaPlayer. Volume, tempo (0.5–2) and pitch (±12 semitones) share controller settings. MIDI drums are not transposed; file-audio behavior depends on platform PlaybackParams support.
- `core/MidiLyrics.java` parses SMF format 0/1, merges tempo events across tracks and derives lyric-line start times, typed channel messages and end-of-track duration. Limits: 16 MiB, 256 tracks, 250,000 events and six hours. The audible clock maps output frames across buffered tempo changes instead of showing render-ahead time. SMPTE/format 2 and malformed/unbounded inputs fail explicitly.
- Prepare-before-commit keeps reservations in Up Next until the backend acknowledges actual start. A generation token suppresses stale prepare callbacks; queue entries have distinct identities even for repeated songs.
- Audio focus and unplug handling pause playback. Front-camera, microphone scoring/DSP, video stages and hardware audio acceptance are not yet reconstructed on Android.

## Network / remote

The recovered iOS baseline contains optional PIN-authorized plaintext LAN control. Pagination and singer reservation interfaces are reconciled with the newer UI. Command retries use a bounded, connection-scoped replay cache that pins in-flight requests; reconnect/durable replay remains open. It must not be described as encrypted. Android companion transport has not been reconstructed; no Android server/socket implementation exists yet. The website's newer encrypted-Android/cross-platform claims are requirements/evidence, not this reconstruction's shipping capabilities.

## iOS recovery

`apps/ios/` retains SwiftUI/AVFoundation architecture, SwiftPM modules and XcodeGen configuration. The original stage UI snapshot has been supplemented with 78 individually selected missing paths, including 60 Swift files, from the historical snapshots. No existing baseline file was overwritten during that restoration.

Missing Favorites storage, SQLite catalog, CSV/private Songbook export, SFX engine and C compression bridge are newly reconstructed code, not recovered originals. All Swift package/test targets compile in hosted validation. The full unsigned Release simulator app build passed run 38748040876; all 158 package tests passed on head 56c9fedbb70b79ebc350e4678d5620554d53c983. Xcode 26.2 / Swift 6.2 is selected explicitly. The AES-GCM Songbook envelope follows the captured browser reader; new tests cover durable Save retries, failed writes, literal/Unicode search, CSV quoting and encryption round-trip.

## Current risks and bottlenecks

No device performance measurements exist for the reconstruction. Source-review risks include linear Android catalog search, whole MIDI reads bounded to 16 MiB, one IO executor shared by imports and ancillary work (playback preparation now separate), JSON catalog rewrite cost, and platform/lifecycle behavior requiring device checks. These are potential bottlenecks, not measured lag. Prioritize playback/control responsiveness before visuals or background jobs.

## Checks so far

- 50 recovered Python release-tooling tests passed.
- Four starter-generation/fixture tests and the starter resource guard passed.
- C bridge compiled for Apple in the hosted package/app builds; synthetic codec fixtures passed. The Linux unsupported-codec branch also compiled with warnings treated as errors. Physical user-library compatibility remains unverified.
- All nine runtime Java files compiled against official Android API 36 references and Java 17 host libraries. Forty-six core regression checks passed. Cloud run 38742284862 also passed Gradle APK/lint and captured browser interoperability; device launch/runtime acceptance remain pending.
- Hosted Swift execution passed all 158 package tests on run 38748040876, including native audio, persistence, encrypted exports, bounded replay, scoring overflow and live/source-boundary coverage. The same source head passed the unsigned Release simulator app build.
- Cloud validation is iterative under standing owner authorization. Android build/lint/domain/browser checks pass. All 36 Swift test files are wired into seven package suites plus the Xcode UI suite; layout preflight and diagnostic artifacts support reconciliation. PR #1 is merged. Signing and deployment are not claimed. The new Android branch adds emulator runtime instrumentation; its first cloud execution remains pending.

## Android media branch acceptance

The current source compiles against official API 36 references. All 167 core regression assertions and captured browser interoperability pass locally. C11 builds with warnings treated as errors; ASan/UBSan rendering, truncation, targeted table-reference checks and 2,000 mutations pass. LeakSanitizer cannot inspect processes in this managed local runtime; explicit allocator-balance assertions pass and cloud sanitizer execution retains normal leak checks. Gradle/NDK/lint and emulator execution remain required on this changed source.

SAF individual/folder imports accept MIDI/KAR, MP3/WAV and SF2. Folder scans are bounded to 10,000 entries, 1,024 directories and depth 16. Cancellation rolls back the batch's new copies and metadata; byte-identical orphan copies can be recovered after integrity verification. A folder is copied explicitly, not watched automatically. The selected bank is persisted independently of song names.

SF2 acceptance is deliberately bounded: 32 MiB input, 128 MiB native allocation budget per worker, 128 voices, 1,024 presets, 8,192 expanded regions and bounded traversal. Structural chunk/table/reference checks precede the unchanged third-party parser; final sample/loop bounds are checked before rendering. Negative coarse sample offsets are rejected before the pinned loader can perform a signed shift. Out-of-range coarse/fine tuning and root keys are rejected. Unsupported banks fail visibly rather than being treated as a successful override. Physical sound quality, latency, bank compatibility and long-session acceptance remain open.
