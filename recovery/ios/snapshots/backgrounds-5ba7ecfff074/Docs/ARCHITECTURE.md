# Architecture

## Architectural principles

1. **Offline-first.** Core karaoke playback, library search, queueing, lyrics, scoring, backgrounds, and local control must work without Internet access.
2. **One app, primary local control.** The main KANTA Host UI exposes search, queue, transport, volume, pitch, and tempo directly. A second-device Companion Remote remains optional.
3. **Shared command surface.** UI features depend on `KaraokeController`, not directly on local playback or networking.
4. **Local transport only by default.** Remote discovery/control uses LAN technologies such as Bonjour/mDNS and Network.framework/WebSocket-style messaging; cloud is not required.
5. **Compatibility adapters are isolated.** Legacy format readers belong behind repository-owned interfaces and must not leak into presentation code.
6. **Renderer/UI is projection, not authority.** Playback/queue/library state lives in domain services; views observe state and issue commands.
7. **Bring Your Own Library.** Commercial builds read user-selected Files/iCloud libraries and do not redistribute third-party third-party karaoke payloads.
8. **Third-party notices remain intact where legally required.** Product branding can be Gelo-owned without misattributing external libraries/assets.
9. **Architecture changes require this document to change in the same PR/commit.**

## Build and module boundaries

The domain, storage, playback, and compatibility foundation is a Swift Package:

~~~text
GeloKaraoke
├── GeloKaraokeCore
│   ├── Control
│   ├── Library
│   ├── MIDI
│   ├── Playback
│   ├── Networking
│   └── Scoring
├── LibraryStorage -> GeloKaraokeCore
├── AVFoundationPlayback -> GeloKaraokeCore
├── AVFoundationMIDIPlayback -> GeloKaraokeCore
├── GeloLegacyCompression -> zlib + Apple CommonCrypto
├── LegacyCompatibility -> GeloKaraokeCore + GeloLegacyCompression
├── LocalNetworkControl -> GeloKaraokeCore
├── MicrophoneScoring -> GeloKaraokeCore
└── kanta-container-probe -> LegacyCompatibility
~~~

The SwiftUI application target composes these modules and does not own binary parsing or playback state machines.

Host control is stage-first: an inline **Controls** panel expands within the Host list rather than presenting an overlay, so search/queue/playback controls never obscure lyrics or the stage. Background image/video presentation is intentionally secondary product chrome and is exposed as a simple `Background visuals` toggle inside that panel. The underlying `BGV/*` and `BG/*` folders remain implementation/library conventions rather than primary navigation.

The application shell uses an adaptive NavigationSplitView. On iPad this
keeps mode selection in a persistent sidebar with the active Host,
Remote, or Library surface in the detail column; compact-width devices
collapse to the normal single-column navigation flow. Host/Remote
transport controls expose explicit VoiceOver labels and values, while
the karaoke stage treats visual backgrounds as decorative and keeps the
current lyric as the accessible content.

## Device support and adaptive performance

The shipping deployment target remains **iOS/iPadOS 17.0** with both iPhone and iPad device families enabled.

Product support floor:

- iPhone XR and newer, when running iOS 17 or later.
- iPad (9th generation) and newer as the standard-iPad baseline.
- Supported iPad mini/Air/Pro models running iPadOS 17 or later.
- Forward compatibility is maintained against the current Apple SDK through iOS/iPadOS 27.

This is a support policy rather than a generation gate in Xcode; Apple does not provide a normal application entitlement for declaring a minimum iPhone/iPad generation. Runtime behavior therefore adapts by capability and resource pressure rather than hard-coding product model names.

Performance priority order is:

1. audio engine and transport timing,
2. lyrics and queue/control responsiveness,
3. scoring capture/analysis,
4. stage visuals and animation.

