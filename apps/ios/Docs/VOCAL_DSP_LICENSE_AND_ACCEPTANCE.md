# KANTA Vocal Pitch DSP — MIT integration, licensing and device acceptance

Status: **Real SoundpipeAudioKit integration committed in PR #46; not CI/device validated**
Reviewed: October 10, 2026

## Implemented architecture

KANTA uses one AVAudioEngine and the existing `MicrophonePitchMonitor` as
the sole microphone-input owner. The experimental opt-in live vocal graph is:

```text
mic input ─┬─ dry tap: pitch observations → optional scoring (unchanged)
           └─ SoundpipeAudioKit PitchCorrect → Apple TimePitch fallback
              → EQ → compressor/expander → de-esser → doubler
              → reverb → echo → limiter → hard-muted monitor → permitted output
```

Exactly one tuning backend is active at a time:

- **Soundpipe · PitchCorrect (default when tuning is enabled):**
  SoundpipeAudioKit 5.7.4 provides the actual, MIT-licensed native Audio
  Unit for monophonic pitch correction. The KANTA key/scale intervals are
  translated into a bounded 24…107 MIDI note frequency table and passed via
  `setScaleFrequencies`. Its `speed` and `amount` parameters are
  changeable from the existing Soundcard UI. Apple TimePitch is set to zero.
- **Apple · Native:** Soundpipe amount is zero. The existing KANTA
  `VocalPitchFollower` uses validated dry pitch observations and note
  hysteresis to control Apple's `AVAudioUnitTimePitch`.
- **Disabled, stopped, denied microphone, or unsupported output:**
  Soundpipe amount and native pitch return to neutral; monitor output is
  hard muted. Live monitoring stays **off by default**.

Users explicitly select the backend. Existing saved settings without a
`backend` field decode safely; Soundcard and karaoke audio remain optional.
The new Soundpipe node is attached/connected before starting playback and
is never graph-rewired while running. KANTA does not launch a parallel
AudioKit engine. The Soundpipe DSP performs its own correction; dry scoring
observations are not reprocessed by the new effect.

**Limitations:** Runtime and real-time safety of changing Soundpipe's scale
frequency table while monitoring are **not yet measured or certified**.
The system may add latency or artifacts even with amount zero because the
effect is in the graph. This is a source integration, not a low-latency or
formant-preserving hardware certification. Keep the feature experimental.

## Exact direct version constraints and attribution

| Software | Version | License | Source |
| --- | --- | --- | --- |
| SoundpipeAudioKit | **5.7.4 exact** | MIT | https://github.com/AudioKit/SoundpipeAudioKit |
| AudioKit | **5.7.2 exact** | MIT | https://github.com/AudioKit/AudioKit |
| AudioKitEX | Transitive version, resolve in build | MIT | https://github.com/AudioKit/AudioKitEX |
| Tonic | Transitive version, resolve in build | MIT | https://github.com/AudioKit/Tonic |
| KissFFT | Transitive version, resolve in build | **BSD 3-Clause** | https://github.com/AudioKit/KissFFT |

All five repositories' published permission/copyright notices were
reviewed and copied without abridgment into
`Resources/Licenses/THIRD_PARTY_AUDIO_NOTICES.txt`. The app includes
that file via `project.yml` and exposes it in the Legal & Privacy UI.
`PublicSite/licenses.html` reproduces the notices for website users.

**Release gate:** Inspect the actual resolved dependency revisions,
third-party nested sources/licenses and generated license payload before
signing. Neither Soundpipe's MIT nor KissFFT's BSD license provides rights
to karaoke songs, third-party SoundFonts, other people's audio content, or
use of the commercial Auto-Tune trademark. GPL-restricted DSP plugins
are **not** included. Copyright/license compliance is not legal immunity.

Signalsmith Stretch remains **not included**, because its FFT/block
processing and latency profile has not been integrated or tested as an
Audio Unit in the iOS real-time microphone graph. We selected the
native-AU `PitchCorrect` implementation instead of combining unrelated
effect engines. Its MIT license remains a future possible optimization,
not a claim of shipped code.

