# KANTA Reborn

Native Android and iPhone/iPad karaoke apps in one repository, with distinct platform code and a restored public website.

**Current status:** reconstructed testing builds pass the checks below. Feature parity, physical-device acceptance and production app signing remain incomplete. iOS combines recovered original modules with reconstructed infrastructure; the original Android source was unavailable, so Android is a new native implementation.

| Location | Purpose |
| --- | --- |
| `apps/android/` | Native Java/Gradle Android app |
| `apps/ios/` | Reconciled Swift app and infrastructure |
| `apps/web/` | Restored static website and private Songbook reader |
| `recovery/ios/` | Preserved historical snapshots and missing-path records |
| `docs/evidence/website/2026-10-15/` | Immutable original website evidence |
| `docs/CODEBASE_CONTEXT_PACKET.md` | Stack, storage, playback, networking and bottlenecks |
| `docs/ARCHITECTURE.md` | Platform boundaries and ownership contracts |

## Try the verified builds

- [Android preview bundle](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38812761100/artifacts/12008224871): debug-signed APK, checksum and build record.
- [iPhone/iPad unsigned bundle](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38812761100/artifacts/12008259804): unsigned IPA, checksum and build record. Separate personal signing is required; iCloud Save is unavailable.
- [Live website](https://kanta-public.vercel.app): platform availability, download help and private browser Songbook.

GitHub sign-in is required for Actions downloads. These bundles are retained for 30 days from October 15, 2026. They preserve the original accepted application bytes and are not store releases.

## Accepted checks

| Scope | Result |
| --- | --- |
| Android [38807243721](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38807243721) | 201 domain assertions, 28 API 35 emulator checks, native sanitizer checks, APK/instrumentation build, lint and browser interoperability |
| iOS package [38802025283](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38802025283) | 158 Swift package tests and unsigned simulator compilation |
| iPhone/iPad runtime [38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805) | All three walkthroughs on each simulator, app/UI compilation and unsigned iPhoneOS archive/IPA |
| Download packaging [38812761100](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38812761100) | Five contract tests and original APK/IPA identity/checksum checks |
| Website [38813213292](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38813213292) | Ten-page route/anchor, metadata, CSP, preserved-reader, download-provenance and JavaScript syntax checks |

The live website's ten pages and four public assets were also checked against the submitted source over HTTP. Browser visual inspection was blocked by an offline workspace; no visual pass is claimed.

Android personal photo/video stages are an unmerged local draft. Android camera, microphone processing, companion networking and official YouTube playback remain unfinished. No physical audio quality/latency, camera, HDMI/AirPlay or production-signing acceptance is implied.

See [reconstruction ledger](docs/RECONSTRUCTION.md), [testing contracts](docs/TESTING.md), [Android checkpoint](docs/ANDROID_STAGE_CHECKPOINT.md), [iOS checkpoint](docs/IOS_RUNTIME_CHECKPOINT.md), [website checkpoint](docs/WEBSITE_CHECKPOINT.md) and [handover](docs/HARDENING_HANDOVER.md). Historical documents describe dated attempts; current checkpoints take precedence.