KANTA never solves device pressure by recompressing user media. Instead it reduces disposable visual work, evicts nonessential caches, keeps one active SoundFont sampler hot across MIDI/KAR songs, prewarms selected SoundFonts opportunistically, and may fall back to a smaller user-supplied SF2 if the preferred bank cannot be loaded safely.

## Application composition

`AppServices` is the app composition root. It creates one shared:

- `LibrarySourceRegistry`
- `BookmarkedKaraokeLibrary`
- `AVFoundationAudioPlaybackEngine`
- `AVFoundationMIDIPlaybackEngine`
- `RoutedAudioPlaybackEngine`
- `LocalKaraokeController`
- `BonjourHostAdvertiser`
- `MicrophonePitchMonitor`

Host and Library features receive those shared services. This prevents imported-folder state from diverging between screens.

~~~text
Files / iCloud Drive system folder picker
      ↓
LibrarySourceRegistry
      ↓
BookmarkedKaraokeLibrary
      ↓
KaraokeLibraryAccess
      ↓
LocalKaraokeController
      ↓
RoutedAudioPlaybackEngine
     ↙                     ↘
MP3/WAV                 MIDI/KAR + SF2
~~~

## Library access and security scope

The system document picker persists a bookmark for each user-selected directory. The picker can expose On My iPhone/iPad, iCloud Drive, and other Files providers without requiring a Gelo-owned cloud account or app-owned iCloud container. `BookmarkedKaraokeLibrary` resolves registered bookmarks and keeps successful security-scoped directory access active while the library service is in use.

A reload fetches the registry before changing active state, then rebuilds scopes and catalogs without suspending. A generation token rejects superseded/cancelled reloads. Stale bookmarks are persisted after publication through a bookmark-only update that cannot resurrect a removed source. Startup and Host share an initial load; returning to Host does not clear an active legacy payload cache. Removed sources lose their active scope on explicit reload. Each library instance owns its temporary payload directory.

`LibrarySourceRegistry` treats decode corruption as recoverable state rather than a fatal app-start condition. If the persisted registry bytes can be read but cannot be decoded, the original file is moved intact to a collision-safe `.corrupt-<uuid>` backup, the active registry starts empty, and `AppServices` surfaces a recovery notice so the user can re-add Files/iCloud folders. Filesystem read/move failures still fail closed instead of silently discarding state.

Catalog building uses scan metadata only. Stable loose-file song IDs combine source UUID + normalized relative path. Relative paths containing parent traversal or absolute paths are rejected before URL resolution.

For MIDI/KAR, SoundFont selection is deterministic:

1. `user-selected .sf2` in the same registered source, when present.
2. Otherwise the first normalized `.sf2` path.
3. `.sfz` remains discoverable metadata but is not passed to the current AVAudioUnitSampler SF2 loader.

The service does not import or duplicate the user's full library and validates resolved source URLs remain inside the selected root. For a legacy container song, `BookmarkedKaraokeLibrary` may materialize only the validated payload span needed for the selected song into an app-local temporary cache so AVFoundation can consume a normal file URL. That cache is cleared on library reload/close, is never uploaded, and is never part of the app bundle or a Gelo release. Commercial distribution rules are defined in `Docs/COMMERCIAL_DISTRIBUTION.md`; hosted CI rejects known third-party karaoke payload binaries if they are committed to source control.

## Host

`HostViewModel` projects `LocalKaraokeController` state. It does not own a second queue or playback state machine.

The first end-to-end Host flow supports:

- searchable loose MIDI/KAR/MP3/WAV catalog
- enqueue/remove queue item
- play/pause/previous/next
- volume
- semitone pitch changes
- tempo ratio changes
- periodic authoritative playback snapshots

Playback queue transitions are transactional at the controller boundary.
A queued item is not removed and does not become now-playing until its
asset has resolved, loaded, and (when requested) started successfully.
Malformed/unavailable media therefore remains visible for retry/removal
instead of being silently consumed. Infrastructure playback/legacy
errors conform to LocalizedError where they cross into user-facing Host
alerts.

