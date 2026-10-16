# Reconstruction validation

Tests and production source must describe the same behavior. Keep recovered tests that enforce product invariants; reconcile missing APIs from preserved source or implement the documented contract. Never remove assertions, disable lint or accept a baseline merely to make validation green.

## Suite boundaries

| Suite | Contract | Execution |
| --- | --- | --- |
| GeloKaraokeCoreTests | MIDI/lyrics, one FIFO owner, playback identity, failure-safe handoff, scoring and remote serialization | SwiftPM on macOS |
| LegacyCompatibilityTests | Bounded binary reads, validated spans and malformed inputs | SwiftPM on macOS |
| LibraryStorageTests | Safe import roots, starter removal/restore, backup integrity, persistence, search and metadata exports | SwiftPM on macOS |
| LocalNetworkControlTests | Framing, pairing, bounded search and connection-scoped replay suppression | SwiftPM on macOS |
| AVFoundationPlaybackTests / AVFoundationMIDIPlaybackTests | Format rejection, controls and original starter synthesis | SwiftPM on macOS; physical audio remains separate |
| MicrophoneScoringTests | Pitch detection and room gate | SwiftPM on macOS; microphone/device acceptance remains separate |
| KantaUITests | Actual iOS stage/control walkthrough | Separate simulator UI run; not covered by an unsigned build |
| ReleaseToolingTests / starter generator | Release contracts, privacy/source guards and deterministic first-party resources | Python locally and in CI |
| Android core regression | FIFO retry identity, Unicode search, bounded MIDI timing and encrypted exports | Gradle JavaExec |
| Android native SoundFont | Validated SF2 references, bounded allocations, audible pitch, truncation and mutation handling | C11 ASan/UBSan host harness |
| Android runtime instrumentation | Real JNI/AudioTrack, FIFO commit, cancellation, controls, pause/resume, failed prepare and activity rendering | Clean API 35 emulator install; custom Instrumentation, no external test library |
| Browser interoperability | Fresh Android export through the captured browser decrypt function | Node after Android regression fixture generation |

## Validation order

1. Run `python3 tools/verify-test-layout.py` to reject orphaned Swift test files, absent target directories and unknown local `@testable` imports. This checks wiring, not Swift types or behavior.
2. Run Python release/starter guards. Preserve synthetic fixtures and isolate temporary directories.
3. On Xcode 26.2 / Swift 6.2, run `swift build --build-tests` in `apps/ios` to compile production modules and every package test target before execution.
4. Run `swift test --skip-build --no-parallel`. A successful compilation alone does not establish passing behavior.
5. Attempt the unsigned simulator app build even when package validation fails. This reports app integration errors in the same run rather than hiding them behind earlier failures. Retain the three diagnostic logs as seven-day artifacts.
6. Android runs APK assembly, lint, domain regression and browser interoperability. Do not treat an APK build as device playback proof.

All package suites remain enabled. Build failures stay failures, including when later diagnostic steps succeed. UI automation, signing, physical audio/camera, LAN confidentiality and device performance require separate acceptance; no static audit can guarantee that future mismatches will never occur.

## Reconciled contracts

- Completed room scores include the entire target timeline; live scores include elapsed targets. Changing latency clears prior observations.
- Duplicate envelope IDs execute once within the bounded connection cache; active requests cannot be evicted.
- Unsupported indexed media remains searchable with stable IDs and `isPlayable == false`; title discovery never invents playback offsets.

The immutable recovery snapshots retain provenance. Active source and tests are reconciled together on the current PR.

Native and domain cases run serially for clear failure attribution. All tests remain enabled. Early package-log upload and recent package-process IPS reports support diagnosis. The signal-5 crash was isolated to scoring latency overflow and repaired; native audio cases also pass.

The serial run isolated the signal-5 stop to extreme-latency arithmetic in the scorer and exposed duplicate-slot and adjacent-boundary failures. Restored finite-input filtering, overflow-reporting latency subtraction, half-open windows and one observation per slot. Added extreme-duration/invalid-window coverage; retained the newer finite MIDI-note conversion. Swift backtrace environment injection was removed because this runner rejects it for privileged toolchain executables.

