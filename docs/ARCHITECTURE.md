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

Explicit Android exports use the shared CSV/AES-GCM browser format. The manifest has no Internet permission; optional CAMERA use is described below for the accepted 0.5.0 source, and the 0.6.0 input batch adds explicitly requested RECORD_AUDIO. Device-provider speech is user initiated and disclosed. SAF folder import and custom bank selection are implemented in the current Android branch; camera/video are implemented as described below; monitored audio, calibrated scoring and encrypted companion transport remain unfinished. See CODEBASE_CONTEXT_PACKET.md for bounds and validation status. The official YouTube integration is queued in docs/YOUTUBE_PLAYBACK_PLAN.md.


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

## Android dry microphone input

MicrophoneInput is composed by SessionController and owns no output, queue, playback clock or file writer. Explicit permission/foreground activation creates a transient run identity. Nonblocking mono PCM16 capture at 48 kHz runs on its own worker with bounded input buffers, a five-second no-data bound and privacy-sensitive capture on API 30+. API 29+ silenced-client state disables the run. UNPROCESSED is selected when advertised, otherwise VOICE_RECOGNITION; vendor preprocessing remains possible.

At most one 4,096-sample dry frame is analyzed at a time on a separate worker, no more often than every 125 ms. A bounded YIN difference workspace estimates 70–1,000 Hz periods after silence/nonfinite/aperiodic rejection, searching shorter periods to reject high-frequency fundamentals rather than labeling subharmonics. Immutable measurement snapshots expire after 750 ms and are read by the existing UI tick without rebuilding the stage or control panel per frame. Run-local data and identity checks retire late analysis; stop immediately removes public readings and the capture worker releases AudioRecord independently. Backgrounding, focus loss and noisy-route interruption disable input; returning requires a new explicit action.

This batch has no microphone AudioTrack, effects, recording, completed-song score or singer identification. Input estimates can contain backing music. Hardware input compatibility, acoustic quality and latency remain acceptance items. Monitoring/output route enforcement and calibrated dry scoring remain follow-ups; this input service must not become another playback owner.

## Android optional monitored output (0.7.0 candidate)

MicrophoneMonitor owns one independent AudioTrack and receives copies of the existing AudioRecord PCM blocks. It never modifies dry analysis, opens another input or owns karaoke reservations. Explicit foreground/input-active selection accepts only wired headphones/headsets, USB device/headset and analog line-out. Enumeration alone is insufficient: AudioTrack starts with zeroes and zero volume, and actual routed output must match the selection within 1.5 seconds. API 36 checks the complete routed-device list and rejects multiple outputs. A closed MonitorRouteGuard cannot resume after route loss; a new explicit action creates a new guard. Routing notifications, selected-device removal, worker checks and parent lifecycle/focus cancellation mute and retire the activation. Callback/native/hardware latency means transient physical feedback cannot be categorically excluded without equipment testing.

A bounded 8,192-frame MonitorBuffer starts at a 1,440-frame input floor and uses linear interpolation with occupancy feedback bounded to +/-0.5% consumption adjustment for independent nominal-48-kHz clocks. Overrun drops stale buffered input; underrun emits silence and re-primes. Discontinuities reset effect tails. One output worker owns reusable 480-frame blocks and fixed delay-network memory; input offers run separately with bounded synchronized copies. Nonblocking output writes have a 500 ms no-progress bound. No audio is saved or networked.

Dry/Room/Hall/Echo are first-party monitor-only effects with finite input sanitization and a +/-0.9 sample ceiling. Output volume starts at 10% per activation and clamps at 35%; these software bounds do not control external amplifier gain. Effect/volume changes cannot opt in to output. Stop immediately mutes, invalidates the run and clears queued input; the worker pauses, flushes and releases the track and its callbacks. No automated success claim is made for physical wired/USB playback, acoustic safety or low latency. Pitch correction, calibrated melody scoring, companion and official YouTube remain follow-ups.

Routing limit: before API 36, AudioRouting exposes only getRoutedDevice; this implementation can verify that single reported route but cannot categorically exclude an additional unreported output. API 36 uses the complete AudioTrack.getRoutedDevices list. The privacy/UI text discloses this limit and the monitor remains experimental/default-off. Preferred-device selection is never treated as proof of actual routing.