Validated legacy `index/container` titles are projected into the same catalog. Playback resolves only the selected user-supplied payload span. Native MIDI/WAV/ID3-MP3 spans can play directly; confirmed current protected payload v1 spans are decrypted with AES-256-CBC and inflated as raw DEFLATE into the same temporary cache, with declared-size and decoded-signature verification before playback. Unproven container signatures fail closed.

## Synchronized lyrics

`BookmarkedKaraokeLibrary` exposes timed lyric cues for MIDI/KAR songs and caches parsed cue timelines per song until the library reloads. `KaraokeLyricSequence` is the platform-neutral presentation model that normalizes common KAR lyric control markers and resolves the previous/current/next cue from the authoritative playback position.

`HostViewModel` owns only the projected lyric window for the currently playing song. SwiftUI does not parse MIDI files or derive timing itself. Songs without timed MIDI/KAR lyrics continue playing normally with no lyrics section.

## Background media

Background media remains split between technical compatibility and legal
distribution provenance. `BackgroundMediaCompatibilityInspector` uses
Apple-native decode metadata to report whether user-selected images and
videos are usable on the current iOS playback path without modifying the
source. Compatible imports are copy-only: no transcoding, re-encoding,
resizing, or recompression is performed.

The storage compatibility paths remain `BGV/MOTION`, `BGV/NATURE`, `BGV/3D`, `BGV/USER` for video and `BG/MOTION`, `BG/NATURE`, `BG/3D`, `BG/USER` for images. They are not exposed as product labels. KANTA presents these functional categories as **MY SET**, **LOOP**, **SCENIC**, and **REALM** respectively. Baybayin equivalents remain available as intentional brand accents, but are not mixed into tappable system chrome so unsupported or inconsistent fallback fonts cannot reduce legibility. `BGV/USER` and `BG/USER` remain
user-controlled content. Gelo-distributed media is a separate legal
boundary and requires approved provenance under
`ThirdParty/media-provenance.tsv`.

`LooseMediaCatalog` resolves optional local background media deterministically without treating unrelated artwork as karaoke visuals. Resolution order is: same-directory/same-basename media, same-directory `background.*`, root `background.*`, then the conventional third-party karaoke `bgv/` or `bgphoto/` library pool. Video wins over image only when candidates satisfy the same resolution tier.

`BookmarkedKaraokeLibrary` resolves the selected visual under the same security-scoped source boundary as audio. Host renders images locally and uses a muted looping `AVPlayerLayer` for video. Visual playback follows the authoritative karaoke transport play/pause state and does not own audio transport or queue state.

## MIDI/KAR playback

`StandardMIDIParser`, `MIDITimeline`, and `MIDIPlaybackPlan` remain platform-neutral.

`AVFoundationMIDIPlaybackEngine` loads an explicit local SF2 through `AVAudioUnitSampler`, schedules domain MIDI events, restores channel/note state after seek, and keeps GM percussion channel 10 untransposed.

The engine boundary remains replaceable with a properly licensed alternate licensed MIDI backend adapter if real third-party karaoke SF2/multitimbral fidelity requires it.

## File-audio playback

`AVFoundationAudioPlaybackEngine` handles local MP3/WAV with seek, volume, pitch, and tempo.

## Local controls and companion remote

`InAppControlCenterView`, branded functionally in the UI as **CONTROL**, operates directly on the shared `HostViewModel`/`LocalKaraokeController`. Baybayin remains part of KANTA's brand identity but is kept out of primary control labels for predictable typography across supported iPhone/iPad system fonts. It is the primary control path and requires no network pairing. The panel expands inline and provides bounded search results, enqueue/remove queue actions, transport, volume, pitch, tempo, and the optional background-visual toggle.

The existing network Remote surface is retained as **Companion Remote** for a second phone/tablet and uses the same authoritative command model. It is optional, not required for normal one-device operation.

## Remote protocol

Remote Protocol v2 translates authenticated LAN commands into the same `KaraokeCommand` handled locally.