Live scoring includes the most recently received sample while source note ends remain exclusive; completed scores always use original target windows. The explicit source-boundary regression prevents a future fix from extending notes to recover the latest sample.

## Verified checkpoint

Cloud run [38748040876](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38748040876), source commit `56c9fedbb70b79ebc350e4678d5620554d53c983`: all 158 Swift package tests, 50 release-tooling tests, four starter-generator tests, starter/layout guards, unsigned Release simulator app build, Android APK/lint/46 domain checks and browser interoperability passed. UI automation and physical-device acceptance remain separate.


## iOS online runtime workflow

The root `ios-runtime-artifacts.yml` runs only by owner manual dispatch or `owner-approved-ios-runtime` label. It builds all Xcode UI tests, executes the complete walkthrough suite on an available iPhone and iPad separately, records each simulator and extracts XCTest attachments even on failures. Stable accessibility IDs identify the requested starter and current song, and predicates wait for actual playback. Logs, results and video remain available for seven days. Only after both walkthroughs pass does it build/package an unsigned iPhoneOS personal-signing input; signing and hardware acceptance remain separate.

Android runtime fixtures live in the test APK behind a signature permission declared only by debug builds. The read-only provider exposes synthetic/original starter bytes and a bounded cyclic SAF tree; no user storage is exposed. Instrumentation checks nested traversal, partial failure, cancellation rollback/reopen, byte integrity, real controller import, custom pad decode/reset and idle intermission gating. Fixture code is excluded from release builds.



Android emulator startup uses an explicit shared AVD directory for avdmanager and emulator. The helper detects early process exits, bounds boot/ADB/instrumentation, always collects diagnostics and retires the emulator. Use `owner-approved-android-validation` for Android-only repairs; `owner-approved-validation` still runs both native platforms. No source tests are skipped by the focused label.

## Tiered native CI and visual evidence — candidate

CI distinguishes build correctness from real UI/device acceptance, and it does not equate video capture with passing tests.

| Tier | Trigger | Android | iPhone/iPad | Evidence |
| --- | --- | --- | --- | --- |
| Fast native | Every implementation PR affecting native source or shared tooling | APK + test APK compilation, lint, domain regression, native SoundFont sanitizer, permission/notices and browser interop | Entire Swift package/unit suite, tooling/source guards and unsigned simulator **build only** | Failure logs; no simulator, emulator or video |
| Focused visual | UI-related PR changes, or explicit owner-approved visual label/dispatch | Clean-install API 35 emulator, five real tab interactions and screenshots | Focused XCTest launch/stage, Control sheet and Song Library screenshots on iPhone and iPad | Screenshots, assertion results and logs; **no video by default** |
| Release visual | Manual dispatch with `mode=release`, or owner release-runtime label | Short recorded UI tour plus exhaustive JNI/AudioTrack/SAF/queue/camera/monitor runtime test and stage/camera images | All real iPhone/iPad walkthrough tests, screenshots, recorded video and unsigned personal-signing IPA only on successful acceptance | Release visual artifacts for seven days |
| Failure investigation | Re-run focused visual with `record_video=true` for iOS; Android release capture as appropriate | Focused screenshots and logcat; release video opt-in | Focused screenshots and short video only when requested | Bounded diagnostic capture; no blanket recording |
| Full visual regression | On-demand manual release dispatch (not scheduled) | Complete physical-emulator suite plus focused visual tour | Full iPhone+iPad UI suite | Green automated evidence does not replace physical device tests |

The existing `reconstruction-validation.yml` remains an explicitly owner-authorized full engineering gate, including Android runtime and iOS packages. The new `fast-native-checks.yml` runs on qualifying native pull requests without emulator or video; `android-visual-acceptance.yml` handles visual Android runs; `ios-runtime-artifacts.yml` supports focused and release modes. Concurrency groups avoid duplicate active fast revisions. Owner-only guardrails and GitHub read-only workflow permissions remain in place.

Video is opt-in for focused diagnostics; release acceptance records video. Full release runs do not publish updated app binaries until all required tests and separate packaging checks are green. No UI assertion or source regression test was removed to obtain faster CI. Runtime performance, platform-specific hardware behavior and real YouTube ad display still require device/browser verification.
