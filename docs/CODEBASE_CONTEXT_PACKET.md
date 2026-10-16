# Codebase Context Packet — KANTA Reborn

Current snapshot: merged Android stage/party and iOS runtime work, verified download packaging and restored website. Native source revisions and checks are listed below and in the root README. This is a testing reconstruction, not a signed production release.

## Current accepted state

Android 0.7.0 source `1ddee2416b6efe56562f5826ad479a6373ecf86c` passed run 38842165486 with 268 domain assertions, 90 actual API 35 checks, APK/instrumentation build, lint, native sanitizers, browser interoperability and the permission/runtime-notice gate. Private photo/video storage, stable stage/navigation, opt-in lifecycle-bound front-camera preview and dry microphone input level/pitch are merged. The generated runtime notices preserve dependency identities and exact embedded license text.

iOS source `3c12a1fb962ac956250a8f238c01eace13f560d2` passed all three UI walkthroughs on both iPhone and iPad plus unsigned device packaging in run 38806377805; its package source passed 158 tests. No Apple source change is included in the Android follow-ups.

The website still offers accepted 0.6.0 while 0.7.0 packaging is prepared. Packaging run 38840276706 passed five contract tests and original app identity/checksum verification. Android and unsigned iOS bundles last 30 days and require GitHub sign-in. The static website remains under apps/web; its private reader is byte-identical to evidence and CSP blocks network connections.

Control panels still rebuild on controller publication and search remains in-memory over normalized snapshots. These are source-review risks, not measured latency claims. Camera preview has no capture/analysis/recording output. Experimental monitored effects are implemented; physical output and calibrated scoring, secure companion and official YouTube remain unfinished. Physical quality/latency, external displays and signing remain open.

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

## Android personal-media implementation — October 16, 2026

Workspace access resumed. The previously local draft is being published as a separate Android-only batch, based on current main. StageMediaStore adds bounded private byte-preserving photo/video copies, atomic persisted selection and cancellation/rollback. StageSurface adds a main-Looper muted video-only projection with generation fencing, actual-first-frame visibility and release on deactivation/detach. Photos use sampled EXIF-oriented display decoding; original bytes are never rewritten.

The frequent publication path now retains the stage, transport and navigation subtree, avoiding video teardown/recreation on queue or option changes. Control panel rebuilding and in-memory library search remain source-review performance risks, not measured latency results. Five weighted tabs replace clipped horizontal navigation. No playback/FIFO or audio-clock ownership changes.

Local API 36 compilation of production and instrumentation sources passed; 201 domain checks and actual browser export/decrypt/wrong-code/tamper checks passed. Focused runtime cases cover persisted photo/video selection, malformed-media rollback, source-byte identity, stable stage identity, visible navigation and muted-video first-frame/deactivate/reactivate behavior. Hosted run 38825170997 passed APK/lint/native/browser checks and all 47 emulator checks on source 2ced06c5c6063e15e227cc094b2462a36a03e7f2. Camera, microphone processing, companion networking and official YouTube remain unfinished.

## Android camera batch — October 16, 2026

Current accepted media source remains 2ced06c5c6063e15e227cc094b2462a36a03e7f2 (201 domain checks and 47 emulator checks). New camera source uses ComponentActivity 1.10.1 and CameraX camera-camera2/camera-lifecycle/camera-view 1.5.3; Java/Views, AtomicFile/JSON storage, existing audio engines and authoritative queue ownership remain unchanged. No Compose, Room or DI framework is introduced.

CameraStage owns only a foreground opt-in Preview use case with asynchronous generation fencing, a 12-second readiness bound and one primary/fullscreen target. COMPATIBLE PreviewView supplies rotation/mirroring and an actual streaming visibility signal. The preview has no file/analysis/audio output. Stop removes its observers and unbinds; activation is not persisted or restored after backgrounding. The manifest adds CAMERA only and optional hardware declarations. A built-APK gate checks platform permissions and offline upstream notices.