`Infrastructure/LocalNetworkControl` now owns Bonjour/mDNS presence and discovery using Network.framework with service type `_gelokaraoke._tcp`. Host mode advertises only while the Host screen is active; Remote mode browses the LAN and projects discovered service names into UI state. The iOS app declares `NSLocalNetworkUsageDescription` and `NSBonjourServices` in an explicit Info.plist so on-device discovery follows Apple's local-network permission model.

A six-digit `PairingCode` primitive is generated and displayed by Host mode but is deliberately not placed in Bonjour TXT metadata. `LocalNetworkControl` uses a bounded 4-byte big-endian length prefix around JSON `RemoteEnvelope` frames (maximum payload 1 MiB). A session must identify as `.controller`, complete the PIN exchange, and reach a paired session state before any `KaraokeCommand` can execute. Invalid framing, protocol versions, roles, sequencing, or PINs fail closed. Rotating the Host PIN revokes active remote sessions. Paired sessions receive authoritative `KaraokeSnapshot` updates every 500 ms and after accepted commands. Remote mode exposes transport, volume, pitch, tempo, now-playing, queue-state, bounded catalog search, enqueue, and queue removal. Catalog queries are accepted only after pairing, trimmed to 200 characters, capped at 100 results, correlated by request UUID so stale responses can be ignored, and return only `LibrarySong` metadata—never bookmarks or filesystem paths. The current TCP stream is application-authorized but not cryptographically confidential, so it is intended for trusted LAN use until encrypted-channel hardening is added.

Phase 6 treats transport confidentiality as an explicit release-hardening
gate. PIN authentication prevents unauthenticated command execution but
does not provide secrecy against a local-network observer.

## Scoring and microphone boundary

`GeloKaraokeCore/Scoring` owns platform-neutral pitch observations, explicit target-pitch windows, latency compensation input, and score aggregation. The current score model weights pitch accuracy more heavily than voiced/timing coverage; it is a deterministic foundation, not a claim that third-party karaoke scoring semantics have been reproduced.

`Infrastructure/MicrophoneScoring` owns local microphone capture and pitch detection. `MicrophonePitchMonitor` requests permission only after an explicit Host action, publishes pitch observations in memory, and neither records nor uploads microphone audio. `AutocorrelationPitchDetector` is a bounded pure-Swift baseline that rejects silence/low-correlation input and constrains expected singing frequency to a configured range.

Microphone observations now use monotonic uptime timestamps shared with Host playback anchors. `LiveKaraokeScoringSession` projects those observations into authoritative karaoke media time, interpolates playing position with the current tempo ratio, ignores paused input, bounds retained observations, and resets on material seek drift or pitch-transposition changes. Host exposes the resulting live score plus bounded manual latency compensation. Automated per-device calibration and real-device validation remain pending. `MIDIMelodyTargetExtractor` provides the conservative target-melody boundary. Automatic extraction resolves only when one strong candidate exists: a lyric-bearing track with exactly one non-percussion note channel, or a track explicitly named as a vocal/melody guide with exactly one non-percussion note channel. It rejects competing candidates, polyphonic targets, malformed note lifecycles, and non-center pitch-bend targets instead of guessing. `BookmarkedKaraokeLibrary` exposes that extraction per MIDI/KAR song and shares one parsed-MIDI cache between lyrics and scoring targets. Unsupported or ambiguous songs remain playable but are explicitly unscored.

The current detector allocates/normalizes a short buffer and performs autocorrelation per observation. Battery, memory, thermal behavior, and coexistence with playback audio-session routing require real-device profiling before shipping scoring.

## Indexed-library interoperability boundary

`DirectoryLibraryScanner` performs filename-neutral discovery. It recognizes
normal media and valid SF2 SoundFonts, then structurally probes otherwise
unclassified files for a supported indexed-library layout. A candidate index is
accepted only when its offsets safely correlate with exactly one media container
and bounded payload sampling confirms a supported path.

