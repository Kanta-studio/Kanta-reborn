# KANTA reliability hardening handover

**Current status — 2026-10-07:** PR #25 merged as `beb63b5`; Core CI #130
passed on main; UI Screenshots #48 passed on its PR head. Manual TestFlight
run `37575087891` stopped at missing signing inputs, before archive/upload.
Read the final dated entry below for the release follow-up. Earlier pending
validation statements are historical, not current instructions.

## Status and source

Base inspected: `481e99c977ee75d1ad54eaeb2abe5546ea05bcdb` on
`usermalik20-del/Gelo-Karaoke-iOS/main`. This batch is proposed on
`fix/reliability-hardening-handover`; it is not a validated production release.

The owner requested gap fixes and a handover after every change. Each coherent
change below records the cause, implementation, verification, and remaining work.
Future commits must append an entry here (or link a dated successor), update
architecture when needed, and retain honest pending-validation labels.

The latest existing main CI run inspected was `37483308006`, for `a39bc9c`:
failed before any job step ran, with no runner assigned. The existing AGENTS
handover records exhaustion of the old account's 2,000 included Actions minutes.
No paid capacity, account settings, secrets, Apple identifiers, or deployment
settings were changed. Do not repeatedly retry that run.

## Change 1 — explicit completion and playback identity

**Cause:** completion was inferred from the preceding UI snapshot being within
1.5 seconds of the end. Manual Next near the end could produce a false score;
delayed polling could miss a real completion. Consecutive reservations of the same
song did not rebuild the scoring session because presentation used only song ID.

**Implementation:** both AVFoundation adapters now expose `didFinishNaturally`,
set only by their actual playback completion path and cleared by load/play/stop/
seek. The authoritative controller retains a `KaraokeCompletion` and assigns a
UUID to each playback run. Optional snapshot fields keep old v2 snapshot decoding
compatible; older peers ignore added JSON fields. Scoring consumes new completion
IDs matching its prior run. Host rebuilds per playback UUID, prevents overlapping
snapshot refreshes, and timestamps playback anchors before awaiting metadata.

**Coverage added:** delayed polling, manual skip at 59,999/60,000 ms, pause/seek,
repeat-song completion, once-only delivery, legacy JSON decoding, repeated song
reservation, and concurrent completion polling. Swift tests are written but NOT
executed in this Linux workspace (Swift/Xcode absent).

**Next:** run Swift tests, then verify natural completion, replay, same song twice,
manual Next, seek-to-end, pause/resume, and supported/unsupported scoring on device.
Do not treat this as microphone accuracy or hardware-latency proof.

## Change 2 — serialized queue transitions and failed handoffs

**Cause:** Swift actors are reentrant across `await`; simultaneous Host/Remote
polls or commands could load the same reservation more than once. Failed automatic
handoffs retried on every poll without surfacing an error. A failed adapter play
could leave the engine on an asset that the controller had not committed.

**Implementation:** an actor-owned continuation gate serializes controller
commands/snapshots across async engine/library calls, without blocking a thread.
Queue transitions share one implementation. Failed automatic items are retained,
reported through `playbackError`, and suppressed from repeated automatic retry.
Manual Next explicitly retries. Failed engine preparation stops playback and marks
the committed song for reload on Play; snapshots do not expose an uncommitted asset.

**Coverage added:** 20 concurrent snapshots advance exactly once; failed handoff
load count remains bounded over repeated polls; manual retry; failed Next/play
keeps the queue and restores the committed song on Play. Not executed yet.

**Next:** validate multiple paired remotes plus rapid local commands. Check pause/
stop responsiveness while a large asset is preparing; commands are serialized, so
cancellation of a synchronous AV sampler load is not claimed.

## Change 3 — SoundFont prewarm/cache safety

**Cause:** opportunistic prewarm could change the live sampler during playing or
paused audio. A failed sampler load retained a potentially invalid cache identity.
A working fallback could still be preceded by another expensive preferred-bank
failure on each song.

