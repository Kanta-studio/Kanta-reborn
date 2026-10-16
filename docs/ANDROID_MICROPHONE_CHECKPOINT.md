# Android dry microphone checkpoint

Accepted source: `c961cb3bbe76ef77bea8052529cb93a552d15a53`.
Successful run: [38839639544](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38839639544).

The Android-only pipeline passed APK/instrumentation assembly, lint, native ASan/UBSan tone/truncation/mutation checks, all 233 domain assertions, browser interoperability, the CAMERA/RECORD_AUDIO-only platform-permission and offline-notices gate, and 78 actual API 35 emulator checks. All prior assertions remain enabled.

New runtime coverage includes fresh-install default-off and permission state, rejection without permission, explicit real AudioRecord frames, silent-input pitch rejection, stop/native release, reopen, Home/background release, no restart on foregrounding, late permission/background fencing, rapid replacement, unchanged karaoke ownership and simultaneous camera/MIDI/input with an advancing audible clock. These are emulator results; physical microphone quality, device compatibility, input latency and acoustic isolation are unverified.

Version 0.6.0 adds dry input level and bounded monophonic pitch estimates only. There is no microphone output, saved recording, effects or completed-song score. PCM remains in bounded memory; interrupted input disables the run. Camera and existing local media behavior remain covered. iOS source is unchanged.

Monitoring, safe output routing, vocal effects, calibrated target-based scoring, secure companion and official YouTube remain follow-ups. Download packaging is separate and must copy this accepted APK without rebuilding. Only Markdown checkpoint reconciliation follows the validated source.

Android API references: https://developer.android.com/reference/android/media/AudioRecord and https://developer.android.com/media/platform/sharing-audio-input .
