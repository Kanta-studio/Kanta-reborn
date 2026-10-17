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

The root `ios-runtime-artifacts.yml` runs automatically for relevant feature-branch iOS pushes, same-repository pull requests and after successful main-branch reconstruction validation. Manual dispatch remains available for a deliberate rerun. It builds all Xcode UI tests, executes the complete walkthrough suite on an available iPhone and iPad separately, records each simulator and extracts XCTest attachments even on failures. Stable accessibility IDs identify the requested starter and current song, and predicates wait for actual playback. Logs, results and video remain available for seven days. Only after both walkthroughs pass does it build/package an unsigned iPhoneOS personal-signing input; signing and hardware acceptance remain separate.

Android runtime fixtures live in the test APK behind a signature permission declared only by debug builds. The read-only provider exposes synthetic/original starter bytes and a bounded cyclic SAF tree; no user storage is exposed. Instrumentation checks nested traversal, partial failure, cancellation rollback/reopen, byte integrity, real controller import, custom pad decode/reset and idle intermission gating. Fixture code is excluded from release builds.



Android emulator startup uses an explicit shared AVD directory for avdmanager and emulator. The helper detects early process exits, bounds boot/ADB/instrumentation, always collects diagnostics and retires the emulator. Use `owner-approved-android-validation` for Android-only repairs; `owner-approved-validation` still runs both native platforms. No source tests are skipped by the focused label.

## iOS KCP1 controller candidate

`owner-approved-ios-validation` selects the full iOS package/app gate without rerunning unchanged Android native tests. The job pins Java 17 and compiles the unmodified Android CompanionProtocol with a synthetic Java TCP peer. LocalNetworkControlTests requires that peer via KANTA_KCP_TEST_CLASSES; absence is a failure, never a silent skip on macOS. Fixed independent Python crypto vectors check exact handshake, request and bidirectional record bytes. Live Java/Swift socket checks exercise the actual iOS client, bounded busy behavior, Unicode, distinct repeated reservations, cancellation and revocation. This is automated interoperability evidence, not a physical Android/iOS pair or iOS-host acceptance.

## iOS walkthrough runner diagnostics and suite timeout

`tools/capture-ios-runtime.py` still executes the complete four-test `KantaVisualWalkthroughUITests` suite on each platform. XCTest per-case deadlines stay 120 seconds (180 seconds maximum), while the outer process deadline is 1,080 seconds so it cannot abort a legitimate multi-case run at 660 seconds. A failing process prints the last 100 lines from its test log in the Actions job and retains the full log and completed `.xcresult` attachments; partial result bundles are not passed to `xcresulttool`. The 55-minute workflow limit and existing red-on-failure/unsigned-artifact gates are unchanged. This addresses a confirmed iPad outer-runner timeout, not the separate iPhone UI assertion; the latest branch still requires an accepted iPhone/iPad runtime run before merging or updating public binaries.

## PR #31 iPhone/iPad runtime regression checkpoint

Run [38923007543](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38923007543) built app/UI tests but both platform walkthrough jobs failed. The full preserved **iPhone** test log reports two passes (`testDemoKeypadCancelAndRepeatedIntentionalReservations`, `testMainMenuButtonsAndScreens`) and two failures: the encrypted companion screen did not become visible after pressing `companion.open` (line 108), and More was dismissed during actual starter playback (line 53). The restarted XCTest runner printed a subsequent `Executed 0 tests` success line which does not supersede the failed test cases. No unsigned IPA was produced.

The new candidate replaces route-derived sheet lifetime with an independent presentation flag and removes the nested companion link's simultaneous gesture. The capture runner scans the entire XCTest log for failed source assertions and requires the four explicit UI test cases to pass before declaring a device accepted. Verify both an iPhone and an iPad on the same final PR commit; `xcodebuild` exit zero, a nonempty recording, and a complete named test pass set are all mandatory. Failing tests must not be skipped or converted to nonblocking. The iPad's exact test assertion remains to be confirmed with the next actionable log or its separate result bundle.



## Playback completion and navigation presentation

RootView passes navigation-sheet visibility to HostView. The automatic completed-session Favorites sheet is deferred while More navigation is presented, without clearing the pending session prompt. Its binding setter must not discard pending session state while navigation owns presentation. The existing real-playback XCTest keeps its More persistence assertion and additionally verifies the navigation Done control; run all four named walkthroughs independently on both iPhone and iPad before accepting a release.


## Post-navigation keypad transition regression

The real playback walkthrough waits for a rendered stage Search button after closing the Song Library sheet. UIKit can consume a touch during sheet dismissal, so the harness retries only the idempotent action to open Search (maximum three attempts). It still fails if the stage is blocked or the actual numbered keypad never appears; no assertions are skipped. Both iPhone and iPad must pass on the final commit.


## iOS modal request lifecycle

The Root, Host and Stage SwiftUI sheet owners share `KantaPresentationGate`. The gate holds a request received while another sheet is presented or dismissing, coalesces a second pending request from the same owner, and activates the first pending action only after the current owner reports `onDismiss`. The Search walkthrough deliberately taps once after leaving Library; do not add retries or fixed sleeps to mask a dropped presentation request. UIKit fullscreen remains a separately owned presenter and is not covered by this gate yet.


### iOS fullscreen presentation ownership candidate

The presentation contract guard checks that the UIKit fullscreen presenter acquires and releases `KantaPresentationGate` ownership through its dismissal callback, and that the gate restores fullscreen after a nested Search/Queue sheet. The UI walkthrough opens fullscreen from CONTROL, uses Search inside fullscreen, exits, and verifies normal-stage Search can present afterward. Run `tools/check-ios-presentation-contract.py` and the full reconstruction validation on the candidate SHA. A green run on a different SHA does not validate it.


## Automatic workflow triggers and release boundary

Reconstruction validation runs for relevant app, tool and workflow changes on feature/main pushes and pull requests. iOS runtime, website and verified-download contract checks also run on relevant feature-branch pushes so a PR does not need a manually applied label to start. iOS simulator walkthroughs follow relevant same-repository pull requests and successful main reconstruction runs. Website validation runs for relevant website changes. Verified-download contract tests run automatically; packaging the fixed, previously accepted IPA/APK artifacts still requires owner dispatch or the packaging label. No workflow signs, merges, deploys or publishes production downloads automatically.

## CI separation: fast validation, unsigned artifacts and visual acceptance

- `reconstruction-validation.yml` remains the required PR source, Swift package, simulator-build, and Android validation gate. It does not execute the long XCTest UI walkthrough.
- `ios-runtime-artifacts.yml` builds the unsigned personal-signing IPA independently on relevant iOS changes or manual dispatch. Its success proves packaging, not simulator interactions, signing, or installability.
- `ios-visual-walkthrough.yml` runs the full four-case XCTest walkthrough separately on both iPhone and iPad, with screenshots, recordings and failure diagnostics. It is manually dispatchable, scheduled weekly (Monday 03:00 Asia/Manila), and triggered by `ios-rc-*` tags. It does not run on ordinary pull requests or documentation commits.
- A release candidate requires a successful visual walkthrough on the **exact candidate SHA**; weekly or unrelated-commit green evidence cannot substitute for release acceptance. CI does not sign, publish or deploy.
- `ios-smoke.yml` runs `testFocusedNavigationSmoke` on an iPhone simulator for relevant iOS PR changes. It checks Search, fullscreen dismissal and Search recovery. This is not the full iPhone/iPad release walkthrough.
- This split deliberately prevents the expensive walkthrough from blocking ordinary merges while keeping the full iPhone/iPad visual acceptance mandatory for release.
