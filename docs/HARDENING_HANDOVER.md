# Recovery import handover — 2026-10-15

Prepared platform separation, original iOS baseline, separate snapshots, captured website evidence, provenance manifest and reconstruction ledger. No original source file was edited and no snapshot was blindly overlaid. Android source remains absent. Imported-file SHA-256 comparisons passed; no runtime/build claim. The kanta-gelo connection now has verified admin/write access. Next: publish recovery branch, audit iOS missing references, and build native Android foundation.


## Native reconstruction checkpoint — October 15, 2026

Recovered 78 missing iOS paths, including 60 Swift files, individually without overwriting the stage baseline. Reconstructed absent Favorites/playlists, SQLite catalog, CSV/private Songbook, SFX and C compression infrastructure; repaired older LAN pagination and singer interfaces and restored asset-catalog metadata. New focused Swift storage/export tests require Apple/Swift execution.

Android now has a native Java/Gradle foundation for app-private imports, MIDI/KAR/audio playback, timed lyric lines, FIFO/singer queues, saved sets, scenic/fullscreen/TV stage, keypad/voice search and metadata exports. Missing advanced features are explicit in apps/android/README.md. Owner coding/context guide and conservative publishing policy are retained. Official YouTube playback is queued; no ad blocking or DNS workaround is included.

Actual checks: 50 recovered release-tooling tests, four starter-generation tests and resource guard passed. Nine Android runtime Java files compiled against official API 36 references and Java 17 libraries; 46 domain regression checks passed. New Swift files parsed with tree-sitter; five untouched original files exceed that grammar, so this is not a full Swift syntax/build result. C compiled on Linux for its unsupported-codec branch; Apple codec is untested. No Gradle APK/lint, simulator/device launch, CI run, signing, merge or deployment is claimed. Next gate: authorized cloud build validation before release claims.

Actual browser interoperability check also passed: a fresh synthetic Android export decrypted through the captured browser function; wrong-code and tampered-payload checks rejected. The owner-gated cloud workflow is prepared with pinned actions and no push/synchronize trigger; it has not been run.


## Existing comment review — October 15, 2026

Reviewed active iOS and Android source comments under the shared coding standard. Tightened comments in eleven existing Swift files, corrected the obsolete FTS5 fallback description, and removed an unmeasured 48,000-title responsiveness claim. Android comments already describe concrete ownership and bounds. Required attribution and recovery snapshots remain unchanged. The shared instructions explicitly cover existing and new code.

Validation: non-comment lines are byte-identical in every changed source file; all 50 release-tooling tests and git diff whitespace checks passed. No runtime behavior changed. Platform builds remain unverified; the next build gate is the previously prepared, owner-authorized consolidated CI run.


## Standing CI authorization — October 15, 2026

The owner removed the per-run CI approval and run-count limit. CI and necessary repair reruns are authorized without repeated confirmation. Consolidate coherent changes and investigate failures before retries. Platform quotas, policy denials, signing and release acceptance remain separate boundaries. Root AGENTS.md supersedes historical per-run approval instructions.


## First cloud validation — October 15, 2026

Run 38741919509 passed iOS source guards (50 release-tooling tests, four starter-generator tests and resource guard), then stopped before compilation: macos-15 selected Xcode 16.4 / Swift 6.1, while Package.swift requires Swift 6.2. The workflow now selects the runner-installed Xcode 26.2 explicitly. Android validation is still in progress. No Apple compile or simulator acceptance is claimed.

Android run 38741919509 assembled the debug APK, then lint stopped on MainActivity's literal font-style argument (WrongConstant). Replaced the value with Typeface.BOLD without changing rendering semantics. The run reported six additional lint warnings; these remain for review. Domain regression and browser interoperability steps did not execute after the lint failure. Both corrections require fresh validation on the changed head.


## Second cloud validation — October 15, 2026

