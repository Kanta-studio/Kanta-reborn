# Release Readiness Checklist

**Current merged source baseline (October 10, 2026):** `kanta-ph/Gelo-Karaoke-iOS` `main`, merge commit [`6dcdf5f`](https://github.com/kanta-ph/Gelo-Karaoke-iOS/commit/6dcdf5f675572771f0377fe2197c2cee41b4bf5c), PR #44 merged and PR #40 closed as superseded. The last green Core CI ([run #38003895381](https://github.com/kanta-ph/Gelo-Karaoke-iOS/actions/runs/38003895381)) validated **173 Swift tests**, an unsigned Release iOS Simulator build, and live Host/CONTROL simulator startup on an earlier PR head; it **did not rebuild the final in-app Legal & Privacy edit or this merge commit**. KANTA has **no verified signed TestFlight upload or physical-device acceptance** for this merged batch. Website `/legal` and `/privacy` are live and were checked on production. Historical draft/pending paragraphs below record their original dates and must not supersede this status.


Status: **merged source; earlier-head simulator Core CI green; signed TestFlight and physical acceptance still pending**
Reviewed: **2026-10-10**

## Automated gate

Every pull request and push to main must pass:

- commercial third-party karaoke asset guard
- iOS privacy/permission configuration guard
- release metadata/AppIcon/iCloud entitlement/export-declaration guard
- Swift package tests
- Xcode project generation
- unsigned iOS Simulator build using the Release configuration

The hosted Release build proves that production optimization settings and
the generated project compile. It does not substitute for a signed
device archive.

## Versioning

Current product metadata is sourced from project.yml:

- bundle identifier: com.gelo.karaoke
- product name: KANTA
- marketing version: 0.1.0
- build number: 1
- minimum iOS/iPadOS: 17.0
- supported device families: iPhone and iPad

The manual upload workflow overrides CURRENT_PROJECT_VERSION with
`GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT` (e.g. 2.1). Each dispatch/retry has a distinct
build identity. Export keeps it unchanged. The project value remains the unsigned
baseline. Renaming/replacing the workflow requires reconciling its counter with
App Store Connect before upload. Marketing version changes remain reviewed source changes.

Current automated uploads are **TestFlight Internal Only**. External testing and
App Store submission require a separate reviewed release change after the device,
public-contact/legal, and LAN confidentiality gates are closed.

## Apple Developer setup

Use Apple Developer / App Store Connect and GitHub web settings; a local Mac is
not required for this workflow. Configure these six repository Actions secrets:

- APPLE_TEAM_ID
- APP_STORE_CONNECT_KEY_ID
- APP_STORE_CONNECT_ISSUER_ID
- APP_STORE_CONNECT_API_KEY_P8_BASE64
- APPLE_DISTRIBUTION_CERT_P12_BASE64
- APPLE_DISTRIBUTION_CERT_PASSWORD

APPLE_KEYCHAIN_PASSWORD is no longer required: the runner generates and masks a
temporary password. Linux preflight checks presence/shape before macOS allocation;
Apple still validates roles, certificate identity, provisioning, and agreements.
Do not retry missing-secret failures without changing the actual inputs.

The release owner must complete these account-bound steps:

1. register/confirm the App ID for com.gelo.karaoke
2. select the correct Apple Developer Team
3. configure automatic or managed distribution signing
4. create the App Store Connect app record
5. dispatch the manual workflow on main with upload_to_testflight=true; hosted macOS archives/signs
6. validate the archive
7. upload to TestFlight
8. complete App Privacy responses consistently with
   Docs/PRIVACY_REVIEW.md
9. use the canonical privacy/support URLs in Docs/APP_STORE_METADATA.md
10. confirm the App Store encryption questionnaire matches the shipping
    `ITSAppUsesNonExemptEncryption` declaration

No signing certificate, private key, provisioning profile, App Store
Connect API key, or account secret belongs in Git history.

## Additional SFX and DSP acceptance

- Exercise Stage Soundcard Phase 1 compressor, expander/noise gate, adaptive de-esser, short-delay doubler, preset switching and always-on limiter on actual wired/USB audio hardware. Confirm route changes mute vocal monitoring without affecting dry mic scoring.
- Exercise all eight Phase 2 procedurally synthesized party sounds from Host and PIN-paired Remote, bounded four-voice overlap, Stop All, level slider, short user-owned audio import, restore-original path, and invalid/oversize rejection.
- Confirm Phase 3 pitch correction and harmonizer remain visibly disabled, with no hidden mic processing or misleading release promises.
- Do not report simulator compilation as evidence of acceptable acoustic feedback, DSP quality or latency.

## Device acceptance gate

Follow `Docs/DEVICE_ACCEPTANCE.md`; all physical-device rows currently remain NOT RUN.

Before a commercial release candidate is promoted:

- iPhone playback: MIDI/KAR/MP3/WAV
- iPad split-view/orientation behavior
- VoiceOver, Dynamic Type, and Switch Control smoke tests
- microphone permission, scoring, latency, battery, memory, and thermal
  behavior on real hardware
- local-network permission, discovery, pairing, reconnect, and
  multi-controller behavior
- user-selected Files/iCloud library reauthorization
- corrupted registry/media recovery
- current authorized index/container protected payload acceptance
- preferred real SoundFont fidelity
- offline launch and operation after installation

## Security and legal gates

Still required before commercial shipment:

- close `Docs/LAN_SECURITY_DECISION.md`: internal-only distribution is the current boundary; authenticated encryption remains outstanding
- legal review of third-party-format interoperability
- final review of trademarks and user-facing third-party notices
- verify KANTA publisher legal identity/contact; privacy/support URLs are
  canonicalized in Docs/APP_STORE_METADATA.md and must remain publicly reachable
- verify applicable app license; review Apple minimum terms before adopting a custom EULA
- reconcile legal-screen copy with iCloud Save, Files-provider sync and LAN behavior
- verify no third-party karaoke content or SoundFonts are bundled
- confirm the App Store privacy disclosure matches the shipping binary
- confirm the export-compliance answer remains exempt before every release if
  cryptography/dependencies change
- capture at least one accepted Dynamic-Island iPhone screenshot and one accepted
  13-inch iPad screenshot before submission

## Release decision

A release is ready for external distribution only when the automated
gate is green and every applicable account-bound/device/legal item above
has an explicit pass or approved exception.

## October 2026 feature acceptance additions

All rows below are **NOT RUN on real hardware** unless a dated device acceptance record later supplies actual evidence:

- 47,998-title Files/iCloud import, title-only catalog status, 5-digit code lookup, large-library speed/memory and paginated Host/Remote search.
- Songbook native CSV Share sheet; known-artist display, local manual artist correction, app relaunch persistence, source-index reorder behavior.
- End Session → Save/Don't Save, Favorites persistence/rename/delete and Up Next requeue across app restarts, expired permission and missing songs.
- Live Vocal FX Dry/Room/Studio/Hall/Cathedral/Plate/Echo parameter response, wired/USB mic signal, level safety, route interruptions, feedback and karaoke/scoring latency.
- Two-device LAN pairing and unauthorized commands; the confidentiality gate remains **OPEN** until encryption or a formal trusted-LAN risk acceptance.
- Website /features, /support and /privacy publicly reachable and consistent with app disclosures after deployment.

A successful Swift CI #182 and Release simulator build on Soundcard PR #38 do not close signing, physical input/output, TestFlight or App Store Review gates.

## October 2026 stage and party-feature gate

Before internal TestFlight promotion, collect real-device evidence for
HDMI/USB-C external-screen scene creation and teardown, AirPlay
mirroring-versus-extension behavior, sung lyric sync on TV, input selection
and scoring coexistence, singer reordering across paired Remote, old
Favorites JSON migration and editable playlists, intermission audio fades,
and amplifier/USB audio-session routing. These are NOT RUN until the device
matrix is completed; a successful simulator build is not an audio
latency or external-screen acceptance test.

## Private website Songbook release gate (2026-10-08 draft)

- [ ] Run exact-head Swift Core and Release iOS Simulator; confirm new AES-GCM
      metadata-only export and UI compile with iOS 17 floor.
- [ ] Validate WebCrypto AES-GCM round-trip against actual exported file/code,
      including wrong code, damaged data, 48K+ entries and CSV quoting.
- [ ] Test mobile Safari (iPhone XR baseline) and desktop browsers, reduced
      motion, VoiceOver/keyboard navigation, page turning and large PDF print.
- [ ] Review absence of data uploads, logging, public catalog and client
      storage; manually test CSP and raw URL /songbook.
- [ ] Merge reviewed draft only after explicit owner permission to spend CI;
      deploy Vercel website separately and smoke-test routes/redirects.
- [ ] Confirm new phone-code instructions/privacy are accurate. Codes are
      neither expiring one-time passwords nor server-side account validation.


## New release gate — opt-in Filipino speech model (PR #44)

- [ ] Resolve WhisperKit 1.1.0 from the exact SwiftPM pin and build
      the iOS app (Swift tests alone are insufficient).
- [ ] Verify user-triggered install, optional ~147 MB model size plus
      tokenizer/cache, progress, actual Core ML loading, no automatic
      network traffic during normal karaoke, backup exclusion and
      model removal.
- [ ] Document Argmax MIT, converted model MIT and underlying Whisper
      Apache-2.0 licensing; audit actual source revision/hash provenance.
- [ ] Verify microphone permission and privacy disclosures, local
      transcription and deletion of temporary clips, Apple English
      online-recognition caveat, no leaked private library/audio.
- [ ] Test A12 iPhone XR and iPad 9 time-to-results, memory and
      playback/soundcard/score continuity after microphone route changes.
- [ ] Report Filipino/Taglish retrieval >=90% usable@3 **per cohort**
      before making accuracy claims.
- [ ] Capture iPhone/iPad UI showing same installed icon + in-app mark,
      correct palette, Voice Search, Settings download/remove flow and
      permission/denial states.


## PR #44 runtime evidence gate — 2026-10-09

- [ ] Resolve the pre-step runner failure on run 37858998365 from actual
      account/job annotations before allocating another macOS job.
- [ ] Run latest-head iPhone/iPad Host, CONTROL and fullscreen capture; require
      a live app at each capture and retain real iPhone orientation JSON.
- [ ] If the crash persists, inspect complete IPS/crashed-thread evidence and
      symbolicate against the exact app/dSYM uploaded by that failed run.
- [ ] Run the consolidated final Core CI on the corrected review head.

The crash-collection regression tests do not close any runtime or hardware gate.

## Integrated draft PR #44/#40 pitch acceptance — 2026-10-09

- [ ] One exact-head consolidated Swift Core + Release Simulator CI validation.
- [ ] Verify live Host/CONTROL/fullscreen screenshots without SIGSEGV.
- [ ] Validate 12 roots, five scales, correction amount/speed, mute/reset,
      input scoring independence, wired/USB route feedback and audio latency.
- [ ] Preserve prior Filipino/Taglish offline model, provenance, privacy,
      concurrency, iPhone XR/iPad 9 and signing release requirements.
- [ ] Check runner allocation and ensure merge-to-main does not consume
      unapproved additional macOS Actions. TestFlight dispatch is separate.

## Host startup/DSP follow-up — 2026-10-10 (draft PR #44)

- [ ] Verify cold Host/CONTROL launch and scrolling diagnostics without a microphone prompt, unexpected AVAudioSession activation or SIGSEGV on iPhone/iPad simulator.
- [ ] Confirm route observer is removed on diagnostics dismissal, reappears once on return, and diagnostics updates after hot-plug.
- [ ] Confirm persisted intermission track does not open an AVAudioPlayer until explicitly enabled, then plays/fades/stops/reopens after Host reentry; invalid audio is reported and no data is lost.
- [ ] Confirm finite-bound soundcard levels and old preferences via Swift Core regression tests; test all DSP route/gain behavior on real wired/USB hardware.
- [ ] Retain symbolicated crash artifact and matching dSYM if SIGSEGV persists. Current change is not proof of its root cause or correction.

## Single-Core-CI runtime smoke gate — 2026-10-10

- [ ] On the final review SHA, one owner-authorized Swift Core CI executes package tests, Release simulator build **and live Host/expanded CONTROL iPhone launches in the same macOS job**.
- [ ] The two saved screenshots must show KANTA (not SpringBoard), and simctl termination must prove the app remained alive after each screenshot. A crash/failure retains matching app+dSYM and bounded IPS/log evidence; no report is not proof of no crash.
- [ ] The separate full iPhone/iPad Debug screenshot workflow is not implicitly covered, authorized or passed by this Release smoke. Physical and signing gates remain NOT RUN.

## Host SIGSEGV root-cause acceptance — 2026-10-10

- [x] Retain a real exact-commit Host simulator IPS and symbols from one Core CI: artifact 11650380721, run 38002988380.
- [x] Identify frame evidence: main-thread stack-guard SIGSEGV with recursive `KantaIntermissionMusic.volume.didset/setter` from StateObject initialization.
- [x] Stage source fix removing self-assignment in the `@Published` observer and adding explicit bounded/persistent setter plus source guard.
- [ ] **NOT YET VALIDATED:** new-head Core tests, Release Simulator, and actual Host + CONTROL process-liveness smoke; no automatic third CI attempt.
- [ ] Full opt-in iPhone/iPad screenshots and physical audio/route testing; signing and TestFlight remain separate.

## Customer-facing web and app legal update (2026-10-10)

- [x] Stage user-friendly website Legal & Content Use and Privacy pages, with clear customer navigation and matching in-app Legal & Privacy summary.
- [x] Preserve disclosure of third-party rights, non-encrypted companion LAN, optional voice-model download, English Apple Speech, iCloud, private Songbook sharing and beta status.
- [ ] **Exact merged-head CI not run** after Swift Legal & Privacy view changes. The owner approved merging without an additional CI test; run #38003895381 passed on the earlier PR head.
- [x] Production /legal, /privacy and Home were fetched and checked after website deployment. Broader mobile Safari, desktop browser and accessibility reviews remain **NOT RUN**.
- [ ] Verify publisher identity, public support/privacy contact, App Store privacy answers and have qualified legal review before public app distribution.
- [ ] Signed TestFlight and hardware acceptance still required; publishing a static website does not release a signed iOS app.


## Merge and distribution reconciliation — 2026-10-10

- [x] PR #44 merged to main as `6dcdf5f`; PR #40 closed as superseded.
- [x] Core CI #38003895381 green on earlier source: 173 Swift tests, Release simulator build, live Host and CONTROL process survival; prior Host SIGSEGV fixed in observed simulator startup.
- [x] Customer website `/legal` and `/privacy` publicly deployed and direct-route verified.
- [x] Markdown release state reconciled; three current Word files generated against the merged source baseline (outside GitHub, in user's Library).
- [ ] Exact merged-head compile of new Swift Legal screen; no test run requested for this docs-only update.
- [ ] Apple signing credentials, signed internal TestFlight upload/build number, actual iPhone XR and iPad 9 device test matrix, real speech/copyright/privacy review, public support contact and release owner signoff.