Instrumentation retains all prior tests and adds fresh-install default-off/permission state, actual emulated front-preview rendering, fullscreen transfer/return, explicit disable/reopen and a real Home/foreground cycle with no automatic camera restart. New dependency compilation and all hosted checks passed in run 38826875086 (201 domain assertions, 60 emulator checks, APK/lint/native/browser and permission/notices gates); no hardware or latency measurement is claimed. Official references: https://developer.android.com/media/camera/camerax/preview and https://developer.android.com/reference/androidx/camera/view/PreviewView .

## Android microphone implementation context — October 16, 2026

Starting from main a4bd5dd0422da502709dcb342e309a963080860e. Java 17/Views, minSdk 26, targetSdk 36, CameraX 1.5.3, Activity 1.10.1 and AtomicFile/JSON storage remain unchanged. SessionController owns playback/FIFO; microphone capture will be an independent foreground opt-in input service with no AudioTrack, file output or network access in this first batch. RECORD_AUDIO will be requested only by explicit activation.

AudioRecord reads nonblocking bounded PCM16 buffers on a dedicated capture worker. A separate worker receives at most one outstanding 4,096-sample dry frame for pitch analysis; busy analysis drops frames rather than accumulating latency. UI reads immutable snapshots on its existing 100 ms tick. Stop clears visible measurements immediately; per-run identity fencing rejects late callbacks and observations. Input estimates are neither a singer-identification result nor a completed-song score. Monitoring/effects, calibrated timeline scoring, companion networking and official YouTube remain separate follow-ups. No measured device latency or microphone quality claim is made.

Android references reviewed: AudioRecord, AudioRouting and Android's Sharing audio input guide. The first capture batch deliberately has no microphone output route. Source and instrumentation acceptance remain pending until the changed head is built and exercised.

Accepted microphone input source c961cb3bbe76ef77bea8052529cb93a552d15a53 passed run 38839639544: APK/instrumentation build, lint, native sanitizers, 233 domain checks, browser interoperability, permission/notices gate and 78 actual API 35 emulator checks. No old assertions were removed. Only Markdown checkpoint reconciliation follows. No physical microphone acceptance, monitored output, effects or completed-song score is claimed. See ANDROID_MICROPHONE_CHECKPOINT.md.

## Android monitored-output implementation context — October 16, 2026

Starting from d4f9d84 (accepted 0.6 input and verified website). The Java/Views stack, storage, library search, AudioRecord dry path, CameraX and authoritative playback/FIFO remain unchanged. The next batch adds a separate opt-in AudioTrack monitor with no second input or song queue. Available-device enumeration is only a selection step; actual routed output must match that selection, with all API 36 routed outputs checked. Playback begins muted and route loss retires the activation. Speaker/Bluetooth routes are excluded.

Capture/output clocks are independent even at nominal 48 kHz. A bounded interpolation ring will adjust consumption for small clock drift and retire stale audio on overflow/underrun. Monitor-only Dry/Room/Hall/Echo processing never modifies the dry pitch frame. No native autotune, melody scoring, recording, network, new dependency or physical latency claim is included in this batch. Acceptance will distinguish domain DSP/routing checks, emulator rejection of unsafe output, and unverified physical wired/USB playback. References: Android AudioTrack/AudioRouting and NDK Audio latency guidance.

Candidate implementation now compiles all Android production and instrumentation Java against official API 36 and the exact 48 pinned runtime dependency coordinates from the accepted CameraX build. Local checks pass 268 domain assertions, browser export/wrong-code/tamper interoperability and test-layout wiring. Existing compatibility/deprecation/resource-analysis warnings remain; Android lint is still a separate hosted gate. Voice settings expand within Control to preserve search/reservation space. Physical output remains unverified.

Pre-API-36 routing exposes one reported route; any additional unreported outputs cannot be verified. API 36 checks the complete routed-device list. Privacy and experimental voice settings disclose this boundary. No absolute acoustic-safety claim is made.

Accepted monitor source 1ddee2416b6efe56562f5826ad479a6373ecf86c passed run 38842165486, all 268 domain and 90 actual API 35 checks plus APK/lint/native/browser/permission-notice gates. Only Markdown checkpoint reconciliation follows. Physical monitoring remains unverified; see ANDROID_MONITOR_CHECKPOINT.md.
