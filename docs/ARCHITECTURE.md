# KANTA Reborn architecture

## Repository boundaries

`apps/ios` retains the original Swift app structure, project.yml, Package.swift, Sources, Resources and Tests. The original stage-ui snapshot is the selected baseline because it includes the latest recovered stage implementation; missing paths have been restored individually and absent infrastructure reconstructed; hosted Swift tests and unsigned simulator compilation have passed; device/release acceptance remains open. Original Apple bundle identities and iOS 17 minimum remain subject to the recovered project configuration.

`apps/android` contains a new native Java/Android Views reconstruction, explicitly distinct from original source, with its own Gradle build and signing boundary. See its README for implemented and missing features.

`recovery/ios/snapshots` contains other original snapshots without nested Git databases. They are evidence, not dependencies. Complete recovery ZIPs remain preserved separately. Historical source variants must be reconciled file by file.

`docs/evidence/website/2026-10-15` stores exact public-site bytes, extracted readable text and URL/SHA-256 manifest. It remains immutable evidence; the active restored website is maintained separately under apps/web. No public song catalog may be added.

## Runtime contracts

Each platform has one playback controller and FIFO reservation queue. UI, lyrics, fullscreen/TV stage and companion control project that owner's state. Import and persistence run away from latency-sensitive playback/UI work; commits are atomic and stale async results cannot replace newer state. Retry suppression applies to the same operation ID, never separate intentional reservations.

Scoring is default off and observes dry microphone input without storing audio. Completion scores belong to immutable playback identities and are emitted only once. Monitoring and pitch processing are separate opt-in services and must mute on unsafe output routes. Source media and user SF2 are byte-preserved.

Companion commands require explicit pairing, authorization, bounded replay protection and revocation. Website descriptions conflict between older plaintext PIN control and newer encrypted Android pairing; do not implement or advertise cross-platform transport compatibility without an explicit reviewed protocol and tests.

## Build isolation

Historical `.github` directories nested inside app/recovery folders do not run as root GitHub workflows. The new root reconstruction-validation workflow runs only by explicit manual dispatch or an owner-applied owner-approved-validation label (both platforms); owner-approved-android-validation runs Android only for focused repair. It has no push/synchronize trigger, read-only repository permissions, bounded timeouts and pinned action revisions. Publishing code does not launch it. Signing secrets never belong in Git. The iOS job explicitly selects Xcode 26.2 on macos-15 to satisfy Package.swift tools version 6.2; the image default Xcode 16.4 is insufficient.

## Shared material

Shared future files are limited to independently verified first-party assets and documented interoperability formats. Native playback state and UI code remain platform specific. The captured Songbook JavaScript may inform a compatibility specification; a claim of compatibility requires cross-platform fixture tests.

## Reconstructed storage and export boundaries

On iOS, SavedKaraokeSetStore performs synchronous atomic write-before-publication transactions inside its actor, retaining durable Save operation keys. SQLiteSongCatalog is owned solely by BookmarkedKaraokeLibrary; validated metadata replaces atomically and query terms are bound. CSV is metadata-only with quoting/formula neutralization. Private Songbooks derive an AES-GCM key from a random per-export 128-bit code using the captured browser format. The SFX actor owns at most four independent AVAudioPlayer voices and bounded private clip copies. The C codec uses bounded streaming buffers and private exclusive temporary files; Apple compilation passed; legacy licensing acceptance remains open. Older LAN pagination and singer APIs were reconciled; its transport remains plaintext.

## Android ownership and media

KantaApplication owns one SessionController. MediaPlayer creation, commands and callbacks stay on the main Looper. ReservationQueue gives intentional reservations distinct UUIDs with bounded replay tracking. A serial IO executor owns LibraryRepository writes and heavy file work. Search uses cached normalized song keys, immutable snapshots, a separate executor and stale-result fencing. Visible song results and reservation rows are paginated.

SAF imports create hash-identified, byte-preserved private files; AtomicFile commits metadata, queue references, saved sets and starter tombstones. SMF 0/1 lyric parsing bounds files, tracks, events, text and timing while merging tempo across tracks. MIDI channel events feed a dedicated TinySoundFont/AudioTrack worker; imported SF2 selects the next song's bank. MP3/WAV retain main-Looper MediaPlayer. Explicit backend start acknowledgement commits the reservation. RenderedPlaybackClock tracks audible frames through buffered tempo changes. Playback preparation and SAF tree scanning have separate workers from serial catalog IO. Failed prepare retains the reservation; stale or removed reservations cannot start. Native StageView, fullscreen and TV Presentation project the same playback time without a second queue or progress bar.

Explicit Android exports use the shared CSV/AES-GCM browser format. The manifest has no Internet or microphone permission; optional CAMERA use is described below for the 0.5.0 source. Device-provider speech is user initiated and disclosed. SAF folder import and custom bank selection are implemented in the current Android branch; sensor audio, camera/video, encrypted companion transport remain unfinished. See CODEBASE_CONTEXT_PACKET.md for bounds and validation status. The official YouTube integration is queued in docs/YOUTUBE_PLAYBACK_PLAN.md.


The recovered iOS LAN connection now suppresses duplicate command envelope IDs through a bounded 512-entry cache on the main actor. Completed results may be evicted; in-flight commands stay pinned. This is connection-scoped, not durable replay protection across reconnects, and does not encrypt the recovered plaintext protocol.