**Implementation:** public prewarm runs only while stopped; song load uses its own
actor-isolated synchronous loader. Invalidate loaded identity before a mutating
bank load. Cache the resolved candidate chain and its metadata so an unchanged
successful fallback stays hot; changed paths/metadata trigger reevaluation. Keep
case-sensitive paths distinct. User preference is not rewritten.

**Verification:** source review only; no valid redistributable SF2 is bundled and
no physical-device memory test was available.

**Next:** use an authorized SF2: play/pause while changing preference, repeat songs,
modify/switch banks, force primary load failure, inspect actual fallback audio,
and profile iPhone XR/iPad 9th-generation memory. Large-file size is not a memory
budget; this does not guarantee near-1 GB banks fit. Do not claim universal GM
multitimbral fidelity from the sampler API alone.

## Change 4 — verified iCloud replacement and stable backup paths

**Cause:** the prior backup was deleted before copy/verification; display-name
paths collided; stale scan sizes could incorrectly reject a changed source; lexical
path normalization alone did not reject symlink escapes. UI implied completed
cloud upload when it had only prepared local ubiquitous files.

**Implementation:** `LibraryStorage/VerifiedLibraryBackup` validates resolved source
boundaries, copies to a sibling temporary file, checks fresh source size/mtime and
copied size, then replaces the destination. Existing data is untouched by read,
copy, or verification failure. iCloud coordinates source reads/destination writes.
Backup folders use stable registry UUIDs. Reentrant backup requests are rejected;
stale results are cleared. UI says prepared/submitted, with iOS upload timing noted.

**Migration:** old display-name backup folders are intentionally left intact; this
batch does not delete or migrate them. The first UUID-based backup may require
additional iCloud space. Byte count/mtime checks are not cryptographic hashing.

**Coverage added:** successful replacement, missing-source failure preserving the
previous backup, temporary cleanup, parent traversal and symlink escape rejection.
Tests not executed yet. Signed iCloud provisioning remains unverified.

**Next:** run storage tests on macOS and signed-device acceptance with Files/iCloud
providers; test interrupted/network-unavailable backup, equal display names,
source changes, stale bookmarks, and insufficient storage. No claim of transactional
all-library backup or whole-library restoration is made.

## Change 5 — privacy metadata and reproducible validation

**Cause:** the manifest listed no required-reason APIs despite settings and file
metadata use. Screenshot workflows had no manual trigger, and draft changes could
consume scarce macOS minutes.

**Implementation:** declare UserDefaults `CA92.1`, file metadata `C617.1`/`3B52.1`,
and timing `35F9.1`. Privacy guard now uses portable Python plist parsing and checks
these categories. Both workflows support manual dispatch, cancel superseded runs,
and skip macOS jobs for draft PRs; Ready for review triggers validation.

Apple references checked:
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons

**Passed here:** commercial asset guard, media provenance guard, privacy guard,
release metadata guard, YAML parsing, shell syntax, and git whitespace checks.
**Not run:** Swift package tests, XcodeGen, Release/Debug simulator compilation,
simulator screenshots, physical device playback, or signed iCloud/TestFlight.
No claim of App Store approval or a complete binary privacy audit.

## Exact next validation sequence

1. Verify destination repository/history and Actions allowance after transfer.
2. Open this existing draft PR in the destination and mark Ready for review once;
   do not create an empty commit or repeatedly trigger workflow runs.
3. Require both Core CI and screenshot jobs. Inspect concrete compiler failures and
   fix them coherently. Keep `swift test` plus Release build and Debug screenshots.
4. Once workflows exist on default branch, manual dispatch is available for future
   validation. Before merge, Ready for review is the intended validation trigger.
5. Inspect the four actual screenshots (phone/tablet CONTROL/fullscreen).
6. Merge only after required checks pass. Update this handover with run URLs,
   exact commit, results, and any remaining failures. Skip is not pass.
