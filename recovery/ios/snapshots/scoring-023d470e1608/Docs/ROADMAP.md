# Roadmap

## Current status — 2026-10-06

The offline playback path is implemented for loose MIDI/KAR/MP3/WAV,
including synchronized lyrics, local stage backgrounds, Host/Remote LAN
control, and playback-aligned live scoring. Legacy third-party karaoke container
compatibility engineering is complete for the proven offset-table +
protected payload v1 path: validated title offsets resolve selected spans lazily,
and protected payload v1 payloads are decrypted/inflated only on demand into a
temporary local playback cache. A matching authorized current
`media container` is still required for final real-library acceptance testing;
the older public sample is a different addressing/protection generation
and is deliberately rejected rather than guessed.

## Phase 0 — Reference analysis
- Catalog supplied APKs and library files. **Confirmed.**
- Map permissions, media formats, folder conventions, and LAN behavior.
  **Implemented for the paths required by current iOS parity; remaining
  opaque Android-only metadata is documented but not treated as a
  shipping dependency.**
- Document `index/container/meg*`, MIDI/KAR, and SoundFont findings.
  **Implemented for confirmed current `index/container` playback;
  unproven `meg*` variants remain fail-closed.**
- Feature-parity matrix. **Maintained.**

## Phase 1 — Native iOS foundation
- SwiftUI app shell. **Implemented.**
- Dependency composition/domain protocols. **Implemented.**
- Files/iCloud Drive folder import + persistent security-scoped
  bookmarks. **Implemented as Bring Your Own Library.**
- Commercial asset guard preventing tracked third-party karaoke payload binaries.
  **Implemented in hosted CI.**
- Shared bookmarked playback library. **Implemented.**
- Stable loose-file catalog/search. **Implemented.**
- Shared local controller. **Implemented.**
- Routed file/MIDI playback. **Implemented.**
- Host UI wired to actual imported songs. **Implemented.**
- Automated tests + iOS Simulator CI. **Implemented.**

## Phase 2 — Karaoke playback
- Standard MIDI/KAR parsing. **Implemented.**
- Tempo-aware lyric timing. **Implemented.**
- MIDI playback plan/state reconstruction. **Implemented.**
- SF2 output. **AVAudioUnitSampler baseline implemented; real-device
  fidelity validation with the user's preferred SoundFonts remains a
  release-validation task rather than a code blocker.**
- MP3/WAV playback. **Implemented.**
- Pitch/tempo/volume. **Implemented.**
- Host queue/transport UI. **Implemented with an inline non-obstructive CONTROL ᜃᜓᜈ᜔ᜆ᜔ᜍᜓᜎ᜔; second-device remote is optional.**
- Lyrics presentation/highlighting. **Implemented baseline with
  playback-synchronized previous/current/next cues.**
- Background photo/video. **Implemented baseline with deterministic local image/video resolution and muted looping Host presentation. UI is intentionally de-emphasized to a simple Background visuals toggle.**

## Phase 3 — Legacy library compatibility
- Decode legacy index metadata. **Complete for catalog/playback:
  version-tolerant title parsing plus the validated trailing offset
  table are implemented; unused opaque fields remain intentionally
  unnamed rather than guessed.**
- Map title-index/trailing table to `media container`. **Complete: strict
  cardinality/order/blob-bound validation and lazy per-record spans are
  implemented.**
- Direct-open existing container library. **Complete for the confirmed
  current format: native MIDI/WAVE/ID3-MP3 spans direct-open, and protected payload
  v1 spans use bounded AES-CBC + raw-DEFLATE materialization into the
  temporary cache. Unproven ZIP/GZIP/arbitrary variants fail closed.**
- Compatibility tests against representative fixtures. **Complete for
  the implementation boundary: synthetic byte-exact protected payload
  decrypt/inflate coverage, malformed/truncated cases, offset mapping,
  and fail-closed type-9/unsupported-layout tests are hosted in CI.
  Final acceptance against a matching authorized current encrypted
  library is tracked as release validation.**
- Conversion fallback only if direct-open is impractical.
  **Not required for the confirmed current format; retained as a future
  fallback for genuinely incompatible variants.**

**Phase 3 engineering status: complete.** The parser, validated
offset-to-blob mapping, bounded protected payload v1 materializer, catalog/playback
integration, failure policy, tests, and architecture documentation are
mergeable when normal Swift/iOS CI passes. Real-library acceptance is
a product-hardening gate and must use a matching authorized current
`index/container` pair; an older public sample must not be substituted
for that proof.

## Phase 4 — Unified Host + Remote
- Primary same-device CONTROL ᜃᜓᜈ᜔ᜆ᜔ᜍᜓᜎ᜔. **Implemented inline in Host with search, queue, transport, volume, pitch, tempo, and background toggle; it expands without covering the stage.**
- Host authoritative controller. **Implemented locally.**
- Bonjour/mDNS discovery. **Implemented with Network.framework host
  advertisement and Remote browsing.**