Run 38742284862: Android assembleDebug, lintDebug, domain regressions, captured browser interoperability and artifact upload passed. iOS source guards passed using Xcode 26.2, then Swift test compilation found the absent RemoteCommandReplayCache referenced by recovered tests. Reconstructed the bounded cache, wired it into the existing connection after pairing validation, and added saturation coverage so executing commands cannot be evicted. Cached failures replay without re-execution; successful retries return current state. This protection is connection-scoped; reconnect/durable replay and transport encryption remain open. Removed a stale package exclude for absent Core/README.md. Fresh Swift execution and simulator build are pending.


## Third cloud validation repair — October 15, 2026

Run 38743316223 passed Android again. iOS test compilation reached RoomScoreReliabilityTests and found completedScore missing from the active LiveKaraokeScoringSession. The preserved scoring-023d470e1608 implementation differs only in completed versus elapsed target selection and clearing observations after latency changes; reconciled those exact changes and connected final Host scoring to the reliability gate. Existing room-score tests cover unheard song endings and latency invalidation. Apple test execution and simulator build require the next cloud run; no green claim is carried forward.


## Full test/source reconciliation — October 15, 2026

Following the owner request, audited the complete active test layout (36 Swift files, seven SwiftPM test targets plus Xcode UI suite) and explicit local type-qualified references. The remaining definite missing static APIs were IndexedContainerCatalog.indexRelativePath and catalogOnlySongs. Added bounded metadata-only decoding and a fixture asserting standalone/unsupported titles remain non-playable; stable IDs align with validated entries. No test assertions were removed.

Added test-layout preflight, documented all suite boundaries in TESTING.md, and separated cloud test compilation from execution. The app build now attempts independently after package failure; logs upload even on failure, exposing multiple integration errors in one run. Layout check and 50 release-tooling tests passed locally. Fourth run 38744293195 passed Android and reached the missing catalog APIs in iOS; fresh cloud compilation/execution remains required. This audit cannot guarantee absence of runtime or future integration defects.


## Expanded validation diagnostics — October 15, 2026

Run 38744977603 compiled all Swift package/test targets successfully, then test execution terminated with signal 5 after starting concurrent native audio and domain tests; the log supplied no stack or failed assertion. The independent simulator build exposed two scoringMessage references introduced during reconciliation; removed these unsupported status assignments while retaining the completed-score reliability gate. The next run executes every package test serially with Swift backtraces enabled, uploads package logs before the app build, and retains recent package-process IPS reports. Crash causality is not yet established; no tests were skipped and no runtime pass is claimed.


## Serial scoring diagnosis — October 15, 2026

Run 38746167309 compiled all package/test targets. Early package artifact showed native audio cases passing, duplicate burst/boundary score assertions failing, then signal 5 at scorerRejectsInvalidPitchAndLatencyOverflow. The active scorer subtracted Int64.min without overflow handling. Reconciled the full scorer hardening from scoring-023d470e1608 while preserving the newer finite MIDI-note conversion. Also made expected-slot calculation integer-safe for Int64.max durations and rejected invalid mutable target windows; added focused extreme-value coverage. Existing assertions are retained. Removed SWIFT_BACKTRACE injection after the runner reported privileged-executable backtraces unsupported. Apple revalidation is pending.

Run 38746167309 also completed the full unsigned Release iOS Simulator app build successfully; no package-process IPS report was produced. The next run validates the scorer repair on a changed head. Native audio tests, including non-silent original starter SF2 rendering, passed in the serial run before the scoring crash.


## Complete package execution — October 15, 2026

Run 38747387142 executed all 157 Swift package tests without the prior crash: 156 passed, one live-score assertion failed. Half-open note windows correctly reject note-ending samples, but the live window clipped its end to the latest sample timestamp and excluded that sample. The live cutoff now includes that tick with saturation at Int64.max while still clipping to the source note end. Added live/source-boundary regression coverage; completed scoring remains unchanged. No assertions were removed. Android passed again; simulator validation on this run is still in progress.


## Validated reconstruction test checkpoint — October 15, 2026

Cloud run 38748040876 passed on source head 56c9fedbb70b79ebc350e4678d5620554d53c983: all 158 Swift package tests, 50 release-tooling tests, four starter-generator tests, starter/layout guards, unsigned Release iOS Simulator build, Android APK/lint/46 domain regressions and browser interoperability. No assertions or suites were disabled. The test-layout guard and TESTING.md contracts are now required by root engineering instructions.