## Android optional pitch-following scoring (0.8.0 accepted source)

The existing bounded SMF parser now retains track index, note-channel masks, bounded track/instrument labels and real lyric evidence without changing event timing, MIDI rendering or imported bytes. MelodyTarget requires exactly one lyric-bearing or explicitly vocal/melody-labelled track with one non-drum note-bearing channel. It rejects ambiguous candidates, overlapping or incomplete note lifetimes and noncentral channel pitch bends (including bends from another track). No target is invented for MP3/WAV or unlabelled high notes. Extraction runs with MIDI preparation off-main.

SessionController remains the single owner. Each started reservation installs its distinct UUID as the playback identity and its complete immutable target. A separate opt-in creates MelodyScoreSession off-main with stale-request and identity fencing. Natural completion finalizes at most once; manual stop, replacement or preparation failure cannot publish a score. A last result retains title/singer/identity and a bounded numerical summary in session memory only. Insufficient/silent input shows no reportable numerical score.

Scoring observes the existing dry pitch estimate on the 100 ms foreground tick regardless of whether voice controls are expanded. Whole-frame/epoch fences reject data spanning start/resume/calibration/control changes. Timing uses the estimated dry-frame center, its arrival age, audible source position, source tempo and a manually adjustable -500..1,500 ms offset. This is an estimate requiring physical calibration, not measured input latency. Source-end-clamped playback rejects later frames, including the MIDI release tail. Key/tempo/calibration changes cancel and rebuild the accumulator; pause/resume and foreground transitions retire crossing frames.

SoundFontPlayback exposes an audible control fence: main-thread key/tempo requests receive identities, the audio worker records the first newly rendered frame, and only the actual playback head can acknowledge it. An old acknowledgement cannot settle a newer request. Scoring waits for that fence and a subsequent complete dry frame, rather than comparing new targets against buffered old-key/old-tempo audio. Volume alone does not reset scoring. Existing rendered source-clock ownership is unchanged.

The scorer uses binary target lookup and constant-size incremental best-confidence slot aggregation, without a growing observation array. Source slots scale with tempo (200 ms at normal pace). Half-open note windows avoid double counting boundaries; final expected coverage always includes the complete target, including unobserved endings. At least 20 matched slots and 10% coverage are needed before reporting a finite estimate. Invalid/nonfinite, low-confidence, silent, out-of-order and foreign-identity samples are rejected. Pitch accuracy and timing coverage form an informal estimate; backing music can be mistaken for a singer and no ability assessment or physical scoring accuracy is claimed. Monitoring/effects remain separate, with no recording or networking. Pitch correction, secure companion and official YouTube remain follow-ups.

Oversized optional track/instrument labels are skipped without rejecting otherwise playable MIDI. Overlong decoded labels are not truncated into explicit vocal-name evidence. Lyric/event bounds and original media bytes remain unchanged. Regression fixtures cover both oversized metadata and misleading name truncation.


Accepted Android 0.8 source `57dc0611cb54435802a4bd7d226e00983dd3c8f6` passed run [38845590252](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38845590252): APK/instrumentation assembly, lint, native sanitizers, all 328 domain assertions, browser interoperability, permission/notices gate and 110 actual API 35 emulator checks. PR #21 merged as `5e6d5dc09f4bbfed25566d6dc17dfc20fe0cf25b`. No prior assertions were removed. Physical timing/scoring accuracy remains unverified; verified download packaging is separate. See ANDROID_SCORING_CHECKPOINT.md.


## Android optional chromatic correction (0.9.0 candidate)

MicrophoneMonitor composes ChromaticPitchCorrector before its existing Dry/Room/Hall/Echo processor on the one output worker. No second capture, song queue, playback clock, file writer, native library or dependency is introduced. Off bypasses the corrector completely. The existing dry AudioRecord analysis and scoring path are unchanged. Each monitor run owns an immutable correction selection/epoch; activation requires an already verified allowed output and separate explicit user action. Stop, input loss, route loss and backgrounding retire that run and its correction selection. A fresh run starts off. A single generation-fenced readiness publication enables the UI after actual routing is verified.

