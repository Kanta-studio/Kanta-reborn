# KANTA CI failure and repair ledger

This is the durable, append-only engineering record for recurring failures. Keep exact evidence, fix commits, and **the first green run on the fixed SHA**. Do not promote a repair from `candidate` to `verified` merely because code was pushed, a different SHA passed, or compilation succeeded. When an issue recurs, search this ledger before editing.

## Mandatory repair record

Every failed CI job with an engineering fix must receive a record containing:

- **Fingerprint:** platform, workflow/job, test/assertion or compiler diagnostic, and distinctive log phrase.
- **Affected SHA / first observed run:** link to job, logs and retained screenshot/xcresult where relevant.
- **Cause:** confirmed mechanism from code and evidence; distinguish hypotheses explicitly.
- **Fix:** changed file(s), exact state/invariant repaired, commit SHA and PR.
- **Regression coverage:** test name and the failure that would occur if the fix were removed.
- **Validation:** first passing CI run ID, job, tested head SHA, scope (source/static, package tests, simulator UI, hardware, signed release), date. If pending or failing, mark `candidate`.
- **Recurrence rule:** grep keywords, related prior records and what *not* to do.
- **Status:** `observed`, `diagnosing`, `candidate`, `verified`, `regressed`, or `superseded`.

After a relevant CI run becomes green, update this ledger **in a separate docs-only commit** recording the actual run ID and SHA, then confirm the documentation commit did not alter production behavior. If a docs-only commit triggers a new workflow, don't imply the prior green result validated the new SHA's source; state the distinction. If validation fails, retain the candidate record and continue the repair. Never rewrite a historical failure as though it never occurred.

## iOS — Search inaccessible after leaving Library

**Fingerprint:** `KantaVisualWalkthroughUITests.testStarterPlaybackAndControls`; `Search is blocked after leaving the library`; iPhone/iPad simulator runtime walkthrough.

**First documented failure:** [runtime run 39014560050](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39014560050), source SHA `6273e16b0b1c66b50a62e1026d87fbcb9c5ad7df`. Runtime failure on both iPhone and iPad. Artifacts: `ios-runtime-evidence` and `ios-iphone-runtime-evidence` on that run. Build/compilation success is not a passing walkthrough.

**Investigation:** `RootView`, `HostView`, `KantaMainPlayerView` and `SingingModalPresenter` have independently owned presentation paths. `HostViewModel.run()` refreshes playback snapshots every 100 ms; library starter playback uses the shared `LocalKaraokeController`. The test previously waited for `navigationBars["Song Library"]` to disappear, but `LibraryView` declares `.navigationTitle("Library")`; the wait could pass before the actual sheet dismissed. This test mismatch is **confirmed**. The exact view obstructing Search in the failed run remains **unconfirmed**; do not claim the ownership refactor is proven root cause until runtime evidence verifies it.