## Visually detailed customer setup guide

`PublicSite/guide.html` is a self-contained illustrated six-section guide:

1. Gear selection for Lightning/USB-C iPhone and iPad, USB class-compliant
   interfaces, safe outputs and amplifier connections.
2. Recommended XLR mic → powered USB audio interface ↔ phone/iPad
   → interface line out → mixer/amp/monitors signal diagram; simple
   built-in mic → wired headphones test; explicit invalid bypass example.
3. Real Soundcard UI labels including monitor safety, vocal effects,
   `Soundpipe · PitchCorrect` vs `Apple · Native`, key, scale, amount,
   speed; all mock controls clearly labeled **illustrations**, not app screenshots.
4. Five-point low-level sound-check procedure and feedback safety.
5. Guided import, BYOL/SF2, private Songbook, timed lyrics, Remote,
   Favorites, scoring and Party SFX.
6. Accessible symptom-specific troubleshooting accordions.

It is linked in public home, features, Songbook, support, privacy/legal and
in-app Legal view. The page is in the PR source tree **only** until an
actual Vercel production deployment can be independently verified.
It must never imply hardware testing is complete.

## Acceptance checklist

- [x] Real MIT SoundpipeAudioKit dependency declared at exact version.
- [x] Apple native fallback and backend selector implemented.
- [x] Existing single-engine graph, dry scoring tap and route mute retained.
- [x] Software copyright/permission/disclaimer text in app resources and website.
- [x] Five domain follower tests, backend preference migration test and Python
      source-contract tests authored in PR.
- [x] Illustrated website setup and features guide authored.
- [ ] Dependency resolution verified on Xcode, including transitive versions.
- [ ] Exact-head Swift Core CI (Swift tests, unsigned Release simulator,
      Host/CONTROL smoke), with user approval for GitHub Actions minutes.
- [ ] Confirm app resources include notices at the actual IPA path.
- [ ] Realtime FFT/AudioUnit parameter changes, backends, output safety,
      interruptions and start/stop/cancellation tested with real wired/USB
      interfaces, iPhone XR and iPad 9 (and newer supported devices).
- [ ] A/B test microphone round-trip latency, distortion, consonants,
      breathiness, sustained notes, false note switches, feedback, thermal,
      interface power and sample-rate changes.
- [ ] Cross-check third-party nested source licenses, resolved revisions,
      customer legal declarations and Word companions before merging.
- [ ] Verified website preview/production promotion (if authorized).
- [ ] Commercial/App Store review, TestFlight signing and accepted audio
      hardware routing.

## Current delivery truth

PR #46: **source pushed, draft/unmerged**. Website pages and code are
**not yet proven CI-green or deployed** in this branch. No new macOS
CI, physical-device test, signed TestFlight or App Store release was
initiated by this implementation batch. Full source integration is
not the same as verified iOS runtime delivery.

## Supplement — verified preview and Library documentation

A separate Vercel preview is READY:
`dpl_E75skeg6rU9AT1VhA3h1Caxwpdoq`,
https://kanta-public-9xkwtbu19-gelo-tech.vercel.app .
Its `/guide` and `/licenses` routes were fetched and their
intended content verified; the production alias has not been promoted.
The three current KANTA 2026-10-10 `(6)` Word documents—Engineering
Handover, User Guide and Feature Specification—were updated in the
owner's Library and visually reviewed. None of these checks prove
iOS Audio Unit correctness, physical microphone latency or feedback
safety. Exact-head Core CI and hardware acceptance remain open.

## Website delivery evidence — verified production

`/guide` and `/licenses` have now been promoted from the preview
to the main KANTA production website:
https://kanta-public.vercel.app/guide and
https://kanta-public.vercel.app/licenses .
Vercel release `dpl_CrzkRL3ojpmxGUnkjTj2oAjpbJtE` is READY and
the homepage and both paths were independently fetched and checked.
This static web deployment is not evidence that the new iOS Soundpipe
Audio Unit compiles or safely processes a physical microphone.
The three `(6)` Library Word companions were updated and
visually rendered with these verified URLs. All iOS CI/device gates
remain open.
