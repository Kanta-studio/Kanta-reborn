# Android monitor/FX checkpoint

Accepted source: `1ddee2416b6efe56562f5826ad479a6373ecf86c`.
Successful run: [38842165486](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38842165486).
Artifact: `12022335093`, android-reconstruction-checks.

The Android-only pipeline passed APK/instrumentation assembly, lint, native ASan/UBSan tone/truncation/mutation checks, all 268 domain assertions, browser interoperability, CAMERA/RECORD_AUDIO-only platform-permission/offline-notices gate, and 90 actual API 35 emulator checks. No prior assertions were removed.

Domain tests cover terminal route loss/no automatic reconnect, readiness bounds, unexpected/multiple routes, buffer warmup/clear/overrun, four 100-second simulations of independent capture/output clocks (+/-500 and +/-2,000 ppm), dry-byte preservation, effect impulse tails/reset and finite/limited output. Emulator checks add Control voice-settings expansion/collapse, default-off, actual built-in speaker and absent-device rejection, gain limits, unchanged input and lifecycle non-restart; prior camera/MIDI/input/media checks remain active.

Version 0.7.0 adds experimental explicit wired/USB/analog-line monitoring and Dry/Room/Hall/Echo on an independent AudioTrack. Actual routing is verified while muted; preferred-device selection alone is insufficient. Route loss/disconnect retires that activation. API 36 checks all routed outputs; older Android exposes one reported route and additional unreported outputs cannot be verified. Capture/output clocks are separate with bounded interpolation. Effects never modify dry pitch data. No recording, network permission, new dependency, pitch correction or completed-song score is added.

The emulator has no supported physical monitoring output. No successful physical wired/USB playback, acoustic safety, round-trip latency, device sound quality or API 36 hardware route claim is made. Software volume limits do not control external equipment gain. Device acceptance and calibrated melody scoring remain open, followed by secure companion and official YouTube. iOS source is unchanged. Download packaging is separate and must preserve this accepted APK's bytes. Only Markdown checkpoint reconciliation follows the validated source.