The first-party processor uses two complementary Hann-weighted fractional delay taps, an 8,192-float history and a precomputed 4,097-float window at 48 kHz. Input/output block lengths remain equal, with no growing buffer or audio-worker allocation. The 4,096-frame sweep plus 480-frame minimum creates roughly 10–95.3 ms of algorithmic tap delay; unshifted fallback has a fixed 2,528-frame (52.7 ms) delay. These are mathematical buffer lengths, not measured device or total round-trip latency. Ratio and wet transitions smooth over nominal 40 ms and 10 ms time constants. Output is finite and limited to +/-0.9 before existing effects. On discontinuity or selection replacement, histories/effect tails are reset; final cleanup clears them.

Stable existing dry estimates in 70–1,000 Hz, confidence at least .85 and RMS at least .008 select a nearby equal-tempered semitone. A .6-semitone hysteresis threshold prevents boundary chatter and bounds shifts to +/-60 cents. Estimates must be no older than 300 ms and their complete 86 ms frame must follow the activation/discontinuity epoch. Invalid, stale, silent or uncertain estimates relax to equally delayed unshifted input. Correction is chromatic, not song-melody/scale guidance or formant-preserving processing; it can color the voice and produce artifacts. Physical voice quality, latency and feedback remain unverified. No audio is saved or uploaded.

Algorithm references (concepts only; no third-party source copied): Miller Puckette, The Theory and Technique of Electronic Music, pitch-shifter section, https://msp.ucsd.edu/techniques/v0.05/book-html/node115.html ; Android low-latency guidance, https://developer.android.com/games/sdk/oboe/low-latency-audio and https://developer.android.com/ndk/guides/audio/audio-latency . This change retains the existing AudioTrack worker; it does not claim Oboe/AAudio implementation or measured low latency.


## Hosted Android 0.9 acceptance

Source `4f48e051dcd815e878205eda43bf9331591e279d` passed run [38881735518](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38881735518): all 364 domain assertions and 116 actual API 35 emulator checks, APK/instrumentation assembly, lint, native ASan/UBSan checks, browser interoperability and merged permission/offline-notices checks. PR #25 merged as `2851a0b81f43698a99b036b8dd28aa25c0d495eb`. Existing assertions remain enabled. The accepted output is artifact `12038226827`; checksum-verified packaging must preserve these APK bytes before changing public downloads. Physical corrected voice quality, artifacts, feedback and total latency remain unverified. Secure companion and official YouTube remain queued. This entry supersedes candidate hosted-pending statements above.


## Production Android 0.9 verified

Website source `95855ff18e9c1758e53a4315bf460b9f29ee876b` passed static run `38882633589` and READY preview `dpl_ESS6EucV9dVBs8x7y9tKzjGSqxK8`. All 15 preview pages/assets matched source with CSP, and real browser inspection confirmed Android 0.9, the 364/116 checks, source/download identity and setup navigation. PR #27 merged as `4c8e8066dc9f480de1922410628990eb788df4d5`. Production deployment `dpl_4xB8tKDdT61KhkSMnTRLx21HS4de` is READY on https://kanta-public.vercel.app; all 15 production pages/assets match validated bytes with CSP. The browser independently confirmed the public Android 0.9 page and bundle `12038451005` from packaging run `38882359866`. Original private reader/styles/notices and unsigned iOS application bytes are unchanged.

Post-deploy verification caught a competing production deployment returning 404. The public alias was restored to the verified deployment, and the persistent Vercel project settings now explicitly use root `apps/web`, output `.`, no framework, and empty install/build commands. The corrected public alias and all 15 responses were verified after restoration. Deployment READY alone is insufficient: check the public alias, content and security headers before declaring completion.

Pitch correction implementation, acceptance, verified packaging and website publication are complete. The next software task is secure companion control, followed by official YouTube playback. Physical voice quality/timbre/artifacts/feedback/latency, scoring calibration, camera/external-display acceptance and iOS production signing remain open. This checkpoint changes Markdown only and requires no additional native build.


## Android optional companion boundary

Android 0.10 adds foreground-only, explicit private-IPv4 companion hosting/client control through the existing SessionController/FIFO. The actual Java 17/Views, storage, imports, audio engines, CameraX and platform separation remain unchanged. INTERNET is added for private Java sockets; no new dependency, cloud service, discovery broadcast or iOS protocol change is introduced. KCP1 uses a 128-bit random expiring pairing secret, mutually authenticated HMAC handshake, HKDF direction keys and ordered AES-GCM records. Commands are limited to bounded search/queue metadata, reserve/cancel and Play/Pause/Next; sensors and file access are excluded. A single worker owns socket work; main-Looper mutations check active foreground run and cancellation. Background/Stop revokes immediately, with no automatic reconnect. See ANDROID_COMPANION_CHECKPOINT.md for exact framing, bounds, replay scope, no-forward-secrecy limitation and acceptance.

