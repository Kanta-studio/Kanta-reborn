# Android experimental pitch correction — October 16, 2026

## Candidate behavior

Android 0.9 adds a separate, default-off chromatic correction choice after actual wired/USB monitor routing is verified. It processes monitored voice before the existing effects. Dry microphone analysis, scoring, karaoke playback, reservation identities and imported source bytes keep their existing owners and behavior. Monitor stop, input stop, route failure and backgrounding retire the choice; foregrounding or reconnecting cannot restore it.

The first-party processor uses fixed history/window storage and two crossfaded fractional-delay taps. Stable 70–1,000 Hz dry estimates with confidence at least .85 and RMS at least .008 select a nearby semitone with hysteresis and a +/-60-cent shift bound. A complete analysis frame must follow activation or a buffer discontinuity. Estimates older than 300 ms, silence and unreliable input relax to unshifted delayed input. Invalid samples are sanitized and output is limited before existing effects. No new dependency, permission, networking, recording or Apple source change is introduced.

This is experimental chromatic processing, without melody guidance or formant preservation. The delay taps span approximately 10–95.3 ms; unshifted fallback adds 52.7 ms. These mathematical lengths do not establish total device latency. Voice quality, artifacts, feedback, physical routing and round-trip latency remain unverified.

## Verification

Fresh Java 17 compilation and all 364 domain assertions passed in this session. Independent spectral checks of four synthetic detector-to-processor tones measured target errors of 1.49, 3.14, 0.00 and 0.20 cents. Coverage also includes output continuity, block partition invariance, stale/future/extreme times, uncertainty, hysteresis, finite sample bounds, reset and storage limits. Browser decrypt/wrong-code/tamper interoperability and the complete Swift test-layout preflight passed.

The saved earlier API 36 production/instrumentation compilation log reports no errors and 14 compatibility/resource-analysis warnings; this is separate from a fresh hosted APK build and lint. Six added emulator assertions cover default-off, the disabled control before verified monitoring, missing/speaker-route rejection, preserved dry capture and lifecycle non-restart. A clean emulator has no supported physical output, so these do not prove corrected wired/USB sound.

Changed-head hosted build, lint, native sanitizer, permission/notices and complete emulator acceptance are pending. Public downloads remain on accepted Android 0.8 until successful validation and checksum-verified packaging. Secure companion control and official YouTube playback remain queued.


## Hosted Android 0.9 acceptance

Source `4f48e051dcd815e878205eda43bf9331591e279d` passed run [38881735518](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38881735518): all 364 domain assertions and 116 actual API 35 emulator checks, APK/instrumentation assembly, lint, native ASan/UBSan checks, browser interoperability and merged permission/offline-notices checks. PR #25 merged as `2851a0b81f43698a99b036b8dd28aa25c0d495eb`. Existing assertions remain enabled. The accepted output is artifact `12038226827`; checksum-verified packaging must preserve these APK bytes before changing public downloads. Physical corrected voice quality, artifacts, feedback and total latency remain unverified. Secure companion and official YouTube remain queued. This entry supersedes candidate hosted-pending statements above.


## Verified Android 0.9 download packaging

Run 38882359866 verified source/run/artifact identity, original application bytes and archive digests. Android bundle 12038451005 preserves source 4f48e051, APK SHA-256 85952b6db76dd2c418013a78895d6161cfa9310b14f57fe8b75095b4a2db1474 (26,957,042 bytes). iOS bundle 12037574662 preserves the unchanged unsigned IPA. Downloaded manifest artifact 12038027446 matched its archive digest. Website pages/manifest now select these packages with separate experimental-correction instructions; hosted website validation and production publication are pending. See WEBSITE_09_CHECKPOINT.md.