- Pairing/PIN or QR bootstrap. **Six-digit host PIN plus authenticated
  framed PIN exchange implemented; QR is optional polish.**
- Protocol v2 framed domain envelope. **Implemented with bounded
  length-prefixed JSON, version validation, and fail-closed sequencing.**
- second-device CONTROL search/queue/transport controls. **Implemented baseline:
  paired Remote supports bounded catalog search, enqueue/remove,
  transport, volume, pitch, tempo, now-playing, and queue state.**
- Multi-controller state synchronization. **Authoritative snapshots are
  consumed by paired remotes every 500 ms and after accepted commands;
  presence/conflict UX remains polish.**

## Phase 5 — Scoring and performance
- Microphone pipeline. **Local AVAudioEngine pitch monitor implemented
  with explicit permission/start; observations stay in memory and audio
  is not recorded/uploaded.**
- Pitch/timing scoring. **Implemented baseline: conservative MIDI target
  extraction feeds a playback-aligned live scoring session; Host
  presents overall/pitch/timing results and resets safely on seeks or
  pitch changes.**
- Latency calibration. **Playback/microphone clock alignment and bounded
  manual compensation implemented; automated per-device calibration
  remains real-device hardening.**
- Battery/memory profiling. **Pending real-device profiling and
  optimization of microphone/autocorrelation coexistence with playback.**

## Phase 6 — Product hardening
- Device compatibility floor. **Defined: iPhone XR and newer on iOS 17+, and iPad 9th generation and newer on iPadOS 17+. KANTA is maintained against current SDKs through iOS/iPadOS 27. Adaptive performance protects audio/control/scoring before visual effects, and user media is never recompressed to meet device limits.**
- Recovery/corrupted library handling. **Implemented baseline:
  unreadable registry state is quarantined as a preserved backup;
  failed asset resolution/load/play does not silently consume queued
  songs; controller state changes commit only after playback succeeds;
  and library/protected payload failures expose actionable messages. Broader
  real-device malformed-media acceptance remains a release test.**
- Accessibility and iPad layout polish. **Implemented baseline:
  adaptive NavigationSplitView shell for iPad, scalable stage sizing,
  VoiceOver labels/values for Host and Remote transport/volume controls,
  and lyric-first accessibility semantics. Real-device Dynamic Type,
  VoiceOver, Switch Control, and iPad orientation validation remain a
  release test.**
- Privacy/permissions review. **Implemented baseline: explicit privacy
  manifest, CI permission/privacy guard, microphone/local-network/Files
  data-flow review, and no unused sensitive permission declarations.
  Authenticated LAN transport is still plaintext and remains a Phase 6
  confidentiality hardening gate.**
- Third-party license audit. **Current runtime dependency inventory is
  documented and contains no vendored third-party runtime SDK/content.
  Commercial BYOL and third-party-format interoperability legal review
  remains required before release.**
- Current legacy-library acceptance. **Pending a matching authorized
  current `index/container` pair for end-to-end protected payload validation; the
  public 1.0.0 sample is intentionally excluded because its type-9
  addressing/protection generation differs from the supported format.**
- Signing/distribution. **Pre-signing pipeline implemented: release
  metadata is CI-validated, the generated iOS target builds under the
  Release configuration without signing, and the TestFlight/App Store
  acceptance checklist is documented. Apple Developer signing,
  physical-device archive validation, and upload remain account-bound
  release tasks.**



## 2026-10-06 reliability batch (proposed, validation pending)

Completion identity, controller transaction serialization, failed-handoff recovery,
SoundFont prewarm/cache safety, verified iCloud replacement, privacy reasons, and
manual/draft-aware CI are implemented on `fix/reliability-hardening-handover`.
Regression tests are added but have not run under Swift/Xcode. Do not mark these
release gates complete until hosted and hardware acceptance succeeds.
See [the per-change handover](HARDENING_HANDOVER.md) for next steps and remaining gaps.


## 2026-10-07 repository-wide review (Manila)

A further hardening batch covers app imports, storage transactions/reload scope,
import responsiveness, microphone cancellation, remote lifecycle callbacks,
paused MIDI behavior, SoundFont metadata/fallback, parsing and numeric bounds.
Ten regression cases were added. Static guards passed; Swift tests and the iOS
app build are deliberately deferred per owner instruction. Core CI #109 remains
107/108 passing; its backup correction has not been confirmed by a new run.
Do not close release gates based on this source review.



## Current release milestone — 2026-10-07

PR #25's simulator/UI validation is complete at baseline beb63b5. Current work is
internal TestFlight readiness and physical-device acceptance, not feature expansion.
Follow DEVICE_ACCEPTANCE.md and LAN_SECURITY_DECISION.md. Apple signing inputs,
actual device results, authenticated LAN transport, publisher identity/contact,
and final legal review remain open. New release-tooling changes require their own CI.