`IndexedContainerCompatibility.swift` is the neutral facade between storage
code and the isolated private format implementation. Higher layers use
`IndexedLibraryProbe`, `ContainerOffsetCorrelator`,
`ContainerSpanIndex`, and `ContainerPayloadProbe` through that facade rather
than depending on third-party product terminology.

`IndexedContainerCatalog` projects validated title rows into
`.legacyContainer` songs. `BookmarkedKaraokeLibrary` materializes only the
selected payload when playback needs a standalone media URL. Source files remain
inside the user-selected security-scoped folder and are never rewritten.

Low-level constants needed to recognize a compatible protected payload stay
confined to the private compatibility implementation. They are implementation
details, not product identity, public documentation, or App Store metadata.

## Testing strategy

- Core: MIDI parsing/timing/playback plans, queue/controller/routing,
  including failed asset/load/play rollback of user-visible queue state.
- Storage: safe traversal, catalog construction, registry persistence, and corrupt-registry quarantine/recovery.
- Playback: generated media + adapter preconditions.
- Legacy compatibility: synthetic protected payload byte-for-byte decrypt/inflate
  tests, malformed/truncated envelope rejection, strict offset-table
  mapping tests, and explicit fail-closed coverage for unproven type-9
  addressing. Matching-current-library acceptance is a release
  validation task, not a source-controlled or downloaded CI fixture.
- Integration: shared controller -> routed engine -> resolved media assets.
- Local network: frame boundaries/version limits, controller-only pairing gate, PIN rejection, authenticated command dispatch.
- Scoring: note/frequency conversion, latency-aware aggregation, playback-clock alignment, seek/pitch-change reset behavior, synthetic-tone pitch detection, and silence/out-of-range rejection.
- Privacy/configuration: plist lint, required permission strings,
  Bonjour declaration, tracking-disabled privacy manifest, and manifest
  inclusion in the generated iOS target.
- Hosted CI: `swift test` plus generated iOS Simulator build.


## Legal and licensing surface

The SwiftUI application exposes a first-class **Legal & Privacy**
destination. It summarizes BYOL ownership boundaries, background-media
quality/compatibility behavior, privacy posture, trademark neutrality,
third-party notice requirements, and the rule that Gelo-owned releases
must not redistribute third-party media without documented rights.

The in-app surface is explanatory; machine-enforced distribution policy
remains in CI and repository documentation.


### One-folder compatible-library BYOL onboarding

The preferred onboarding path is one-folder and non-destructive. Users place the
matching compatible index, media container, and any valid `.sf2` files in a
folder and select that folder through Files/iCloud Drive.

Detection is structural rather than filename-based. The scanner validates the
index/container relationship, discovers any valid SF2 regardless of name, and
keeps large source assets in user-controlled storage.

## Reliability hardening — proposed 2026-10-06

See [per-change handover](HARDENING_HANDOVER.md) for validation limits.

- Controller operations use an actor-owned asynchronous FIFO gate: actor isolation
  alone cannot serialize a transaction across library/engine awaits. Views and
  remotes continue to use the same controller; no second playback state exists.
- Adapters report explicit natural completion. Snapshots retain an optional
  completion record and per-run UUID, allowing scoring to distinguish manual skip,
  replay, and repeat reservations. No timing-proximity heuristic remains.
- Failed automatic handoffs retain reservations and publish an error once rather
  than retrying on every poll. Partially changed adapter state is stopped and must
  reload the committed song before resuming.
- SoundFont prewarming cannot mutate playing/paused MIDI. The resolved candidate
  chain stays cached until file metadata/selection changes; cache identity is
  invalidated before mutating sampler loads.
- VerifiedLibraryBackup belongs to LibraryStorage; iCloud orchestration stays in
  the app. Provider-coordinated reads/writes use UUID-based backup directories and
  verified temporary replacements. Older display-name backups are preserved.
  Cloud deletion is deliberately scoped to `Documents/KANTA Backup` plus KANTA's
  iCloud key-value settings key; it never deletes the user's selected source folders.