7. Complete authorized indexed-library/SF2 acceptance and physical-device scoring/performance.
8. Complete AppIcon, signed iCloud, LAN encryption, Apple signing/TestFlight and
   commercial interoperability review before public release claims.

## Explicit remaining gaps

- No successful post-batch iOS app build yet.
- Matching current indexed-library library acceptance still required; strict decoder unchanged.
- LAN TCP remains PIN-authorized but unencrypted; trusted LAN only.
- No measured low-end-device memory, thermal, battery or audio latency results.
- No final production AppIcon, signed iCloud validation, TestFlight or App Store release.
- No hardware or cloud validation was simulated by a mock or generated screenshot.

These blockers must remain visible. Continue hardening, not feature expansion.


## Transfer update — 2026-10-06 23:52 Asia/Manila

The owner confirmed transfer to **kanta-gelo/Gelo-Karaoke-iOS** and that Actions
capacity is available again. Repository ID 1406435710 and draft PR #25 were
verified under the new owner. Prior-account exhaustion above is historical;
the new account's exact remaining balance has not been independently queried.

Standing owner instruction: conserve GitHub Actions minutes from now on.
Batch coherent changes, inspect existing source/logs before running CI, avoid
empty commits and duplicate runs, and rerun only jobs needed for a concrete
failure. Keep draft work from consuming macOS jobs. Use one deliberate validation
cycle when ready. Never enable paid usage or alter billing limits without approval.
Continue leaving a per-change handover with verification and next steps.

This update changes documentation only. PR #25 remains draft; no build or screenshot
job was intentionally started for this note. Next engineering step is the single
post-transfer validation cycle described above, then concrete failure fixes.


## One-run validation update — 2026-10-06 23:54 Asia/Manila

Owner instruction for tonight: **only one CI attempt**, then pause until tomorrow.
The screenshot job is now explicitly opt-in via the `capture-ui` PR label (or
manual dispatch). It retains all build/capture steps. This prevents marking PR #25
Ready for review from starting a second macOS build. No screenshot label is added.
Ready for review tonight authorizes only Core CI: guards, Swift tests, XcodeGen,
and the Release simulator build. No retries, screenshots, merges, or follow-on
production runs tonight, regardless of result. This overrides the earlier
recommendation to trigger both workflows together. Tomorrow inspect this one
run's result/logs first and continue with the smallest necessary follow-up.

Validation for this workflow change: reviewed event/condition logic. Screenshot
checks skipped without the label are not visual acceptance. Existing regression
and release gates remain in force. The single run URL/result can be recovered
from PR #25 Checks; no code is pushed during the run to avoid cancellation or
an accidental additional attempt.


## Backup metadata correction — requested 2026-10-06 23:59 Asia/Manila

Owner authorized fixing the failure now and explicitly deferred testing until
tomorrow. PR #25 was returned to draft before editing. This commit uses
`[skip ci]` as an additional safeguard; no tests or hosted retries were requested.

**Observed:** Core CI #109 (run 37491611299) compiled the Swift packages and ran
108 tests; 107 passed and the backup replacement test threw Cocoa error 259.
The Release iOS app build was not reached. Controller/scoring regressions passed.

**Source diagnosis:** the backup's initial metadata snapshot used the supplied
URL's cached resource values; only the post-copy snapshot was refreshed.
Reusing the source URL after rewriting the source (as the failing test does)
can compare an old size/mtime with fresh values and reject a valid copy.
This is a concrete cache-consistency defect compatible with the failure.
The existing log did not identify the exact failing copy/guard, so the hosted
confirmation remains pending.

**Change:** one helper explicitly clears cached/temporary URL resource values
before all three verification reads: source before, source after, and temporary
copy. Verification and prior-backup preservation remain intact. Split the
source-changed and copy-size errors into descriptive messages so a future failure
identifies the violated condition instead of only returning generic error 259.

**Regression coverage:** the existing replacement test deliberately warms source
metadata before its different-size rewrite. A new same-size rewrite test uses
controlled modification dates to cover stale timestamp metadata independently.
No sleeps, weakened assertions, removed verification, or replacement of prior
backup before verification.