Candidate core compilation and all 443 domain assertions passed (79 new companion checks); browser interoperability and Swift layout guards pass. Hosted build/lint and actual emulator socket/queue/lifecycle checks remain pending. Physical two-device networking, iOS compatibility and independent security review remain open. Public downloads remain accepted 0.9 until separately verified packaging/publication.


## Hosted Android 0.10 acceptance

Final source `d777334eec73996116fdf2c01d97ac73a3a53958` passed run `38885716463`: all 448 domain assertions (84 companion cases), 139 actual API 35 emulator checks, APK/instrumentation assembly, lint, native ASan/UBSan, captured browser interoperability and the CAMERA/RECORD_AUDIO/INTERNET permission/notices gate. Initial source also passed the complete suite; the final source adds bounded peer JSON nesting and strict UTF-8 checks. An independent Python cryptography client verified the JCA handshake, HKDF, framing and both direction keys. PR #28 merged as `51b57e0052c8f01d08fac04f12cccae06b189ad5`. Accepted original artifact is `12039807731`. No existing assertion was disabled. Physical two-device networking, iOS interoperability, forward secrecy and independent security review remain open; Android acceptance does not establish those properties. Public downloads remain verified 0.9 until checksum-verified packaging and website publication.


## Production Android 0.10 verified

Website source `f2bd2b517f0a9059084b2604cddcdc9b2cf1e66c` passed hosted run `38886674120`; preview `dpl_2bG6QWnkFVbkT7YLVuwyxBgLAr13` is READY. All fifteen preview routes/assets returned 200 and retained CSP. Fourteen responses matched source exactly; the homepage matched source plus Vercel's appended preview feedback-script tag, which is blocked by the unchanged CSP. Browser navigation confirmed Android 0.10 source d777334e, the 448/139 counts, accepted download identity and companion setup guide.

PR #30 merged as `0a11058b2d70182b2956d57b2f320edbe19762ee`. Production deployment `dpl_H9fF42EU9QobF613s7Y4d7Rvfkbt` is READY on https://kanta-public.vercel.app, using explicit `apps/web` root, `.` output and empty install/build commands. All fifteen public responses returned 200, matched validated source exactly and retained CSP; production has no appended feedback tag. Browser inspection of canonical `/android` independently confirmed version 0.10.0, source d777334e, run 38885716463 and Android bundle 12040160062. Both platform download pages use successful packaging run 38886416353; iOS bundle 12038684955 preserves the unchanged unsigned IPA. The 26,974,938-byte Android APK SHA-256 is 7743d1994c500b472f86829ea041307303f0f908d0e5505b788c35ca76026d3d. The downloaded packaging manifest archive digest was checked independently.

Android companion implementation, automated acceptance, original-byte packaging and website publication are complete. This is an experimental Android-to-Android milestone, not cross-platform or independently audited security acceptance. The recovered iOS plaintext protocol remains incompatible; encrypted iOS interoperability is the next companion milestone, followed by the queued official YouTube integration. Physical two-device networking, audio quality/feedback/latency, scoring calibration, camera/external displays and production app signing remain open. Final handover updates are Markdown only and introduce no runtime, workflow, dependency or asset change.

### Android YouTube external-player handoff candidate

A separate, optional Control action accepts video URLs and delegates only a bounded canonical HTTPS `www.youtube.com/watch?v=` destination through a standard `ACTION_VIEW` intent. `core.YouTubeLink` is pure Java and tests strict host/scheme/ID boundaries independently of Android. No remote media is persisted or imported; this initial slice does not add YouTube to `SessionController` or the singer FIFO, and does not constitute embedded-player integration. Launching the external player follows the existing Activity `onStop` lifecycle and pauses local karaoke. The future in-app player must be designed as a distinct playback source under the existing controller with explicit failure/foreground handling and verified YouTube player integrity. This is candidate code pending cloud checks, not a production release.
