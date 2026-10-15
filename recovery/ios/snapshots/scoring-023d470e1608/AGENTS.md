# KANTA engineering instructions

## Current source and verified baseline — 2026-10-07

- Repository: `kanta-gelo/Gelo-Karaoke-iOS`; production branch: `main`.
- PR #25 merged as `beb63b5a4a4d8284705ceb7f12fcaf144cd05401`.
- Core CI #130 passed on that merged commit. PR-head Core #129 and UI Screenshots #48 passed; 120 Swift package tests were reported in the accepted batch.
- Manual TestFlight run `37575087891` passed guards/tests/XcodeGen, then failed because signing inputs were absent. No signed archive, IPA, or upload was produced.
- Subsequent changes must earn their own validation. Do not carry baseline green status onto a changed commit.
- Read `Docs/HARDENING_HANDOVER.md` for the latest batch and `Docs/RELEASE_CHECKLIST.md` for release gates.
- `Docs/ARCHIVED_TRANSFER_HANDOVER.md` is historical; its pending-build claims and old repo identity are superseded.

## Product and architecture invariants

Read `Docs/ARCHITECTURE.md` before changing system boundaries. Update it in the same batch when boundaries change; update `Docs/ROADMAP.md` for milestone movement.

- KANTA is one-device-first, offline-first BYOL karaoke. Full local CONTROL remains primary; a companion remote is optional.
- `LocalKaraokeController` owns playback and FIFO reservations. Views, fullscreen, lyrics, and remote surfaces project its state; never add parallel queues/state machines.
- Natural completion auto-starts Up Next and captures an immutable score once per playback identity. Pause, manual Next, and repeated reservations of the same song must not create false scores or reuse a scoring session.
- Scoring defaults OFF. Microphone analysis stays in memory on device: no recording/upload. Ambiguous melody targets remain playable and unscored.
- Folder bookmarks and symlinks stay bounded to the user-selected root. Reject unsafe paths and unsupported indexed-container variants rather than guessing offsets.
- Source media/SF2 remains byte-preserved. No transcoding, resizing, whole-container import, or bundled user libraries. Follow `Docs/COMMERCIAL_DISTRIBUTION.md` and provenance guards.
- Large SF2 preparation must preserve control responsiveness, active playback, and selected preference; reuse a hot bank and retain bounded fallback behavior. Do not claim all 1 GB banks fit device memory.
- Runtime priorities: audio, controls/queue, lyrics, scoring, stage visuals. Reduce disposable visual workload first.
- Bundle `com.gelo.karaoke`, iCloud container `iCloud.com.gelo.karaoke`, deployment target iOS/iPadOS 17 remain stable. GitHub transfer/rebranding does not authorize changing Apple identities.
- Test baseline is iPhone XR and iPad 9th generation, plus newer supported hardware. A simulator screenshot is not device performance evidence.
- iCloud Save copies selected categories; large categories default OFF. Prepared files are not proof of completed upload. Delete only KANTA's private backup tree/settings, never source folders.
- Functional controls use Latin text; Baybayin requires deliberately supported artwork/fonts. Preserve the accepted compact iPhone and bounded iPad Reserve geometry.

## Release scope and security

The current manual workflow is INTERNAL TestFlight only. Its export settings must retain `testFlightInternalTestingOnly=true` until a separately reviewed release batch closes device, public-contact/legal, and LAN confidentiality gates. It does not invite testers or approve external release.

The current remote is PIN-authorized plaintext TCP for trusted LANs. Do not describe it as encrypted, expose it over the internet, or treat a PIN as confidentiality. See `Docs/LAN_SECURITY_DECISION.md` for the release decision and acceptance criteria. TLS/secure pairing implementation is still outstanding.

Signing inputs belong in GitHub Actions secrets, never chat, source, logs, or artifacts. The temporary keychain password is generated per job and no longer needs a repository secret. The manual workflow must fail its Linux preflight before allocating macOS when signing inputs are missing.

## Validation and CI conservation

- Inspect current head, PRs, and existing runs before editing; do not overwrite another agent's work.
- Review the affected subsystem and related failure modes, not only the first error.
- Batch changes on a non-production branch; avoid incremental CI-triggering commits and empty reruns.
- Run deterministic release-tooling tests and static guards first. One Core CI cycle on the finished batch; screenshots are opt-in for visual changes.
- A package-test pass is not an iOS app build pass. A simulator build is not signing, iCloud, physical audio, or TestFlight evidence.
- Every coherent change appends files/behavior, actual checks, blockers, and exact next steps to `Docs/HARDENING_HANDOVER.md`.
- Report written, pushed, CI-passed, merged, deployed, and device-tested as separate states. Never report plans or an empty hosting project as delivered work.

