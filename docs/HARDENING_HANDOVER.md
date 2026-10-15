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


Run 38802025283 passed iOS package tests and simulator compilation again, plus Android NDK/APK, lint, native/domain/browser checks. Android emulator never launched: its log reports Unknown AVD name because avdmanager and emulator resolved different default AVD homes. The runtime helper now shares an explicit isolated ANDROID_AVD_HOME across both tools, checks emulator process liveness, bounds every device call/startup, and retains logs/screenshots with cleanup. Android-only owner labeling permits focused infrastructure repair runs without rebuilding unchanged iOS source. No app runtime acceptance is claimed until the repaired runner executes it.


Run 38802630169 compiled the complete app/UI target. All three iPhone tests passed, including real Morning Light playback, transport and menus. iPad menu walkthrough passed; landscape keypad hittability failed, leaving orientation state for the next starter case and an invalid popover hit target. Captures show a stale window/orientation geometry. UI tests now restore portrait before/after each case, await a stable visible control frame/window orientation, and retain a capture before landscape hit assertions. Assertions are preserved. The workflow now uploads iPhone evidence before independent iPad execution. Device IPA remains blocked until both pass; no UI or signing success is carried onto the changed head.