This checkpoint updates documentation only after the validated source commit; application source remains byte-identical to that passing head. UI automation, physical-device audio/camera/performance, secure companion transport, signing and release/deployment remain unverified. Advanced Android parity and official YouTube playback remain queued separately. PR #1 subsequently merged at 1720a54f31123f2ef59d41383dc41ef06c5855d5.


## Native Android media follow-up — October 15, 2026

`feature/native-media-parity` replaces system MIDI playback with bounded, revision-pinned MIT TinySoundFont synthesis while preserving the one controller/FIFO owner. Separate preparation and folder workers keep Next independent of import IO. Start acknowledgement commits reservations; cancellation/error retain them. SAF folder/SF2 import is transactional, source bytes remain unchanged, and failed metadata writes roll back new copies. The output-frame clock preserves audible lyric timing across tempo changes. Pitch/tempo/volume controls apply to both backends subject to platform support.

Local validation: 167 domain assertions, browser interoperability, runtime/instrumentation Java compilation against API 36 and native ASan/UBSan checks passed, including an audible generated tone, octave transposition, targeted invalid references, truncation and 2,000 mutations. Local LeakSanitizer is restricted by process inspection; allocator-balance assertions pass. The cloud workflow adds NDK builds and actual Android emulator instrumentation with screenshot/log artifacts. Changed-head cloud execution is pending. This does not establish physical audio acceptance or remaining advanced parity.


Cloud run 38801573776 passed native sanitizer checks, all 167 domain assertions, browser interoperability, NDK APK and instrumentation assembly, and lint. The emulator setup stopped before app launch because `adb` was absent from PATH. The workflow now installs platform-tools explicitly, exports its path and collects logcat independently after failure. No emulator pass is claimed from that attempt. Native review also added a pre-loader rejection for negative coarse offsets and invalid tuning/root-key ranges; vendor bytes remain unchanged. Fresh changed-head execution is required.


## iOS online runtime/artifact follow-up — October 16, 2026

Prepared a separate owner-labeled iPhone/iPad runtime workflow, actual simulator recordings/screenshots and an unsigned device IPA packaging gate. The Xcode UI suite now isolates interactions on MainActor, selects the Morning Light starter by stable identity and waits for actual current-song/playing state before pause/resume. This addresses asynchronous preparation rather than weakening the playback assertion. Device archive uses the existing personal-signing flag and omits iCloud entitlements, retaining all original Apple bundle identities. No signing material is requested or exposed. These changes require hosted UI compilation and execution; no runtime/IPA pass is claimed yet.


## Android stage and party follow-up — October 16, 2026

Added source-timed KAR fragment highlighting (including inline markers and unmarked line timing), cached native text layout, persistent lyric sizing and optional first-party perspective lights. Eight synthesized WAV pads, independent volumes, bounded four-voice SoundPool playback, stop-all and custom short-clip assignment now project the single SessionController. Intermission selects existing MP3/WAV media, is opt-in and stops for active karaoke, focus loss or background; no reservation queue is duplicated. Per-slot generations fence async metadata/load results and custom selection persists after decoder acknowledgement. Party generation follows main-library readiness rather than blocking it.

Local checks: 197 domain assertions, deterministic/non-silent bounded WAV checks via Java's independent audio decoder, source lyric-boundary cases and API 36 runtime/instrumentation compilation pass. Emulator instrumentation now includes party loading, voice bounds, stop-all and unchanged reservations. Hosted validation remains pending; custom clip/loop physical audio, camera/video and microphone parity remain open.

Expanded Android runtime coverage with a signature-protected test-only provider: nested/cyclic SAF scans, mixed-validity imports, staged cancellation and durable reopen, byte identity, controller audio import, custom pad acknowledgement/reset and idle/interrupted intermission. Runtime and provider source compile against API 36; actual emulator execution remains pending. Debug-only fixture permission does not enter the release manifest.