**Candidate repair commits:** `e88204f` captures screenshot and full accessibility hierarchy on blocked Search; `74270b1` corrects the navigation-title wait; `ed3dd56` tracks root navigation dismissal through `onDismiss`; `2bc19cb`, `63116bb`, `84be430` introduce a shared main-actor presentation gate for Root/Host/Stage. PR [#36](https://github.com/kanta-gelo/Kanta-reborn/pull/36).

**Regression:** one-tap Search after More → Library → starter playback → Done, then keypad → Cancel → CONTROL on iPhone and iPad. Preserve failure-time hierarchy and screenshots. Additional required coverage: simultaneous sheet requests, dismissal callbacks, session-save prompt and fullscreen UIKit presenter ownership.

**Validation status:** `candidate`. [Reconstruction run 39021531256](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39021531256) was in progress when this record was authored, head `84be43061ffee747580ffe6c854e7ed8b1bc610b`. No passing runtime walkthrough or release IPA is established by this record. Recheck run before marking verified.

**Recurrence rule:** inspect the current Library title, actual topmost presentation and attached accessibility hierarchy before modifying XCTest waits. Do not add blind sleeps, repeat taps, or claim source guards prove simulator interaction. Review `docs/ENGINEERING_ARCHITECTURE_CONTRACT.md` and the modal lifecycle source before any fix.

## Future entries

Add a new dated section for each distinct fingerprint. When a previous fingerprint returns, add a **recurrence subsection to the existing record**, linking the new SHA/run and explaining why the earlier repair did not hold. Never delete previous attempts or passing-run evidence.

## iOS — Presentation contract guard mismatch (2026-10-17)

**Fingerprint:** `tools/check-ios-presentation-contract.py`; `FAIL: root rejects overlapping menu presentations`; reconstruction validation iOS source guards.

**Observed:** [run 39021723583](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39021723583), source SHA `2365d4723f4117da61b6a05e1f30126bd5c2d0da`.

**Cause:** the static contract still matched the obsolete exact string `guard activeNavigation == nil else { return }` while `RootView` now guards `activeNavigation == nil && !navigationDismissing` and also requires `presentationGate.acquire(.navigation)`. The new guards reject overlapping requests; the stale checker was rejecting the stronger implementation.

**Candidate fix:** align the checker with both current guards rather than deleting the contract assertion. PR [#36](https://github.com/kanta-gelo/Kanta-reborn/pull/36). No application behavior changed.

**Regression:** the source guard fails if either the dismissal check or shared gate acquisition is removed. **Validation:** `candidate`; CI on this fix SHA pending. This does not establish passing iPhone/iPad walkthroughs.
undefined

## iOS — UIKit fullscreen bypasses presentation gate (2026-10-17)

**Fingerprint:** fullscreen UIKit player can overlap SwiftUI sheet requests; UIKit presenter has no shared owner acquisition or dismissal acknowledgment.

**Cause:** confirmed by current source inspection. `SingingModalPresenter` presents a UIKit controller independently of `KantaPresentationGate`. Simply holding the gate for fullscreen would block Search/Queue sheets hosted inside that fullscreen stage.

**Candidate repair:** PR #36 adds fullscreen gate acquisition, waits for the UIKit dismissal completion before releasing ownership, queues a fullscreen request before the CONTROL sheet releases its owner, and models fullscreen Search/Queue as a nested stage owner which restores fullscreen after child dismissal. Adds walkthrough coverage for Search inside fullscreen and Search after exiting fullscreen. The UIKit presenter continues to dismiss only its own player controller.

**Regression coverage:** `KantaVisualWalkthroughUITests.testStarterPlaybackAndControls` opens fullscreen from CONTROL, opens and dismisses Search inside fullscreen, exits, then opens Search on the normal stage.

**Validation:** candidate. Current-head source guards, simulator compilation, iPhone/iPad walkthrough and unsigned IPA remain unverified. Do not merge based only on a passing earlier SHA or source inspection.

**Recurrence rule:** inspect both UIKit player identity and nested SwiftUI sheet ownership. Do not acquire a fullscreen lock without a child-presentation path; do not release the gate before UIKit's completion callback.


## GitHub Actions — duplicate push trigger keys (2026-10-17)

**Fingerprint:** `.github/workflows/verified-downloads.yml` and `.github/workflows/website-validation.yml` appeared as failed runs with zero jobs on source SHA `325c3792c2cc7d570c0390c50450df4a8b8da5b7`: [verified-downloads run 39030157542](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39030157542) and [website-validation run 39030156916](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39030156916).

**Cause:** the feature-branch trigger was inserted as a second root `push` key instead of being combined with the existing main-branch trigger. GitHub could not load either workflow, so both runs failed before creating jobs. The iOS runtime workflow on the same SHA loaded and began normally.

**Fix:** consolidate each workflow to one path-filtered `push` trigger covering relevant changes across branches, and keep their pull-request triggers. Download packaging remains gated; only its contract-test job runs automatically.

**Regression coverage:** GitHub Actions must create actual jobs for website validation and verified-download contracts on a relevant feature-branch push. Check run event, job list and final conclusion; zero-job workflow failures are not validation passes.

**Validation:** candidate on the corrected workflow SHA. Recheck both workflows on the new head. Do not rerun unchanged SHA `325c3792c2cc7d570c0390c50450df4a8b8da5b7`.

## iOS — Session-save sheet obstructs Search after Library (2026-10-17)

**Fingerprint:** `testStarterPlaybackAndControls` line 79, `Search is blocked after leaving the library`; [runtime run 39030285248](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39030285248), SHA `a37a2d37a3b78367579f952bd79eef8c3f956a4d`. Both iPhone 16 Pro and iPad walkthroughs failed this assertion; the other three walkthrough cases passed on each device.

**Confirmed iPhone cause:** the retained `search-blocked-accessibility-hierarchy` and screenshot show a topmost **Save to Favorites** host sheet covering the stage Search button. The Library navigation bar was already gone. `HostView` automatically presented a pending session-save sheet when `navigationSheetPresented` changed to false. `HostViewModel` marks a completed session when playback stops with an empty queue; this can happen while Library is open. The earlier dismissal-animation hypothesis does not explain the captured obstruction. The iPad shares the same assertion and presentation code, but its retained hierarchy has not yet been independently inspected.

**Candidate repair:** remove automatic save-sheet presentation during navigation handoff; keep the pending save offer as a visible, explicit stage action. Preserve the saved session until the user chooses Save/Don't Save, and continue tracking subsequent completed songs while a save decision is pending. Close the save sheet when the model clears the pending decision. Changed `HostView`, `KantaMainPlayerView`, `HostViewModel` and UI regression. PR [#36](https://github.com/kanta-gelo/Kanta-reborn/pull/36). Commit and runtime validation are pending at the time of this record.

**Regression coverage:** after Library → Done, Search must be accessible on the first tap without dismissing another modal. If the pending-session action is visible, opening it must show Save to Favorites and Don't Save must close it. Preserve both device screenshots/hierarchies. No blind sleeps or repeated Search taps were added.

**Status:** `candidate`; compile, iPhone/iPad simulator acceptance, merge and release are not yet verified for this repair.


## iOS — Fullscreen action unreachable in expanded CONTROL (2026-10-17)

**Fingerprint:** iPhone and iPad runtime walkthrough run [39031958909](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39031958909), current head `0b00cc3d4f13ab24051be7051f59dc050ec876ec`; `testStarterPlaybackAndControls` failed at the fullscreen button hit-test (test line 107). Reconstruction validation [39031958919](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39031958919) passed on the same head. iOS compilation passed; the walkthrough failed on both device sizes before attempting fullscreen.

**Cause:** the test expanded the detailed CONTROL section and then searched for the fullscreen action in the Stage row below a long scrolling list. The action remained outside the hittable viewport after the test's bounded swipes, making the path fragile on both device layouts.

**Repair:** expose a labeled, identified fullscreen action in the CONTROL navigation toolbar. Keep the Stage-preview affordance and route both entry points through one Host method that dismisses CONTROL and queues fullscreen with the shared presentation gate. The walkthrough now targets `controls.openFullscreen` directly, then continues to verify fullscreen Search and gate release after exit.

**Validation:** candidate fix pushed to the PR branch; automatic iPhone/iPad runtime and reconstruction results are pending. Do not merge until both walkthroughs pass on the updated head.


## iOS — Post-fullscreen Search assertion raced dismissal (2026-10-17)

**Fingerprint:** runtime run [39034162526](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39034162526), head `c6a5f2a4ff3b47e2efc3c8ad70687bdfee9860fd`; both iPhone and iPad reported `Fullscreen dismissal did not release stage presentation ownership` at the final Search-after-exit check. App and UI tests compiled; all other walkthrough cases passed.

**Evidence:** the walkthrough tapped Cancel and immediately checked that `fullscreen.exit` existed, although that button remains in the underlying fullscreen view during child-sheet dismissal. After tapping Exit it checked only that the stage Search element existed; the same accessibility identifier also exists under the fullscreen projection and in the underlying Host. Neither existence check proved either dismissal had completed.

**Repair:** wait for the fullscreen Search keypad to disappear after Cancel, wait for the unique `fullscreen.exit` control to disappear after Exit, and require the stage Search button to be hittable before tapping it. This preserves the real gate-release assertion while removing ambiguous accessibility queries and transition races; no fixed sleeps or relaxed checks are added.

**Validation:** strengthened walkthrough pushed to PR #36; automatic current-head runtime and reconstruction checks are pending. If stage Search remains blocked after the fullscreen exit control is gone, trace and repair the app's gate release callback before merge.


## iOS — Fullscreen presenter dismissed its nested child, not the player (2026-10-17)

**Fingerprint:** runtime run [39036089941](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39036089941), head `b1322ffc1620144eac4ab4e84e3243e22415073b`. Build passed; both iPhone 16 Pro and iPad failed at the assertion waiting for `fullscreen.exit` to disappear after tapping Exit. Reconstruction validation [39036089948](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39036089948) passed; Android emulator checks passed.

**Cause:** `SingingModalPresenter.updatePresentation()` began dismissing its player as soon as the Host binding became false, even while a nested Search/Queue sheet still owned the presentation gate. UIKit can complete dismissal of that child first; the presenter then treated that callback as fullscreen teardown, cleared its player identity and left the parent fullscreen controller visible. The prior test only waited for Search's keypad to leave the accessibility tree, which can precede the sheet's `onDismiss` gate handoff.

**Repair:** observe shared presentation-gate changes. If the child still owns the gate, defer fullscreen teardown. Once the child `onDismiss` restores `.fullscreen` ownership with dismissal requested, the presenter dismisses its exact player and completes ownership release from that dismissal callback. The test's explicit wait for the unique fullscreen exit control to disappear remains in place.

**Validation:** presenter change is applied on the latest PR head; automatic current-head runtime and reconstruction checks are pending. Do not merge until both device walkthroughs pass.


**Follow-up after run 39038432004:** the gate-observation guard compiled but the runtime still left `fullscreen.exit` visible on both devices. The Exit action now calls the UIKit presenter directly in the same main-actor turn that clears the SwiftUI binding. The presenter records the dismissal intent, enters the gate's serialized dismissal path and waits for child ownership restoration before dismissing its exact player. This addresses the missing presenter update signal shown by the failed assertion; fresh iPhone/iPad runtime validation is pending.

### 2026-10-17 — fullscreen exit remains visible after tap

- Failed runtime run: `39038432004`, source SHA `8e5c2560b0a6503f35101b8da93debc177e0c50b`; both iPhone and iPad `KantaVisualWalkthroughUITests.testStarterPlaybackAndControls` timed out at line 127 waiting for `fullscreen.exit` to disappear.
- Source-level cause candidate: `SingingModalPresenter.updatePresentation()` refused to call UIKit dismissal unless `presentationGate.owner == .fullscreen` and `presentationGate.dismissing == true`. Fullscreen child Search/Queue can temporarily own the gate; the exit intent must not be dropped while that child transition completes.
- Fix commit: `b2bdc3810e9470e7f87a8788b033d7c74e64969f` removes the blocking guard while preserving the existing dismissal callback and gate completion.
- Verification: pending latest-head iPhone/iPad simulator walkthrough; no green runtime result claimed.


### 2026-10-17 — fullscreen Exit still visible after tap (run 39041512052)

- iPhone 16 Pro failed at UI test line 127 after successfully tapping `fullscreen.exit`; the XCTest wait expired because the button remained in the accessibility tree. The failure log is in the [iOS runtime run](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39041512052).
- Cause candidate: `updatePresentation()` required the presenter's view to remain attached to a window for both presentation and dismissal. UIKit can detach the presenting view during a full-screen presentation, so that guard can block the Exit dismissal path.
- Fix commit: `fa635ab4eb33546c543ca61322a36bdb3c05ede0` moves the window attachment requirement into the presentation branch; dismissal remains available while the presenter is off-window.
- Validation: pending fresh iPhone/iPad walkthrough and reconstruction checks on the updated head. Do not merge until both device walkthroughs pass.


### 2026-10-18 — PR #51 has no validation run after lifecycle repair

- Source: `7fb5e2a8f8e2bd805c2ecf5b5820ad2208fe42ed`; main advanced to `56f10c505ed654c57e0b6b4b3412b082181a77c4`. GitHub reports `mergeable_state: dirty`; both the commit-filtered Actions query and PR-run query returned no runs. There is no failed run ID because validation never started.
- Confirmed integration blocker: both branches appended independent sections to `docs/ARCHITECTURE.md`. Git reports that file as the sole merge conflict. Pull-request workflows require a mergeable PR; draft status is not excluded by the current workflow.
- Repair: merge the current main ancestry into the existing feature branch, preserving the online-player lifecycle section and all approved library-folder, SongHub import and FluidSynth decisions. No application, workflow or assertion changes. No history rewrite or main-branch merge.
- Verification: conflict-marker and whitespace review, test-layout and presentation guards on the resolved tree. Reconstruction and focused iPhone smoke must run on the resulting head; earlier green runs apply only to `77f9f10`. Hosted results remain pending.


### 2026-10-18 — Swift Testing macro rejects mutating lifecycle calls

- Failed run: [39103777006](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39103777006), iOS job `117605226475`, PR head `92e838c6fe7307d10eea9620832a00e5156a4038` (checkout merge `be14bbccc7b03b407ee37228db1ece3a49807fe0`). Deterministic test compilation failure; package execution never started. Android validation and focused iPhone smoke run `39103776922` passed; the unsigned iOS simulator app build also passed.
- Confirmed cause: six `#expect` expressions in `YouTubeVideoReferenceTests.swift` directly invoked mutating `YouTubePreviewLifecycle.close(_:)`. Swift Testing expanded the receiver into an immutable `$0`, producing `cannot use mutating member on immutable value`. This is test-expression incompatibility, not evidence of a runtime lifecycle failure.
- Repair: execute each close exactly once into a named Boolean before asserting the result. Preserve all stale-token, repeated-close, background and replacement assertions and production value semantics. No production, dependency, workflow or architecture change.
- Local verification: test-layout and presentation guards, unchanged assertion count, and bounded diff/whitespace review. Swift is unavailable in this execution environment; fresh hosted package compilation and execution remain required on the repair commit. No unchanged deterministic rerun.
- Follow-up: append green evidence only after the repaired head passes. Audio-focus coordination and native iOS lifecycle/device acceptance remain separate PR gates.


## Verified hosted checkpoint — October 18, 2026

Source `5c1b0f4eea9f92196b836a8bbf2980a5bb6793ad` passed reconstruction run [39106105837](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39106105837) and focused iPhone smoke run [39106105865](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39106105865). Reconstruction job steps confirm Swift package/test compilation, package execution, unsigned simulator application build, Android assembly/lint/domain regression, full native sanitizer gate and emulator runtime checks passed. This closes the earlier Swift Testing macro compilation failure after repair `1ca7454`; no assertions were removed. It also validates the subsequently added iOS/Android local-playing preview-entry guards on this source.

This is hosted evidence for the named SHA only. The smoke test is navigation coverage, not iOS native online-player lifecycle acceptance. General audio-focus/session arbitration, Android remote/asynchronous-start preview reconciliation, iOS runtime online lifecycle coverage and physical-device embed/interruption/ads acceptance remain open. No merge, signing, packaging, deployment or release is claimed.


## Verified controller-observer repair — October 18, 2026

Source `fa5dcbcf7aa070d924d86ed6c3e832af3618cebb` passed reconstruction run [39108033371](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39108033371): Swift package/test compilation and execution, unsigned simulator build, Android build/lint/domain/native sanitizers/browser interoperability and actual emulator runtime checks. The added KCP1 remote start/resume regression passed. Earlier Android-only run `39107996743` was cancelled by the superseding run, not a regression failure. Focused iPhone smoke run `39108033323` was still in progress at this checkpoint; no smoke, physical-device, signing or release result is inferred from reconstruction success.


## Verified Android audio-coordination checkpoint — October 18, 2026

Source `99f3898d35394a26d1879149c3f8637acd48ef56` passed reconstruction run [39108899667](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39108899667). Both Android and iOS jobs succeeded. Android native emulator execution includes the new effects/intermission/microphone/stale-owner/background/FIFO cases, plus the existing encrypted-remote start/resume cases. Swift package compilation/tests and unsigned simulator app build passed. Focused iPhone smoke run `39108899640` remained in progress at this checkpoint; its outcome is not inferred. This validates the Android candidate in hosted checks, not physical output timing, real YouTube media/ads or iOS audio-session parity. No merge/signing/release.