**Validation:** source/diff review only. Per owner instruction, no test execution
or second CI attempt tonight. Tomorrow remove draft status once to validate the
new head; do not rerun #109 because it tests the old commit. Keep the
`capture-ui` label absent so screenshots do not consume another build.
If backup tests pass, let that same Core CI run reach the Release app build.
Do not merge or claim a passing correction until the new run succeeds.

Apple cache behavior reference:
https://developer.apple.com/documentation/foundation/url/removeallcachedresourcevalues()


**CI skip-marker clarification:** correction commit `2c35dfd` and this note use
`[skip ci]`; do not assume changing draft status alone will run those commits.
On tomorrow's authorized continuation, review the correction and update this
handover with the actual validation scope/status in a normal documentation commit
without a skip marker while the PR is still draft. That is a substantive handover
update, not an empty CI-trigger commit. Then mark Ready for review once. Keep
screenshots opt-in and do not rerun the obsolete failing commit.


## 2026-10-07 Manila — whole-codebase review, no CI run

Owner scope: all codebase, fix concrete issues before CI, preserve Actions quota,
and leave a handover for each coherent change. The latest explicit test timing
is **test tomorrow**. This batch stays on draft PR #25, uses `[skip ci]`, and does
not start or schedule any workflow. The four portable static guards are not a
Swift test run. Future work must not interpret this handover as authorization to
retry CI repeatedly.

### Change A — app wiring and microphone lifecycle

Files: `KantaUserSettings`, `HostViewModel`, `LibraryViewModel`,
`MicrophonePitchMonitor`, `AutocorrelationPitchDetector`, `KaraokeScoring`.
Added explicit Combine imports for ObservableObject/@Published app-only files.
A capture generation invalidates permission continuations and queued samples on
stop, prevents duplicate starts, and honors task cancellation. Timestamp capture
precedes pitch detection. The Bluetooth option uses the iOS 17-compatible API
spelling. Reject nonfinite pitch inputs before integer conversion, and publish
live score aggregation on the existing snapshot cadence rather than every mic
buffer. Regression cases cover nonfinite detector/observation inputs.
Check next: turn scoring off while permission is open, deny/regrant, navigate
away, and verify no capture/observation after stop on a physical device. Confirm
routing, latency, and CPU usage; the detector still runs in the audio tap.

### Change B — storage commit and reload boundaries

Files: `LibrarySourceRegistry`, `BookmarkedKaraokeLibrary`, `AppServices`,
`HostViewModel`, storage regression tests.
Persist proposed registry records before exposing them in memory; quarantine
valid JSON with duplicate source IDs. Rebuild active sources/catalogs without
awaits after reading the registry; reject superseded reloads. Register acquired
security scopes before bookmark refresh can throw. Persist only refreshed
bookmark data afterward, without recreating deleted records or overwriting newer
scan/preferences. Deduplicate catalog IDs and isolate temporary cache roots per
library instance. Startup/Host share `loadIfNeeded` so Host reentry does not
remove a currently used legacy cache file. Added failed-upsert/remove, duplicate
ID, and removed-source bookmark regressions.
Check next: repeated Host entry, concurrent import/reload, stale bookmarks,
removed provider folders, and playback while explicitly rescanning/removing a
source. Explicit reload still invalidates caches; playback/provider coordination
under source removal needs device acceptance.

### Change C — provider paths and import responsiveness

Files: `BookmarkedKaraokeLibrary`, `LooseMediaCatalog`, `DirectoryLibraryScanner`,
`LibraryViewModel`, catalog tests.
Reject embedded NUL paths, enforce canonical symlink containment at media access,
and strip only the leading scan root prefix. Validate import destination folders
inside the selected root. Copies use provider coordination plus verified
byte-preserving temporary copies on a utility task. Scans likewise leave the
main actor; security scope remains held through the await. Prevent concurrent
import/rescan operations. No transcoding or source mutation. Added NUL-path test.
Check next: Files/iCloud providers, large SF2 imports and cancellation, same-name
imports, quota/full disk, symlink replacement races and import error UI. Scanner
provider enumeration errors and memory/cache limits remain follow-up review areas.

