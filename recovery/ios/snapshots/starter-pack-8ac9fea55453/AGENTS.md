# KANTA engineering instructions

**Current merged source baseline (October 10, 2026):** `kanta-ph/Gelo-Karaoke-iOS` `main`, merge commit [`6dcdf5f`](https://github.com/kanta-ph/Gelo-Karaoke-iOS/commit/6dcdf5f675572771f0377fe2197c2cee41b4bf5c), PR #44 merged and PR #40 closed as superseded. The last green Core CI ([run #38003895381](https://github.com/kanta-ph/Gelo-Karaoke-iOS/actions/runs/38003895381)) validated **173 Swift tests**, an unsigned Release iOS Simulator build, and live Host/CONTROL simulator startup on an earlier PR head; it **did not rebuild the final in-app Legal & Privacy edit or this merge commit**. KANTA has **no verified signed TestFlight upload or physical-device acceptance** for this merged batch. Website `/legal` and `/privacy` are live and were checked on production. Historical draft/pending paragraphs below record their original dates and must not supersede this status.

**Documentation rule:** Treat `Docs/PROJECT_STATUS_2026-10-10.md` as the present-state ledger; do not copy old Oct 7/8 draft language into customer docs. Documentation-only commits must include `[skip ci]` and may not run macOS Actions; real implementation/merge code requires explicit owner consent for testing.


## Current source and verified baseline — 2026-10-08

- Main now includes KANTA Songbook codes/search and local CSV export (#36), saved session Favorites and manual artist corrections (#37), and optional wired/USB Vocal Soundcard (#38). The corresponding Swift Core CI + Release iOS Simulator runs #176, #179 and #182 passed before merge.
- **DO NOT** infer TestFlight signing, physical input/output testing, actual 47,998-title hardware import, playable protected media or encrypted LAN from those results.
- Latest source-of-truth feature inventory: `Docs/FEATURE_PARITY.md`; public docs: `PublicSite/`.
- This current note supersedes the dated PR #25 baseline below for the most recent feature scope.

## Archived 2026-10-07 baseline

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

## Proactive error recovery and FIFO execution

- When an error, failed check, runtime crash, regression, or deployment defect appears during an already-authorized implementation, **investigate and fix it immediately** as part of that same task. Do not require the owner to say "fix it" before acting. Keep the active task ahead of newly queued implementation requests unless the owner reprioritizes.
- Inspect diagnostics, identify a plausible cause, apply the smallest architecture-consistent fix on the existing working PR, and run a focused validation before restarting broader CI. Continue the original test → merge → deploy workflow only after release gates pass.
- If the failure is external (runner allocation, billing, credentials, signing, device-only acceptance), distinguish it from application defects, preserve evidence, and report the concrete blocker. Do not burn limited macOS minutes on blind reruns or claim an unverified fix is complete.
- Pauses are for genuine new approvals, missing permissions, irreversible actions outside granted scope, or safety/release gates; status requests alone must not replace authorized debugging work.

## Validation and CI conservation

- Inspect current head, PRs, and existing runs before editing; do not overwrite another agent's work.
- Review the affected subsystem and related failure modes, not only the first error.
- Batch changes on a non-production branch; avoid incremental CI-triggering commits and empty reruns.
- Run deterministic release-tooling tests and static guards first. One Core CI cycle on the finished batch; screenshots are opt-in for visual changes.
- A package-test pass is not an iOS app build pass. A simulator build is not signing, iCloud, physical audio, or TestFlight evidence.
- Every coherent change appends files/behavior, actual checks, blockers, and exact next steps to `Docs/HARDENING_HANDOVER.md`.
- Report written, pushed, CI-passed, merged, deployed, and device-tested as separate states. Never report plans or an empty hosting project as delivered work.

## Private Songbook architecture (draft branch)

PublicSite/songbook.* must never include user catalog rows or transmit an
imported .kanta-book, access code or searches. The page is only an encrypted-file
reader, not a server authorization service. The iOS exporter creates a fresh
random 128-bit hex code and AES-GCM encrypted metadata per file; WebCrypto
decrypts using the documented SHA-256 domain-separated key. Keep zero public
songs and no third-party JS. Do not reuse the six-digit LAN Remote PIN. Only
user-requested CSV/PDF export is plaintext. Ensure docs and public privacy text
match; validate secure browser and real phone before reporting shipping.


## Filipino speech pack (PR #44, draft)

- The owner approved a one-time *opt-in* multilingual Whisper Base
  download; keep it in the same FIFO PR #44 as the palette/AppIcon and
  title-first voice search until validated. No unattended CI runs.
- `project.yml` pins Argmax OSS WhisperKit 1.1.0 exactly for the iOS
  app target. Do not add model weights to Git, IPA, public website,
  iCloud Save, background asset bundles, or the domain Swift package.
- `KantaFilipinoModelStore` controls the download/preparation/cache,
  removable install marker and offline inference; `KantaFilipinoPackControls`
  is the Settings/Host/Songbook/Remote UI. `KantaFilipinoVoiceCapture`
  holds only an 8-second temporary mic clip. Keep native Apple English
  speech and scoring Soundcard routing separate.
- Never advertise 90–100% Filipino/Taglish recognition accuracy until
  `Docs/VOICE_SEARCH_ACCEPTANCE.md` is met with real XR/iPad 9 noise,
  accent and timing benchmarks; native Filipino iOS ASR is not
  universally available. No auto-reservation from recognized text.
- Verify license/trust of downloaded models and actual no-Internet
  second-session behavior; app privacy copy must reflect model host
  download metadata and Apple Speech online caveat.

## Mandatory concurrency and idempotency hardening — 2026-10-09

Apply this policy to EVERY subsequent feature, repair, migration, and release:
- Identify a single authoritative state owner. Review actor reentrancy at
  every `await`; actor isolation alone is not a multi-step transaction.
- Give retriable side effects stable request IDs and bound replay caches.
  Suppress the SAME request, not distinct intentional actions (for example,
  two singer reservations of the same song).
- Claim in-flight UI state before suspension for Save, import, queue-load,
  export, audio/model operations and other nonrepeatable workflows.
- Make cancellation promptly retire pending continuations, invalidate stale
  callbacks, and release files/audio resources only after consumers stop.
- Prefer actor-isolated atomic persistence; make retry identity durable where
  users can retry a completed action after reopening storage. Use unique
  temporary output files for concurrent exports.
- Include targeted concurrent/replay/cancellation/failure/restart tests in the
  same batch. Update `Docs/ARCHITECTURE.md` and `Docs/HARDENING_HANDOVER.md`
  for each behavioral contract or boundary change, not just this fix.
- Preserve FIFO and release gates: do not launch more paid macOS GitHub
  Actions while capacity is exhausted. Source checks are not simulator/device
  proof. Never merge/deploy a runtime-unverified crash fix as validated.

## Ongoing Soundcard integration contract — 2026-10-09

Monophonic pitch correction is optional, default-off, and upstream of
PR #44's compressor/expander/de-esser/doubler/reverb/echo/limiter.
Dry scoring remains upstream, and any unsafe output route hard mutes
monitoring and resets pitch. Keep older preference decoding functional.
Consolidation source checks cannot close the preexisting Host SIGSEGV or
physical-device acceptance. Preserve FIFO and one-CI-only authorization.
