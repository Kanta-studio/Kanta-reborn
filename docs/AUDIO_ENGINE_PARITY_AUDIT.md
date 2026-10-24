# KANTA Reborn — Audio Engine Parity Audit & Implementation Plan (Issue #32)

## 1. Executive Summary
This document establishes the architecture parity matrix, audit findings, and implementation roadmap for **Issue #32** (iOS + Android native karaoke audio-engine parity and SoundFont/DSP audit).

## 2. Platform Audio Stack Comparison

| Feature / Component | Android Implementation | iOS Implementation | Parity Status |
|---|---|---|---|
| **Synthesizer / SoundFont Engine** | Native TinySoundFont (`tsf.h`) via JNI (`SoundFontPlayback.java`, `soundfont-jni.c`) | `AVAudioEngine` + `AVAudioUnitSampler` (`AVFoundationMIDIPlaybackEngine.swift`) | ✅ Equivalent (Native C vs AVFoundation) |
| **Asset Pack (SF2 / KAR)** | `kanta-tone.sf2`, standard `.kar` files | `kanta-tone.sf2`, standard `.kar` files | ✅ Byte-identical assets |
| **Playback Session Ownership** | `MelodyScoreSession` / single worker thread | `KaraokeAudioOwnership` / `SessionController` | ✅ Unified single-owner model |
| **Microphone & DSP FX** | Custom routing guard (`MonitorRouteGuard`) | Room Microphone Gate (3s ambient), 7 vocal FX presets | ⚠️ iOS has richer vocal preset layers |
| **Pitch Correction / Shifting** | `ChromaticPitchCorrector` (±0.6 st monitor-only) | Scoring latency clamp -500..1500ms | ⚠️ Asymmetric specialized filters |

## 3. Implementation Roadmap
1. **Phase 1: Feature Parity Matrix & Docs** (Completed)
2. **Phase 2: Core Audio Ownership & Session Guard Alignment**
   - Ensure both Android and iOS enforce strict "score-once-per-playback-identity" rules to prevent duplicate score entries.
3. **Phase 3: SoundFont Validation & Transactional Rollback**
   - Implement malformed SF2 limits, file-size guards, and transactional rollback on corrupt asset imports.
4. **Phase 4: Testing & Benchmarking**
   - Run unit assertions and latency/CPU benchmarks on both platforms.
