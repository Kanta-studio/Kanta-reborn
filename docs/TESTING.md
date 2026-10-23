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



Android emulator startup uses an explicit shared AVD directory for avdmanager and emulator. The helper detects early process exits, bounds boot/ADB/instrumentation, always collects diagnostics and retires the emulator. Both native jobs run automatically on every relevant change; no validation label is required, and no source tests are skipped.

## iOS KCP1 controller candidate

The iOS job runs the full package and app gate automatically alongside the Android job; it no longer needs a validation label. The job pins Java 17 and compiles the unmodified Android CompanionProtocol with a synthetic Java TCP peer. LocalNetworkControlTests requires that peer via KANTA_KCP_TEST_CLASSES; absence is a failure, never a silent skip on macOS. Fixed independent Python crypto vectors check exact handshake, request and bidirectional record bytes. Live Java/Swift socket checks exercise the actual iOS client, bounded busy behavior, Unicode, distinct repeated reservations, cancellation and revocation. This is automated interoperability evidence, not a physical Android/iOS pair or iOS-host acceptance.

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

Reconstruction validation runs for relevant app, tool and workflow changes on same-repository pull requests and main pushes. Website validation runs for relevant website changes on main pushes and same-repository pull requests, and can also be started manually. Feature-branch validation uses the pull-request event rather than duplicate ordinary branch-push runs.

The verified-download contract tests run automatically on relevant pull requests and main pushes. The packaging job is **manual-dispatch only on main** because it produces a reusable cross-platform bundle and must not run merely because its own workflow or contract tests changed. Dispatch accepts an optional full source SHA; otherwise it uses the selected main ref. It requires the newest matching main-branch runs for reconstruction validation, the unsigned iOS device archive, and the complete iPhone/iPad walkthrough to have succeeded on that exact SHA. It then discovers artifacts from those runs, rejects expired or mismatched artifacts, and validates their source/run identity, digests, archive structure and application metadata. It never signs, publishes a GitHub Release or deploys production downloads. An expired/missing artifact is a hard failure, not permission to reuse an unrelated build.

## CI separation: fast validation, unsigned artifacts and visual acceptance

- `reconstruction-validation.yml` owns source guards, Swift package tests, unsigned simulator compilation, Android build/lint/domain checks and Android emulator checks.
- `ios-runtime-artifacts.yml` builds the unsigned personal-signing IPA for relevant iOS/tool changes on pull requests and main. It does not sign or publish the app.
- `ios-visual-walkthrough.yml` runs the complete XCTest walkthrough separately on iPhone and iPad for relevant iOS pull requests and main pushes, as well as weekly, manually and on `ios-rc-*` tags. A green result is release evidence only for that exact SHA.
- `ios-smoke.yml` runs the focused iPhone navigation smoke on relevant iOS PR changes. It does not replace the full iPhone/iPad walkthrough.
- `verified-downloads.yml` runs contract tests automatically, while its packaging job is manually dispatched on main and requires successful exact-SHA reconstruction, unsigned IPA and full iPhone/iPad walkthrough evidence.
- Simulator builds and unsigned archives do not establish signing, physical-device audio quality or production deployment. No automated workflow signs or publishes production downloads.

## GitHub Actions cost controls (October 2026)

- Feature branches are validated by the pull-request event only; ordinary feature-branch pushes do not duplicate reconstruction, website or download-contract jobs. Main pushes retain post-merge verification.
- Unsigned IPA generation is separated from the package-bundling job. The archive workflow runs only for relevant iOS/tool changes; the verified-download bundler runs only when deliberately dispatched after release acceptance.
- Full iPhone/iPad walkthroughs run automatically on relevant iOS pull requests and main pushes, plus weekly and on release-candidate tags. Both devices must pass on the exact candidate SHA.
- Failure triage remains manually dispatchable with a failed run ID; it does not launch after every successful validation.
- Workflow YAML changes require checking triggers and required status checks. Keep immutable action pins and preserve all source/test assertions when correcting workflows.

## PR #43 post-merge evidence

Commit `ad95e8b04eb23311127090883f309f0ec4205724` passed reconstruction run [39051661330](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39051661330). Website validation and verified-download contracts also passed on that main-branch commit. This is a historical checkpoint; current packaging is manual-dispatch only and requires exact-SHA reconstruction, unsigned IPA and full iPhone/iPad walkthrough evidence. A missing package on an ordinary push is expected.