Custom pad review added a decoded PCM budget below Android SoundPool's documented 1 MiB truncation limit; metadata-only rate/channel inspection runs off-main and rejects oversized clips. The original media stays untouched. MediaMetadataRetriever uses release() for API 26, and intermission observation projects acknowledged start state rather than querying a preparing MediaPlayer. Local core checks now total 201.


Run 38802025283 passed iOS package tests and simulator compilation again, plus Android NDK/APK, lint, native/domain/browser checks. Android emulator never launched: its log reports Unknown AVD name because avdmanager and emulator resolved different default AVD homes. The runtime helper now shares an explicit isolated ANDROID_AVD_HOME across both tools, checks emulator process liveness, bounds every device call/startup, and retains logs/screenshots with cleanup. Android-only owner labeling permits focused infrastructure repair runs without rebuilding unchanged iOS source. No app runtime acceptance is claimed until the repaired runner executes it.


Run 38802630169 compiled the complete app/UI target. All three iPhone tests passed, including real Morning Light playback, transport and menus. iPad menu walkthrough passed; landscape keypad hittability failed, leaving orientation state for the next starter case and an invalid popover hit target. Captures show a stale window/orientation geometry. UI tests now restore portrait before/after each case, await a stable visible control frame/window orientation, and retain a capture before landscape hit assertions. Assertions are preserved. The workflow now uploads iPhone evidence before independent iPad execution. Device IPA remains blocked until both pass; no UI or signing success is carried onto the changed head.


## Validated native-media milestone — October 16, 2026

Run 38805798316 passed on `87e5aa21dc4dc3d2e2e043e8c1cbdd1beafc4ce5`: Android NDK/APK/instrumentation assembly, lint, 167 domain assertions, browser interoperability, native sanitizer tests (439.3 Hz tone / 880.3 Hz transposed, truncation, invalid references and 2,000 mutations) and 13 actual API 35 emulator checks. The explicit AVD-home repair enabled real JNI/AudioTrack playback, cancellation/FIFO, controls, pause/resume, failed preparation and native activity rendering. iOS source is unchanged from passing run 38802025283 (158 package tests and unsigned simulator app build). Only documentation changes follow this validated source head. PR #3 iPad runtime repair and PR #4 stage/party additions remain separately unverified. No signing, physical-device or deployment claim is made.


The native media baseline is merged as PR #2 (`52e1cf4d5fbc3e8666e87f41631ef8718d3b3c74`). Stage/party source now includes the repaired, bounded emulator helper and the independent iOS runtime diagnostics branch. The 201 local domain assertions and updated runtime/instrumentation source compile; the stage/party cloud run still must pass before merge. This consolidation retains the earlier accepted native source and the pending iPad repair rather than overlaying snapshots.


Latest iOS checkpoint: run 38806377805 passed on 3c12a1fb962ac956250a8f238c01eace13f560d2, including all three UI walkthrough tests on both iPhone and iPad, app/UI compilation and unsigned personal-signing device archive/IPA packaging. No assertions were removed. See IOS_RUNTIME_CHECKPOINT.md for retained artifact identities and acceptance boundaries. Earlier pending statements above describe their dated attempts; signing, installation and physical-device acceptance remain open. Only documentation follows that validated source.


Validated Android stage/party checkpoint: source b3a6cd7c795e2aaea4e48254ede290b4f616d671 passed run 38807243721 with 201 domain assertions, 28 actual API 35 emulator checks, NDK APK/instrumentation assembly, lint, native sanitizer checks and browser interoperability. Covered nested/cyclic SAF traversal, partial failure, cancellation/reopen, byte identity, custom pad decode/reset, bounded voices, stop-all, intermission gating and real karaoke playback. Only Markdown reconciliation follows that source. Personal photo/video, camera, microphone, companion and official YouTube work remain separate; no physical-device or signed-release claim is made.

## Website and clean download checkpoint — October 15, 2026 UTC

PR #5 merged verified download packaging; PR #6 merged the restored static website. Android and iOS remain separate native projects, with `apps/web` as a third independent directory. Main after these merges is `12f59c9e62d7abcea5743bec7d2fac7441a1cf0a`.