### Change D — playback and SoundFont boundaries

Files: both AVFoundation playback adapters, `PlaybackTimeline`, library resolver,
timeline tests.
MIDI seek/pitch while paused no longer restarts notes; repeated Play while already
playing is inert. Stop/pause release sustain and all voices. Refresh SF2 identity
metadata before reading it. A missing preferred SF2 reaches the adapter fallback
chain; invalid fallback candidates are skipped. Saturate time/frame conversions
before converting floating-point values to integers. Added extreme elapsed/rate
regression case.
Check next: macOS compilation, iOS Release build, generated-file seeking at
extreme positions, held/sustained notes while paused, and real user SF2 fallback
and multitimbral fidelity. No bundled SF2 or claim of real-bank validation.

### Change E — remote callback ownership

Files: `RemoteHostClient`, `BonjourHostBrowser`, `BonjourHostAdvertiser`.
Each connection/browser/listener lifecycle has a generation. Ignore obsolete
state, receive, result and send-completion callbacks. Reject obsolete incoming
connections; disconnect clears projected remote snapshot/search state. Only a
pairing session accepts pairing success and only a paired session accepts a
snapshot. Stop processing an envelope batch if it closes the current session.
Check next: rapid connect/disconnect/reconnect and Bonjour start/stop with two
real devices. Existing protocol unit tests do not simulate Network.framework
callback ordering. Encryption, pairing timeouts/rate limits and session-count
bounds remain release-hardening work; this batch does not claim LAN secrecy.

### Change F — binary parsing and span bounds

Files: `StandardMIDIParser`, `BinaryCursor`, `ContainerPayloadResolver`, parser tests.
Index sliced Data relative to its startIndex, reject spans beyond the actual blob
size, and cap prefix reads before converting UInt64 sizes to Int. Added sliced
MIDI/cursor and externally supplied UInt64.max-span regressions.
Check next: run the synthetic compatibility suite. Real current indexed-library acceptance
is still pending. protected payload materialization currently expects decoded MIDI; unsupported
variants must stay fail-closed pending fixtures/format evidence.

### Review coverage and validation

Repository-wide source review covered App/Features, Core control/queue/MIDI/
playback/network/scoring, Infrastructure storage/legacy compression/playback/
microphone/LAN, package tests, Config, Package.swift, project.yml, workflows and
release guards. This is a static review, not proof that every execution path is
bug-free. Remaining gates include AppIcon, signed iCloud, real indexed-library/SF2 fidelity,
XR/iPad 9 performance, microphone routing, LAN confidentiality and screenshots.

Actually executed this batch: `git diff --check`, Config plist parsing, commercial
asset guard, media provenance guard, iOS privacy guard, release metadata guard.
All passed. Ten new Swift regression cases are written but **not executed**.
No Swift/Xcode installed here; **zero new CI runs, no Swift tests, no merge**.
Last hosted result remains run 37491611299: 107 passed, one backup test failed,
and the app build was not reached. The earlier cached-resource-values correction
is preserved and still awaits confirmation.

Next authorized validation: review the final head, add a substantive handover
update without `[skip ci]` while draft, then start **one Core CI** on that head.
Do not rerun the old failing SHA. Keep `capture-ui` absent. Let the same run reach
the Release iOS build if package tests pass. Inspect its result before further
Actions spend; leave the PR unmerged until actual validation succeeds.


## 2026-10-07 Manila — legal branding and implementation-based privacy notice

Owner requested stronger legal wording, the correct app name, and a privacy
notice based on actual behavior. No new CI authorization was given.

