# Codebase Context Packet — KANTA Reborn

Current snapshot: merged Android stage/party and iOS runtime work, verified download packaging and restored website. Native source revisions and checks are listed below and in the root README. This is a testing reconstruction, not a signed production release.

## Current accepted state

Android source `b3a6cd7c795e2aaea4e48254ede290b4f616d671` passed 201 domain assertions and 28 actual API 35 emulator checks in run 38807243721, plus build/lint/native/browser checks. iOS source `3c12a1fb962ac956250a8f238c01eace13f560d2` passed all three UI walkthroughs on both iPhone and iPad simulators and unsigned device archive/IPA packaging in run 38806377805; package source previously passed 158 tests.

The static website is now maintained under `apps/web`, with verified 30-day GitHub Actions download bundles. Packaging and website checks passed in runs 38812761100 and 38813213292. The browser Songbook script/stylesheet remain byte-identical to recovery evidence, with network access blocked by CSP.

The current Android UI rebuilds views on frequent publication and can clip the final navigation tab on narrow screens. A stable-stage subtree/navigation repair and private photo/video background implementation exist only as an unmerged local draft; API 36 source compilation was checked before the workspace went offline, but no cloud build, runtime acceptance or publication is claimed. Do not infer this draft is in main or in the downloads.

Camera, microphone processing, secure companion networking and official YouTube remain separate Android work. Hardware quality, latency, long-session behavior and final distribution remain open across platforms. Historical work notes below retain their original chronology; current checkpoints supersede earlier pending statements.

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

The iOS runtime follow-up changes only accessibility identities, UI-test isolation/waits, and root validation/artifact orchestration. Core playback ownership and persisted formats are unchanged. Xcode UI-target compilation, both simulator walkthroughs and the unsigned device archive remain pending on that branch.

## Android stage/party work snapshot

The follow-up starts from the published native media and iOS runtime branches. StageView currently draws cached scenic bitmaps and line-level lyrics on a 100 ms UI refresh; it rebuilds wrapped text during drawing. Loop/Realm are explicit placeholders. No camera, video, party or intermission backend exists yet. The current work will retain SessionController as authority, keep source-timed lyric fragments, isolate optional stage/party resources, preserve imported bytes and add bounded storage/lifecycle rules. These are planned changes, not current acceptance claims.

## Android stage/party branch implementation

Source-timed fragment highlighting, cached native text layout, lyric sizing and opt-in procedural perspective lights are implemented. PartySounds generates eight deterministic two-second WAV pads; PartyAudio bounds SoundPool voices to four and owns a separate main-Looper intermission player. SessionController gates idle music and foreground/focus behavior; SharedPreferences retains selected local song IDs and independent volumes, never enabled monitoring/sensors. Custom MP3/WAV pads validate size (8 MiB) and duration (30 seconds) on IO, then persist after decode acknowledgement with stale-load fencing. No Android sensor, camera, video or companion implementation is implied. Local API 36 runtime/instrumentation compilation and 197 domain assertions pass; changed-head cloud/runtime validation remains pending.

SoundPool's documented 1 MiB decoded limit requires an additional conservative 900 KiB PCM estimate for custom pads. MediaExtractor validates audio track rate/channels off-main; oversized decoded clips are rejected rather than silently truncated. Metadata retriever cleanup uses release() for minSdk 26 compatibility; close()/AutoCloseable starts at API 29. Both native loops and test snapshots now read acknowledged playback state, not invalid MediaPlayer preparation-state queries. Primary references: Android SoundPool and API 29 MediaMetadataRetriever diff documentation.


## Validated native-media checkpoint

Source head `87e5aa21dc4dc3d2e2e043e8c1cbdd1beafc4ce5` passed run 38805798316: native sanitizer/tone/mutation checks, Gradle NDK APK and instrumentation build, lint, all 167 domain assertions, captured browser interoperability and 13 actual emulator checks (JNI/AudioTrack playback, FIFO, cancellation, controls, pause/resume, failed preparation and UI). iOS app/package source is unchanged from run 38802025283, which passed all 158 package tests and simulator compilation. This checkpoint changes documentation only. iPad runtime, advanced Android parity, signing and deployment remain separate.


Latest iOS checkpoint: run 38806377805 passed on 3c12a1fb962ac956250a8f238c01eace13f560d2, including all three UI walkthrough tests on both iPhone and iPad, app/UI compilation and unsigned personal-signing device archive/IPA packaging. No assertions were removed. See the IOS_RUNTIME_CHECKPOINT.md ledger for retained artifact identities and acceptance boundaries. Earlier pending statements above describe their dated attempts; signing, installation and physical-device acceptance remain open. Only documentation follows that validated source.


Validated Android stage/party checkpoint: source b3a6cd7c795e2aaea4e48254ede290b4f616d671 passed run 38807243721 with 201 domain assertions, 28 actual API 35 emulator checks, NDK APK/instrumentation assembly, lint, native sanitizer checks and browser interoperability. Covered nested/cyclic SAF traversal, partial failure, cancellation/reopen, byte identity, custom pad decode/reset, bounded voices, stop-all, intermission gating and real karaoke playback. Only Markdown reconciliation follows that source. Personal photo/video, camera, microphone, companion and official YouTube work remain separate; no physical-device or signed-release claim is made.
