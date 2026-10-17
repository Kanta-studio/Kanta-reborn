# Engineering automation and repair contract

## Operating principle

An observed failure starts a repair workflow, not a status-only handoff. Never declare a fix without a committed change and evidence. Never merge or publish an unvalidated release automatically. Work on a repair branch and keep `main` deployable.

## State machine

`observed -> classified -> reproduced -> corrected -> locally-validated -> CI-validated -> merged -> release-verified`.

If a stage fails, record the failing command, commit SHA, platform, job/step, exact assertion, evidence URL and diagnostic fingerprint. Return to `classified` after a code change. Distinguish `blocked-external` (credentials, service outage, platform access) from `blocked-code` (must be investigated and repaired). Avoid claiming background progress when no worker is running.

## Root-cause workflow

1. Collect the failing job logs and XCTest/Android artifacts, then inspect the complete ownership and lifecycle of affected components.
2. Reproduce with the smallest deterministic test that asserts the user-visible behavior; do not add sleeps or repeated taps to hide races.
3. Fix the owning component and state transition. Review concurrent async updates, cancellation, idempotency, accessibility and failure recovery.
4. Add unit/state-machine coverage and an end-to-end regression that proves the original failure no longer occurs.
5. Run inexpensive static and package checks first, then one consolidated platform runtime validation on the final head. Re-run only if the head changes or a genuinely new failure is identified.
6. Merge only with the required checks passing. Generate IPA/APK and publish only after artifact integrity and distribution gates pass.

## Modal presentation contract (iOS)

The root coordinator owns mutually exclusive top-level destinations and their presentation lifecycle. Search, Queue, CONTROL, session prompts and fullscreen must not race to present competing modals. Playback state never drives navigation dismissal. Sheet dismissal is complete only after SwiftUI calls `onDismiss`; while dismissal is pending, controls that present another modal remain unavailable, with an accessible explanation rather than ignored taps. Model a single explicit route and transition phase; avoid independent booleans that can describe impossible combinations. Assert `Library -> playback -> Done -> Search -> keypad -> Cancel -> CONTROL` on both iPhone and iPad.

## Automation boundaries

GitHub Actions must use least-privilege permissions, concurrency limits, timeouts, pinned trusted actions and explicit release approval. Do not introduce unrestricted bot loops, automated workflow dispatch storms, secret printing or publication of unlicensed assets. Use read-only failure diagnostics and a bounded repair attempt; escalate when changes require account authorization, signing secrets, or policy decisions. A scheduled checker can report meaningful changes, but does not by itself execute repository fixes.

## Evidence and reporting

For each repair report: failing test and source line, root cause, files and commit SHA, validation commands and results, open blockers, and links to workflow and artifacts. Mark all unrun checks **not verified**. Never describe unsigned IPA as signed or downloadable production software.
