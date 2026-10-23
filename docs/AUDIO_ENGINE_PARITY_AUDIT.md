# Audio Engine & DSP Parity Audit — KANTA Reborn

| | |
|---|---|
| **Audited commit** | `main` @ `96ddd97` |
| **Date** | 2026-10-23 |
| **Method** | Read-only source audit (no builds, no simulators, no physical devices) |
| **Status** | Facts below are read from source at the stated commit. Nothing here is device acceptance, CI validation, or a release claim. |

This audit exists to support [issue #32](https://github.com/usermalik20-del/Kanta-reborn/issues/32)
(audio-engine parity + SoundFont/DSP audit). It records what the code actually does today,
separates verified-by-reading from unverified-on-device, and ranks the real gaps so the
implementation work can start from facts instead of documentation claims.

---

## 1. Headline findings

1. **The two platforms do not share a synthesis engine.** Android renders with
   **TinySoundFont (`tsf`)** through a JNI bridge in native C. iOS renders with Apple's
   **`AVAudioUnitSampler`** inside `AVAudioEngine`. The architecture note naming FluidSynth
   (`docs/ARCHITECTURE.md:250`) is an accepted *decision*, not an integration — and the note
   itself says so. **Neither platform currently links FluidSynth.**
2. **Both platforms ship byte-identical starter assets** (same MD5 for `kanta-tone.sf2` and all
   three `.kar` files). Identical input, two different synthesizers — so any rendering,
   balance, or preset-selection difference is engine-derived, not asset-derived.
3. **iOS has the richer mic/DSP surface** (7 vocal FX presets + profiles, room-noise calibration
   gate, Soundpipe `PitchCorrect` path). **Android has the stricter route-safety model**
   (`MonitorRouteGuard`) and a bounded chromatic corrector. These are complementary, not
   equivalent — the parity gap runs in both directions.
4. **Both platforms already enforce "score once per playback identity"** in code (Android
   `MelodyScoreSession.Completion` carries a `playbackId`; iOS
   `KaraokeScoreCompletionDetector` requires a *new* `playbackID` on the same song).
5. **No shared audio test corpus exists.** Protocol vectors exist (`tools/tests/kcp1-vectors.json`)
   but there are no cross-platform KAR/SF2 fixtures or golden waveforms. This is the single
   biggest obstacle to ever *proving* parity rather than asserting it.

---

## 2. Synthesis and output path

### Android

| Aspect | Value | Evidence |
|---|---|---|
| Engine | TinySoundFont (`tsf.h`), vendored, C | `apps/android/app/src/main/cpp/vendor/tsf.h`, `cpp/soundfont.c` |
| Bridge | JNI: `open/close/midi/tune/render` | `NativeSoundFont.java:4-18` |
| Output rate / buffer | 44 100 Hz, 512 frames, stereo | `SoundFontPlayback.java:13` |
| Output format | `AudioTrack`, `ENCODING_PCM_FLOAT`, `MODE_STREAM` | `SoundFontPlayback.java:43, 55` |
| Thread model | One worker owns synth + AudioTrack + MIDI scheduling + audible clock | `SoundFontPlayback.java:11-16` |
| SF2 validation | Dedicated C validator | `cpp/sf2-validation.h` |
| Native test | Standalone C test | `apps/android/tests/soundfont-test.c` |
| Transport | `start/pause/release/position/controls(volume,tempo,pitch)` | `PlaybackBackend.java:16-27` |
| Key change | `native tune(handle, semitones)` | `NativeSoundFont.java:14` |
| End-of-song | Waits for trailing `+800 ms` of buffered audio | `SoundFontPlayback.java:185` |

### iOS

| Aspect | Value | Evidence |
|---|---|---|
| Engine | `AVAudioEngine` + `AVAudioUnitSampler` | `AVFoundationMIDIPlaybackEngine.swift:7-10` |
| Concurrency | Swift `actor` | same file `:7` |
| SF2 handling | `SoundFontIdentity` de-dupe (size + mtime style identity), fallback URL list | `:26-30`, `:86-140`, `:545` |
| Transport | `play/pause/stop/seek/setVolume/setPitch/setTempo` | `:147-259` |
| Scheduling | Dedicated async scheduler loop, generation-tokened | `:296-371` |
| Position | Derived from clock, not from a frame counter | `:381-409` |
| Teardown | `allNotesOff()` before release | `:532` |
| Output rate | Hardware default via `AVAudioEngine` (not pinned to 44.1 kHz) | `:8` |

> **GAP-UNVERIFIED:** iOS sets no explicit sample rate and has no SF2 validation module
> comparable to Android's `sf2-validation.h`. A malformed or unusual SF2 that Android rejects
> deterministically may fail differently (or silently) on iOS.

---

## 3. Feature parity matrix

Verdicts: **MATCH** (equivalent capability), **ANDROID-ONLY**, **IOS-ONLY**, **GAP** (one side
missing a capability the other has), **GAP-UNVERIFIED** (existence confirmed, behaviour on
device not verified by this audit).

| Feature | Android | iOS | Verdict | Evidence |
|---|---|---|---|---|
| Offline MIDI/KAR playback | tsf + JNI | AVAudioUnitSampler | MATCH (different engines) | `SoundFontPlayback.java:12`, `AVFoundationMIDIPlaybackEngine.swift:7` |
| Bundled starter songs | 3 KAR + 1 SF2 | same 3 KAR + same SF2 | MATCH (byte-identical) | `assets/starter/`, `Resources/StarterKaraoke/` (MD5 equal) |
| Personal song import | SAF document tree, `.(mid\|midi\|kar\|mp3\|wav\|sf2)$` | Directory + bookmark scan | MATCH (different models) | `DocumentTreeScanner.java:55`, `DirectoryLibraryScanner.swift:6-15` |
| Non-MIDI audio playback | `MediaPlayer` | `AVAudioEngine` file path | MATCH | `FileAudioPlayback.java:9-22`, `AVFoundationAudioPlaybackEngine.swift` |
| Tempo | `controls(…, tempo, …)` | `setTempo(ratio:)` | MATCH | `PlaybackBackend.java:26`, `…MIDIPlaybackEngine.swift:259` |
| Key / pitch shift | `tune(semitones)` | `setPitch(semitones:)` + transposed-key logic | MATCH | `NativeSoundFont.java:14`, `…Engine.swift:238, 514` |
| Lyrics timeline | SMF parser, ms-resolution cues + fragments | `KaraokeLyricCue` from MIDI timeline | MATCH-UNVERIFIED timing | `MidiLyrics.java:7-12`, `MIDIPlaybackPlan.swift:49, 80` |
| Character-level highlight | `highlightedCharacters(position)` | `KaraokeLyricBlock` / page paging | ANDROID-ONLY primitive | `MidiLyrics.java:29` |
| Playback queue | `SessionController` | `LocalKaraokeController` + `PlaybackQueue` | MATCH (each authoritative) | `SessionController.java`, `LocalKaraokeController.swift:330`, `PlaybackQueue.swift` |
| Mic capture | 48 kHz mono PCM16, `UNPROCESSED` when available | AVAudioEngine input tap | MATCH | `MicrophoneInput.java:35, 131-145` |
| Mic opt-in gate | `enabled()` flag | `RoomMicrophoneGate` 3-s ambient calibration | **IOS-ONLY** | `MicrophoneInput.java:73`; `RoomMicrophoneGate.swift:12-40` |
| Dry monitoring | `MicrophoneMonitor` 48 kHz | `MicrophonePitchMonitor` | MATCH | `MicrophoneMonitor.java:29`; `MicrophonePitchMonitor.swift:40-57` |
| Monitor route safety | `MonitorRouteGuard`: single-device, 1.5 s verify, retire on route loss | route enum + `isMonitorAudible` | **ANDROID-ONLY** | `MonitorRouteGuard.java:8-35`; `…PitchMonitor.swift:47-48` |
| Vocal FX presets | 4 (dry/room/hall/echo), hand-written delay net | 7 (dry/room/studio/hall/cathedral/plate/echo) + profiles | **IOS-ONLY** (richer) | `VocalMonitorEffects.java:9-14`; `VocalFXSettings.swift:6, 40` |
| FX isolation from scoring | Dry path bypasses FX by construction | Separate analysis path | MATCH | `VocalMonitorEffects.java:5` |
| Dry pitch detection | Autocorrelation, 4096-frame | Autocorrelation `PitchDetector` | MATCH | `DryPitchDetector.java:5-19`; `AutocorrelationPitchDetector.swift` |
| Pitch correction | Chromatic, ±0.6 semitone, monitor-only | `VocalPitchCorrection` + `AVAudioUnitTimePitch` + Soundpipe `PitchCorrect` | **IOS-ONLY** (richer) | `ChromaticPitchCorrector.java:6-7`; `MicrophonePitchMonitor.swift:50-52` |
| Scoring model | Key/interval-aware target windows, coverage + accuracy | Cents-window scorer, confidence, latency clamp | MATCH (different models) | `MelodyScoreSession.java:6-38`; `KaraokeScoring.swift:108` |
| Score once per playback | `Completion(playbackId, …)` | `KaraokeScoreCompletionDetector` playbackID check | MATCH | `MelodyScoreSession.java:21-31`; `KaraokeScoreCompletionDetector.swift:4-17` |
| Latency compensation | Not found in scoring path | `setLatencyMilliseconds` clamped −500…1500 | **IOS-ONLY** | `LiveKaraokeScoringSession.swift:92-95` |
| Party SFX (8 pads) | 8 synthesized WAV pads | 8 synthesized pads + custom clip import/reset | MATCH (iOS +custom) | `PartySounds.java:15-24`; `KantaPartySFXEngine.swift:11-46` |
| Camera stage | `CameraStage.java` | not located in this pass | GAP-UNVERIFIED | `CameraStage.java` |
| YouTube playback | `YouTubeEmbeddedPlayer` | `YouTubeEmbeddedPlayerView` | MATCH (shells) | both files present |
| Companion remote | TCP `CompanionProtocol` (encrypted channels, replay counter) | `RemoteProtocol` + `EncryptedCompanionView` | MATCH (both encrypted) | `CompanionProtocol.java:44-119`; `EncryptedCompanionView.swift` |
| Scene/background media | `StageMediaStore` (photo/video, scenic) | background video/image handling | MATCH-UNVERIFIED | `StageMediaStore.java:18-31` |
| Offline-first storage | SAF tree + JSON | Bookmarks + SQLite catalog | MATCH | `LibraryRepository.java`; `BookmarkedKaraokeLibrary.swift` (1 053 lines) |

---

## 4. Assets and licensing

| Item | Android | iOS | Notes |
|---|---|---|---|
| `kanta-tone.sf2` | `assets/starter/` | `Resources/StarterKaraoke/` | **MD5 identical** (`de6865ff…`) |
| `morning-light.kar`, `sing-together.kar`, `starlight-echo.kar` | same | same | **MD5 identical** on all three |
| TinySoundFont licence | `assets/tinysoundfont-license.txt` + `cpp/vendor/LICENSE` | — | iOS does not vendor tsf |
| Third-party audio notices | — | `Resources/Licenses/THIRD_PARTY_AUDIO_NOTICES.txt` (AudioKit/Soundpipe) | Android has no AudioKit equivalent |
| Vocal DSP licence/acceptance | — | `Docs/VOCAL_DSP_LICENSE_AND_ACCEPTANCE.md` | Android FX is original code |
| Party pad audio | Original synthesis (`"no third-party sound recordings are distributed"`) | Original synthesis (`synthesize(_:)`) | MATCH in policy |

**Licensing risk:** if FluidSynth is ever integrated (per `ARCHITECTURE.md:250`), LGPL relinking
obligations apply to binary distribution and the notices must be updated on *both* platforms.
Today's shipping combination (tsf on Android, Apple sampler on iOS) avoids that.

---

## 5. DSP stage inventory

**Android (48 kHz for mic paths, 44.1 kHz for synthesis)**

```
AudioRecord 48k mono PCM16
  ├─ dry analysis ─→ DryPitchDetector (4096) ─→ MelodyScoreSession(target, key, interval)
  └─ monitor ─→ [ChromaticPitchCorrector ±0.6 st] ─→ VocalMonitorEffects (4 modes) ─→ AudioTrack
                 gated by MonitorRouteGuard (device identity + 1.5 s verification)
Synthesis: tsf (44.1 kHz, stereo float) → AudioTrack  → never shares the mic path
```

**iOS (AVAudioEngine graph)**

```
AVAudioEngine input tap
  ├─ analysis ─→ AutocorrelationPitchDetector ─→ LiveKaraokeScoringSession
  │                (playback-clock anchor, latency clamp, discontinuity tolerance)
  └─ monitor ─→ AVAudioUnitTimePitch + Soundpipe PitchCorrect + EQ(2) + compressor
                 ─→ VocalPitchFollower ─→ route; gated by RoomMicrophoneGate (3 s calibration)
Synthesis: AVAudioUnitSampler inside the same AVAudioEngine
```

Both platforms keep synthesis and capture as separate graphs — no feedback path exists by
construction. Only Android has an explicit route-retirement guard; only iOS has an ambient-noise
admission gate.

---

## 6. Ranked gaps and risks

| # | Gap | Impact | Where |
|---|---|---|---|
| 1 | **Different synthesis engines on the same assets** | Rendered balance, preset/bank behaviour and SF2 edge cases can differ audibly even though assets are identical | `soundfont.c`/`tsf.h` vs `AVAudioUnitSampler` |
| 2 | **No shared audio fixtures or golden vectors** | Parity can only be asserted, never proven; regressions are invisible | absent on both |
| 3 | **iOS has no SF2 validation module** | Malformed banks may fail late or silently where Android rejects early | `sf2-validation.h` has no iOS counterpart |
| 4 | **Android has no room-noise admission gate** | Noisy rooms degrade scoring quality with no user-facing guard | `RoomMicrophoneGate.swift:12-40` (iOS only) |
| 5 | **Android's FX set is 4 modes; iOS has 7 + profiles** | Perceived feature gap in the "sounds good" dimension | `VocalMonitorEffects.java` vs `VocalFXSettings.swift` |
| 6 | **iOS has latency compensation in scoring; Android does not** | Timing tolerance may differ between platforms | `LiveKaraokeScoringSession.swift:92-95` |
| 7 | **Sample-rate asymmetry** (44.1 kHz pinned vs hardware default) | Resampling differences could shift perceived timing/latency | `SoundFontPlayback.java:13` vs `AVFoundationMIDIPlaybackEngine.swift:8` |
| 8 | **No camera-stage equivalent located on iOS** in this pass | Potential product gap, needs confirmation | `CameraStage.java` |
| 9 | **Documentation drift** — FluidSynth named as "the chosen engine" | Readers may believe it ships; it does not | `docs/ARCHITECTURE.md:250` |
| 10 | **Scoring models are structurally different**, not merely implemented twice | Cross-platform score comparability is undefined | `MelodyScoreSession.java` vs `KaraokeScoring.swift` |

---

## 7. Verification boundaries (what this audit does *not* establish)

- No simulator, device, or hosted-CI run was performed for this document.
- Timing accuracy, scoring feel, monitoring latency, SF2 rendering quality and route behaviour
  on real hardware are **GAP-UNVERIFIED** for both platforms.
- Test counts are static: Android has 167 + 17 assertion-check call sites in two framework-free
  runners (`CoreRegressionTests.java`, `CompanionRegressionTests.java`; four of the companion
  checks are second statements on a shared line, so naive line-based counting under-reports them);
  iOS has 168 Swift Testing cases
  across six targets plus UI tests. Coverage of the *audio timing* paths is not asserted here.
- Suggested next step (per issue #32): build a shared fixture set (one SF2, three KAR, expected
  note/lyric timelines) and a cross-platform golden comparison before changing either engine.

---

*Generated by a read-only audit of `main` @ `96ddd97` on 2026-10-23. No production code was
modified, no CI workflow was triggered, and no merge, signing, packaging, deployment or release
is implied by this document.*