- Privacy declarations cover app settings, selected-file/app-container metadata,
  and in-app timing. Metadata is not used for fingerprinting.

These implementations await macOS/physical-device validation; they do not close
LAN confidentiality, signing, actual indexed-library acceptance, or performance release gates.


## Repository-wide hardening — 2026-10-07 Manila (validation pending)

- Registry mutations publish in-memory state only after an atomic disk write;
  duplicate source IDs enter the existing byte-preserving quarantine path.
- Relative media paths reject NUL and resolve symlinks before the root boundary
  check. SoundFont availability is evaluated by the MIDI adapter, allowing a
  missing preferred file to reach the existing fallback chain.
- Library import copies and provider-coordinated scans run on utility tasks;
  the caller retains security scope until completion. Copies use the same
  verified temporary-copy helper as backups and preserve source bytes.
- Microphone start/stop and remote/Bonjour callbacks carry lifecycle tokens.
  Late permission results, samples, and cancelled connection callbacks cannot
  mutate a replacement session. Scoring aggregation is published by Host's
  snapshot refresh rather than on every microphone buffer.
- MIDI seek/pitch changes restore notes only while playing; pause/stop release
  sustain and silence voices. Binary cursors support nonzero Data start indices;
  elapsed-time conversion saturates before integer conversion.

These are source changes, not completed device or hosted acceptance. See the
handover for exact validation and remaining release gates.


### Canonical legal disclosure — 2026-10-07

`Features/Legal/LegalView` owns the legal notice and its presentation content;
`App/LegalDisclosureView` supplies only the modal navigation/dismissal shell.
Both entry points therefore show the same BYOL, third-party, privacy and rights
wording. `KantaTerminology` supplies the public app name and full display identity.
Optional iCloud Save/provider sync and plaintext LAN behavior must be reflected
in disclosures whenever implementation changes. The notice is informational,
not a separate license agreement or a rights-verification mechanism.


## Filename-neutral SoundFont policy — 2026-10-07

SoundFont import and selection is provider-neutral. A user-selected file is
accepted as an SF2 only when its RIFF header identifies a SoundFont bank. No
special filename receives priority. Explicit user selection wins; otherwise
deterministic path order is used. Distribution CI never inspects runtime
Files/iCloud imports and therefore cannot reject a user-owned SF2 by name.


## Release asset and App Store boundary — 2026-10-07

The iOS target owns a single-size 1024×1024 `AppIcon` in
`Sources/App/Assets.xcassets`; Xcode derives smaller iPhone/iPad variants.
Release validation rejects a missing, wrong-size, or transparent icon and checks
the iCloud Documents entitlements used by
`FileManager.url(forUbiquityContainerIdentifier:)`.

The shipping Info.plist declares `ITSAppUsesNonExemptEncryption = false` for the
current build because KANTA currently relies on Apple-provided/system
cryptographic facilities rather than a non-exempt proprietary crypto
implementation. Adding third-party/custom cryptography or materially changing
transport security requires export-compliance re-review before submission.

App Store screenshot automation remains opt-in and targets an available
Dynamic-Island Pro Max iPhone plus a 13-inch/accepted 12.9-inch iPad class. The
workflow verifies pixel dimensions against App Store Connect requirements before
publishing artifacts.


## Responsive Host control policy — 2026-10-07

The Host screen has one search/query state, owned by `HostViewModel`. The
expanded CONTROL surface owns the visible search field; `HostView` does not
also attach a global `.searchable` bar because that system overlay can obscure
queue/playback content on compact iPhone heights.

CONTROL rows must remain width-bounded by their List row. Search-result actions use the horizontal size class explicitly: compact iPhone
layouts render a fixed-size circular reserve action, while regular-width iPad
layouts render the labeled **Reserve** control. This avoids SwiftUI fit
measurement stretching the action to the row height. Queue titles keep layout priority over destructive icons.
Pitch/tempo controls use `ViewThatFits` so compact devices stack controls
instead of forcing horizontal overflow.