**Change:** `LegalView` is now the canonical notice used by the modal
`LegalDisclosureView`; removed the divergent duplicated disclosure. Root entry
points and the screen title say **Legal & Privacy**. Brand constants identify
**KANTA — ᜃᜈ᜔ᜆ** / **KANTA**; no corporate or registered-trademark claim is
invented. Internal bundle/module identifiers remain intact.

The notice explains BYOL, possession versus copyright, separate public-use rights,
third-party non-affiliation, compatibility versus rights clearance, and mandatory
rights. Privacy copy follows source inspection: local microphone buffers (no
recordings/uploads), folder references and scan metadata, settings, temporary
legacy playback files, optional selected-category iCloud copies, provider sync,
PIN-paired plaintext LAN metadata, current absence of developer analytics, and
retention/deletion controls. It explicitly avoids the former false blanket “no
media uploads” claim and does not invent an in-app cloud-deletion feature.

**Docs:** corrected README/commercial/media/privacy claims; updated the stale
“no required-reason APIs” privacy review to match the existing manifest. Updated
architecture for one notice owner, feature docs and release checklist. Public
policy URL, verified publisher/contact, trademark/interoperability review and any
custom EULA remain release gates; these disclosures are not legal clearance.

**References:** IPOPHL copyright FAQ and Apple's custom-EULA minimum terms and
App Review privacy guidance (links in commercial/privacy docs). No third-party
terms were copied into the app or represented as KANTA's own EULA.

**Validation:** source-to-copy review, brand/duplicate-notice search,
`git diff --check`, commercial/media/privacy/release static guards. No new Swift
tests for this copy/presentation change. Swift/iOS rendering and VoiceOver/Dynamic
Type review remain pending the next authorized hosted/device validation. Keep the
PR draft and commit with `[skip ci]`; no workflow or merge requested.


## 2026-10-07 — Filename-neutral interoperability hardening

- Runtime SF2 import is now vendor-neutral: any filename is allowed when the
  selected file has a valid RIFF/SoundFont structure.
- Automatic SoundFont selection no longer contains a vendor-specific filename
  preference. Explicit user choice wins; otherwise normalized path order is
  deterministic.
- Indexed-library detection no longer depends on historical filenames. The
  scanner structurally identifies a candidate index, requires exactly one safely
  correlated media container, and samples bounded payload prefixes before
  publishing the catalog.
- User-facing UI, Host empty-state copy, legal copy, and public documentation now
  use neutral terms such as compatible indexed library, library index, media
  container, and SoundFont.
- The commercial asset guard is distribution-only. It blocks tracked karaoke
  media/SoundFonts from shipping with KANTA but never inspects or rejects a
  user's Files/iCloud runtime imports.
- Low-level constants that are technically required for compatibility remain
  isolated behind the private compatibility facade and are not product identity
  or App Store metadata.

Validation pending: no hosted CI was triggered for this documentation/code batch.


### Follow-up — neutral API test alignment

The indexed-container catalog regression tests were aligned with the renamed
`containerURL` API label after the main neutralization commit. This is part of
the same batch and did not trigger hosted CI.

Raw low-level format identifiers remain only inside the isolated
`LegacyCompatibility` implementation/tests where they are required to recognize
and validate the compatible byte format. Product UI, marketing copy, public
documentation, storage/catalog APIs, and distribution guards no longer depend on
third-party product names or historical filenames.


### Neutral developer tooling follow-up

The old format-specific probe entry point was replaced by
`kanta-container-probe`. It reports only neutral index/container structure and
bounded recognition status through the compatibility facade; the obsolete probe
source was removed. No hosted CI was triggered.


## 2026-10-07 — Apple release-prep completion batch

Code-side release preparation was completed on the reliability branch before the
single hosted validation run.

- Added the iCloud Documents ubiquity-container entitlement required by
  `FileManager.url(forUbiquityContainerIdentifier:)`.
- Added a destructive, confirmed **Delete KANTA iCloud Backup** action. It removes
  only `Documents/KANTA Backup` in KANTA's private iCloud container plus KANTA's
  iCloud key-value settings entry; original user-selected Files/iCloud folders are
  outside the deletion boundary.