Final scoring uses the complete target timeline, including unheard ending windows; live scoring uses elapsed windows. Latency changes invalidate accumulated observations. Host completion applies RoomScoreReliability before publishing a final estimate. These recovered scoring contracts are reconciled from the scoring snapshot without replacing stage UI.

The validation pipeline compiles all Swift package test targets before running them and attempts the iOS app build independently of package failures. Test layout verification prevents orphaned suites; compiler and runtime checks remain authoritative. See TESTING.md for module contracts and acceptance boundaries. Indexed metadata fallback supplies stable non-playable songs when container offsets cannot be verified.


## Online runtime and packaging evidence

The separate owner-labeled iOS runtime workflow compiles the complete Xcode UI target, runs real interactions on one available iPhone and iPad simulator, and retains screenshots, videos and XCTest results. Stable accessibility identities select the actual starter row and current song; playback waits for an enabled Pause state and the selected title before interaction. These UI identities do not own playback state. Simulator videos do not establish physical audio quality.

After both walkthroughs pass, the same workflow builds a separate unsigned iPhoneOS archive with `KANTA_PERSONAL_SIGNING` and no iCloud signing entitlements, then invokes the validated IPA packager. It retains source/run identity and a SHA-256 manifest. This is a personal-signing input, not a signed or directly installable release; it never requests or publishes Apple credentials. The ordinary iOS build retains its original bundle/container identities and capabilities.


## Android stage and auxiliary sound

MIDI lyric cues retain original fragment timestamps and character boundaries. StageView uses those source events for highlighting, the existing audible clock for position, and cached StaticLayout objects for stable text. No word timings are invented. Adjustable lyric size and optional first-party perspective lights are projections of SessionController state; animation owns no playback clock.

PartyAudio owns at most four SoundPool voices and one separate MediaPlayer for explicitly enabled idle intermission music. SessionController alone decides eligibility using foreground, audio focus, current song, loading state and the existing FIFO. It stops auxiliary audio on focus loss/background and never consumes reservations for SFX. Builtin synthesis runs after the main library becomes ready. Custom pad validation runs on IO; per-slot generations retire stale validation/load results, and preference changes commit only after decode acknowledgement. Original media is reused byte-identically from My Set.

## Android personal stage media

StageMediaStore is owned by the serial IO executor. It copies selected files into hash-named private storage, validates content and bounds before committing versioned AtomicFile selection metadata, preserves original bytes and rolls back failed/cancelled imports. Photos are limited to 32 MiB and 100 megapixels/16,384 pixels per dimension; display decode samples to at most 2,048 pixels and honors EXIF orientation without rewriting the source. Videos are limited to 512 MiB, 8,192 pixels per dimension and six hours. Only the replaced same-kind private copy is removed after commit; unknown files are not swept.

SessionController remains the sole queue/transport owner and publishes the selected visual through independent operation and display generations. StageSurface owns only a lifecycle-bound muted looping MediaPlayer, its TextureView surface and the existing lyric projection. It starts visual video only in the foreground, releases it when inactive/detached, retains Scenic behind failed/unrendered video and fences stale preparation callbacks. Fullscreen suppresses the redundant primary video renderer; a separate external-display projection may own another decoder. No camera, audio monitoring, network permission or second karaoke queue is introduced.

MainActivity retains its stage/transport/navigation tree across controller publication and rebuilds only the selected control panel. Five weighted navigation tabs remain visible on narrow phones. The app icon reuses the original recovered iOS artwork byte-for-byte. The test-only solid-color silent MP4 is procedurally generated and has documented provenance; no third-party clip is bundled. Cloud run 38825170997 passed source 2ced06c5c6063e15e227cc094b2462a36a03e7f2: APK/instrumentation assembly, lint, native sanitizer checks, all 201 domain checks, browser interoperability and 47 actual API 35 runtime checks. Physical-device acceptance remains open.

## Optional Android front-camera preview

The 0.5.0 source adds pinned AndroidX Activity 1.10.1 and CameraX 1.5.3. MainActivity becomes a ComponentActivity so CameraX binds to the actual host lifecycle. CameraStage binds only Preview with DEFAULT_FRONT_CAMERA and COMPATIBLE PreviewView rendering; no ImageCapture, ImageAnalysis or VideoCapture use case exists.

Activation requires an explicit user action and CAMERA grant. A transient request flag and generation reject late permission/provider callbacks. The one active preview moves between the primary/fullscreen projection; external display uses a still fallback. Leaving the foreground explicitly unbinds, removes observers/views, cancels the readiness deadline and disables activation. Returning or recreating the activity does not opt in again. Missing/busy/failed cameras leave saved media unchanged, with no retry loop. Camera hardware is optional, and microphone/internet/shared-storage permissions remain absent.

Build-generated runtime notices retain dependency coordinates and the exact embedded upstream LICENSE/NOTICE text, accessible offline in My Set. APK validation inspects merged permissions and the generated asset. Run 38826875086 passed on source 4da765035dd3cbeec6e69f38581138225b706e6d: APK/instrumentation assembly, lint, permission/notices gate, native sanitizers, 201 domain assertions, browser interoperability and all 60 emulator checks; emulator results cannot establish physical orientation, camera quality or thermal behavior.