Functional UI labels use Latin text for deterministic system typography.
Baybayin strings remain separate in `KantaTerminology` for deliberate brand
surfaces where their rendering can be reviewed rather than appearing as an
uncontrolled fallback inside buttons, menus, or navigation chrome.



## Release boundary — 2026-10-07 follow-up

Manual TestFlight has a cheap Linux preflight before the dependent macOS job.
Credential values are scoped to the steps that require them; temporary keychain
credentials are generated per run. The uploader receives API_PRIVATE_KEYS_DIR
explicitly. Run/attempt identity supplies the build version. Export is internal-only
until device/legal/LAN release gates close; this does not add network encryption.

Public policy/support pages are static, separately deployed from `PublicSite/`.
Only those reviewed files go to the public host; Swift sources, user assets,
credentials, and internal Docs never enter the deployment. PRIVACY.md and SUPPORT.md
are the content sources; Tools/build-public-site.py reproduces the HTML. App legal
links and App Store metadata use the stable public hostname. The site introduces
no application backend, analytics, or library upload path.


## Screenshot gallery publication — 2026-10-07

Successful manual screenshot captures on main publish the four validated PNGs to
`screenshots/latest` on the dedicated `ui-screenshots` branch. Its root README
renders a gallery and capture.json records source commit and run provenance.
The capture job remains read-only; only the separate Linux publishing job has
contents write access. PR and non-main captures remain artifacts only, preventing
unreviewed previews from replacing the accepted-main gallery. Failed captures
preserve the previous gallery; run ordering prevents stale retries replacing newer
captures. Atomic, non-force Git pushes preserve history and reject concurrent
external branch changes. Publication uses GITHUB_TOKEN, introduces no app runtime
changes, and does not trigger another app build. The ZIP artifact remains available.



## Bundled still backgrounds — 2026-10-08

`BG/BUNDLED` is an XcodeGen folder-reference resource in the application bundle.
`KantaBuiltInVisualPreset` retains its ten existing persisted static identifiers
and maps each directly to an original PNG using `Bundle.main`. Display names
match the supplied artwork. `KantaBuiltInVisualView` uses the existing asynchronous
`LocalBackgroundImage` reader, shared with user-selected stage images, so Host
and fullscreen have the same rendering path. Missing resources retain the
procedural fallback. Selection/settings, controller ownership, user-library
bookmarks and animated presets are unchanged. Only the selected image is read;
there is no startup scan, network fetch or copy into the user's library.
Original bytes and dimensions are preserved, with exact hashes in
`ThirdParty/bundled-backgrounds.json` and distribution entries in the existing
media-provenance registry. The static guard verifies the pack and bundle wiring.

## Centered source-timed lyric pages — 2026-10-08

`KaraokeLyricPageSequence` preserves original MIDI/KAR fragment timestamps and
explicit slash, backslash and newline line boundaries. Unmarked cues retain
line-level timing. Binary search projects a stable two/three-line page from the
controller playback position; no estimated word duration or independent lyric
clock is introduced. `HostViewModel` publishes this projection on its 100 ms
snapshot refresh and after playback commands. Existing lyric-window consumers
remain compatible. Song replacement and metadata failures clear the page source.

`KaraokeLyricBlock` is the shared centered, heavy, outlined-text presentation for
Host and fullscreen. Fragments turn green at their source timestamp; upcoming
text stays white. Pause, seek and tempo changes follow the controller clock.
Fullscreen starts with playback chrome hidden; tap the stage or the accessible
Show playback controls button to reveal it. A noninteractive KANTA text watermark
uses 0.75 opacity at the bottom-right, outside the lyric block and playback panel.
No reference-brand artwork, lyrics or QR code is copied into the application.