- Added an explicit `ITSAppUsesNonExemptEncryption=false` declaration for the
  current Apple-system/exempt crypto posture. Re-review is mandatory if crypto
  dependencies or transport implementation change.
- Added canonical public `PRIVACY.md`, `SUPPORT.md`, and App Store metadata
  guidance; no seller identity/private contact was invented.
- Hardened release validation to require the AppIcon, exact 1024×1024
  nontransparent PNG properties, iCloud Documents entitlements, and export
  declaration.
- Screenshot CI remains opt-in, but now selects an App-Store-appropriate
  Dynamic-Island Pro Max iPhone and 13-inch/accepted 12.9-inch iPad class and
  verifies captured dimensions before publishing artifacts.
- Core CI now fails hosted release validation if the Xcode major version is below
  26, matching Apple's current upload requirement.

Run one Core CI on the exact final head. Do not mark the PR green or merge until
that run succeeds.


## 2026-10-07 — Compact Host UI follow-up

Screenshot CI exposed two release-facing UI defects on compact iPhone:

1. the global SwiftUI searchable bar covered the bottom of CONTROL/queue content,
   while wide Reserve/queue controls could force rows beyond the safe List width;
2. Baybayin appended directly to functional control labels depended on a system
   fallback font whose visual result was inconsistent with the surrounding
   KANTA typography.

Fixes in this batch:

- CONTROL now owns the only visible Host search field; the global searchable
  overlay was removed.
- expanded CONTROL receives explicit List insets and a width-bounded frame.
- search rows preserve song-title width and fall back from **Reserve + icon** to
  an icon-only reserve action when horizontal space is tight.
- queue rows prioritize title width over the remove action.
- pitch/tempo cards stack automatically when the horizontal pair does not fit.
- the duplicate nested CONTROL heading was removed.
- functional labels are Latin-only; Baybayin strings remain separately available
  in `KantaTerminology` for deliberate brand surfaces.

Validation target: one screenshot CI capture on iPhone/iPad, followed by one
Core CI run on the same final head before PR #25 is marked ready/merged.


### Final compact-UI validation request

PR #25 is ready for hosted validation on the completed compact Host UI batch.
Run the screenshot capture and Core CI against this same head. Do not merge on
a screenshot-only pass: require the Swift package tests, release simulator build,
and screenshot dimensions/capture to succeed together.


### Screenshot follow-up — reserve action sizing

Screenshot CI #43 confirmed the global search overlay and Baybayin control-label
issues were resolved, but exposed a SwiftUI measurement regression: the adaptive
Reserve action expanded vertically to the full search-result row height on both
iPhone and iPad.

The Reserve action now branches on horizontal size class instead of using
`ViewThatFits`: compact iPhone gets a fixed 38-point circular plus action;
regular-width iPad gets a fixed-size labeled Reserve button. This keeps each song
row compact and prevents vertical pill stretching.


### Final validation request after reserve-control correction

Run Core CI and KANTA UI Screenshots on this same head. The prior screenshot
regression was limited to Reserve button sizing; do not merge unless compact
iPhone rows remain compact, iPad labeled Reserve controls remain bounded, and
the existing fullscreen lyric hierarchy is unchanged.


### Screenshot follow-up — iPad bordered-button stretch

Screenshot CI #44 confirmed the compact iPhone Reserve controls are now correct,
but the regular-width iPad branch still inherited SwiftUI's bordered-button
vertical expansion inside the nested List row. The iPad Reserve control now uses
the same explicit, plain-button sizing strategy as compact iPhone: a fixed
38-point-high custom capsule with no system bordered style. This removes the
feedback loop that inflated song-result row height.


### Final validation request after iPad sizing correction

Run Core CI and KANTA UI Screenshots on this head. Acceptance requires compact
iPhone search rows, bounded labeled iPad Reserve controls, unchanged fullscreen
lyrics, and all existing release/test gates green.


