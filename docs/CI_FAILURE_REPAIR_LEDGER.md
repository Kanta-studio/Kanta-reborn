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