Run 38812761100 passed five packaging tests, checked original successful run/artifact identities and retained original app bytes. Separate 30-day Android and unsigned iOS bundles include SHA-256 and build records, require GitHub sign-in, and exclude the Android instrumentation APK. The unsigned personal IPA still requires signing and has no iCloud Save.

Website run 38813213292 passed static checks. Production deployment `dpl_2ar7Pidc2z7m29vGRDJGGRdjkaJb` is READY on https://kanta-public.vercel.app. All ten public pages and four public assets match validated source over HTTP. The private browser reader remains unchanged and CSP still blocks network connections. Visual inspection was attempted but blocked by `environment_offline`.

The local branch `feature/android-stage-media` contains uncommitted private photo/video stage, lifecycle, source-byte preservation, stable UI subtree/navigation and fixture/runtime-test work. It compiled against API 36 before the environment disconnected, but has not been published or runtime validated. Preserve that draft when workspace access returns; do not reset the checkout or claim the feature shipped.

Next implementation work: resume and publish that bounded media draft, run build/lint/domain/native/browser/emulator checks, then address optional camera, microphone and companion features individually. Keep official YouTube integration under its documented playback plan. Physical-device and Apple-signing tasks remain outside completed online acceptance. Necessary CI/reruns are not capped by the user.

## Resumed Android personal-media work — October 16, 2026

The workspace is online again. The local draft was checkpointed before review. A truncated local deepLagoon PNG was preserved separately and restored from the tracked original bytes; that restoration does not change the published artwork.

The Android 0.4.0 batch adds private photo/video stage imports, persisted selection, bounded validation and generation-fenced muted video lifecycle. MainActivity retains its stage/transport/navigation subtree and fits all five tabs on narrow phones. The original app mark is reused without modification. A 1,917-byte original solid-color MP4 replaces unvalidated runtime codec fixture generation. Existing emulator diagnostics are no longer overwritten by a post-shutdown ADB fallback.

Local API 36 source/instrumentation compilation, 201 domain checks, browser interoperability and test-layout preflight passed. Cloud run 38825170997 passed APK/lint/native/browser checks, 201 domain assertions and 47 emulator checks; no release, physical audio/camera acceptance or signed distribution is claimed. Existing public downloads continue pointing to the earlier accepted builds until this source passes its checks.

## Camera source prepared — October 16, 2026

Android photo/video source passed run 38825170997 and is merged in PR #8. Refreshed clean download packaging passed run 38825727083 and merged in PR #9, with Android artifact 12015246566 and unsigned iOS artifact 12014309230. Public website links have not yet been switched to these bundles.

A separate camera batch adds lifecycle-bound, default-off front preview, explicit permission handling, fullscreen transfer, background shutoff and no recording. AndroidX Activity/CameraX versions are pinned; embedded runtime licenses/notices are copied into an offline in-app asset. The merged-APK permission gate permits CAMERA as its only Android platform permission. No microphone, networking, queue/audio-owner or signing change is included.

Host Gradle could not download through the Java wrapper's network path; this is not a cloud-build failure. Test-layout preflight and source formatting passed. Hosted run 38826875086 passed compilation/lint/dependency and permission/notices checks, native sanitizers, 201 domain assertions, browser interoperability and 60 actual emulator checks. The retained capture shows original KAR playback/lyrics over the emulated front-camera feed; the audible clock continued advancing during preview. Website desktop inspection now rendered the homepage and Android download page correctly, followed navigation and confirmed the Songbook missing-file alert; mobile and successful interactive unlock remain separate.

## Accepted camera downloads and website refresh — October 16, 2026

PR #10 merged the 60-check camera source; PR #11 merged verified 0.5.0 packaging. Run 38837064251 passed, yielding Android bundle 12019382511, unsigned iOS bundle 12019507393 and provenance manifest 12019980230, expiring November 15 UTC. Original app bytes are unchanged.

The website refresh points to those actual bundles and accurately describes personal media, opt-in camera, no microphone/network permission, and retained original/runtime software notices. It also repairs footer iPhone links and reconciles the current README/context packet. Static CI and staged/production verification are pending for this batch; native source and original Songbook reader are unchanged.