### Screenshot CI #44 visual review follow-up

The successful #44 artifact was manually reviewed after capture. Compact iPhone
layout is correct and fullscreen lyric hierarchy remains intact. The artifact
still showed two presentation defects on iPad: the labeled Reserve capsule was
visually stretched despite intrinsic sizing, and the navigation brand rendered
Baybayin through an inconsistent fallback font.

The final correction makes regular-width Reserve geometry explicit at both the
button and label boundary (104×38 points) so parent-row proposals cannot stretch
the capsule. System navigation branding now renders plain `KANTA`; Baybayin
strings remain available only for deliberate artwork/screens that provide a
verified supporting font. Re-run screenshot and Core CI on one common head before
merge.



## 2026-10-07 — Release workflow, public pages, and acceptance boundary

Base: `beb63b5a4a4d8284705ceb7f12fcaf144cd05401` in
`kanta-gelo/Gelo-Karaoke-iOS`. This entry describes the follow-up batch, not a
successful signed release.

Implemented:
- Manual TestFlight now uses Linux signing-input preflight before allocating a
  macOS runner. Uploads require main; credentials are step-scoped. API key
  discovery is explicitly wired through API_PRIVATE_KEYS_DIR.
- Ephemeral keychain passwords are generated/masked per job; the obsolete
  APPLE_KEYCHAIN_PASSWORD repository-secret requirement is removed. Cleanup
  addresses fixed temporary paths even when certificate installation fails.
- Unique run/attempt build numbers, explicit Xcode 26+ gate, pre-upload validation,
  internal-only export, and retained IPA/dSYMs improve release reproducibility.
- Six targeted Python regression tests cover input redaction, missing/invalid
  credentials, wrapped base64, version bounds/uniqueness, and internal-only export.
  Core CI and manual preflight run these tests.
- Public policy/support are deployed from reviewed static PublicSite files only.
  Deployment `dpl_BJwaB5WyWzzUacy3yVP1zeSYteMu` is READY on Vercel project
  `kanta-public` under GeloTech. Privacy and support both loaded in a browser
  without a sign-in prompt at https://kanta-public.vercel.app/privacy and /support.
  No source repository, credentials, or user assets were published.
- App legal links, public documents, metadata, privacy review, architecture, and
  roadmap use the public URLs. Support documents TestFlight feedback; a general
  public contact/publisher identity remains unverified and must not be invented.
- AGENTS.md is now current. The obsolete transfer handover is preserved in
  Docs/ARCHIVED_TRANSFER_HANDOVER.md as historical material.
- DEVICE_ACCEPTANCE.md supplies an exact-build evidence matrix. Every physical
  row remains NOT RUN. LAN_SECURITY_DECISION.md restricts the current release
  path to internal testing; authenticated encryption is NOT implemented.

Checks actually run before publication:
- Six release-tooling regression tests: PASS.
- All workflow YAML parsed; every embedded run block passed bash -n.
- Privacy, release metadata/AppIcon, commercial assets and media provenance guards: PASS.
- git diff --check: PASS.
- Public privacy/support navigation and visible policy content: verified in browser.
- New Swift compilation/signing/device acceptance: pending hosted CI/Apple inputs.

Next steps:
1. Inspect the follow-up PR's exact-head Core CI before merging; screenshot CI is
   unnecessary for URL-only changes to the existing legal screen.
2. Configure the six documented signing inputs securely in GitHub web settings.
   Confirm Apple App ID/container ownership and App Store Connect record/roles.
   Dispatch once on merged main; do not retry the old missing-input run blindly.
3. Confirm App Store Connect processing and use the internal build to fill the
   device matrix with actual evidence. Do not claim delivery just from upload exit 0.
4. Implement/review authenticated LAN transport and device results in a separate
   coherent batch. No public-shipment exception has been granted.
5. Verify publisher identity/general public contact and legal/privacy declarations
   before creating an external distribution path.

