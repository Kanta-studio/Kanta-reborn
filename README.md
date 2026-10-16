# KANTA Reborn

Separate native Android and iPhone/iPad karaoke applications, together with their restored public website.

**Testing reconstruction:** Android 0.7.0 includes private photo/video stages, opt-in front-camera preview and optional dry microphone input level/pitch and experimental wired/USB monitoring with local voice effects. iOS combines recovered original modules with reconstructed infrastructure. Physical-device quality and production app signing remain incomplete.

| Location | Purpose |
| --- | --- |
| `apps/android/` | Native Java/Views app with independent Gradle build |
| `apps/ios/` | Reconciled Swift app and independent Apple build |
| `apps/web/` | Static website and private browser Songbook |
| `recovery/ios/` | Preserved historical source snapshots |
| `docs/evidence/website/2026-10-15/` | Immutable original website evidence |
| `docs/CODEBASE_CONTEXT_PACKET.md` | Actual stack, storage, playback, networking and performance risks |

## Verified downloads

- [Android 0.7.0 bundle](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38842836405/artifacts/12021832205): debug APK, checksum and build record.
- [iPhone/iPad unsigned bundle](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38842836405/artifacts/12022495243): requires separate trusted personal signing; iCloud Save unavailable.
- [Public website](https://kanta-public.vercel.app): platform availability, instructions and private browser Songbook.

GitHub sign-in is required. Bundles last 30 days from October 16, 2026 and preserve original accepted app bytes. Separate CI runs can use different Android debug certificates; uninstalling to change builds removes private app state. Keep original media and explicit exports backed up. These are not store releases.

## Accepted checks

| Scope | Result |
| --- | --- |
| Android [38842165486](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38842165486) | 268 domain assertions, 90 API 35 emulator checks, APK/instrumentation build, lint, native sanitizers, browser interoperability and merged-APK permission/notices gate |
| iOS package [38802025283](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38802025283) | 158 Swift package tests and unsigned simulator compilation |
| iPhone/iPad [38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805) | All three walkthroughs on each simulator, app/UI compilation and unsigned iPhoneOS archive/IPA |
| Download packaging [38842836405](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38842836405) | Five contracts and original artifact/source/checksum verification |
| Original website checkpoint [38813213292](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38813213292) | Ten-page routes/anchors, metadata, CSP, preserved reader, download provenance and JavaScript syntax |

The original browser reader remains unchanged. The homepage/Android download and Songbook missing-file UI were inspected on desktop after the workspace recovered. The 0.5.0 website refresh passed static run 38837349896 and all 15 public preview responses. A synthetic private Songbook unlocked in the real browser; matching/no-match search, CSV export and Lock passed. Browser CSV text matches the native fixture with its expected spreadsheet BOM.

Android calibrated melody scoring, pitch correction, secure companion networking and official YouTube playback remain unfinished. Experimental monitored output is implemented, with physical wired/USB audibility, feedback and latency unverified. Camera is preview-only, explicitly enabled, and disabled on backgrounding. Physical camera orientation/quality, audio latency, external display and production signing remain separate acceptance gates.

See [architecture](docs/ARCHITECTURE.md), [testing](docs/TESTING.md), [camera checkpoint](docs/ANDROID_CAMERA_CHECKPOINT.md), [personal-media checkpoint](docs/ANDROID_PERSONAL_MEDIA_CHECKPOINT.md), [iOS checkpoint](docs/IOS_RUNTIME_CHECKPOINT.md), [website checkpoint](docs/WEBSITE_CHECKPOINT.md) and [handover](docs/HARDENING_HANDOVER.md). Current checkpoints supersede dated recovery notes.
