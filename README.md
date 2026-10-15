# KANTA Reborn

KANTA iPhone/iPad and Android reconstruction in one repository.

**Status (2026-10-15): Android and iOS build validation passed. Feature parity and device/release acceptance remain in progress.**
iOS now includes individually restored original modules and newly reconstructed missing infrastructure. Android original source was not recovered; a new native foundation implements local karaoke. This is not a release or complete feature-parity claim.

| Location | Purpose |
| --- | --- |
| `apps/ios/` | Reconciled Swift app and reconstructed infrastructure |
| `apps/android/` | Native Java/Gradle reconstruction |
| `recovery/ios/` | Separate historical snapshots and known missing paths |
| `docs/evidence/website/2026-10-15/` | Captured live website, guide, platform pages and Songbook reader |
| `docs/ARCHITECTURE.md` | Monorepo boundaries and reconstruction contracts |
| `docs/RECONSTRUCTION.md` | Evidence, current gaps and implementation sequence |

See `docs/RECONSTRUCTION.md` before making feature or release claims. Historical iOS documentation describes earlier source states and is not current verification evidence.

[Cloud validation](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38748040876) passed 158 Swift package tests, the unsigned Release simulator app build, Android APK/lint/domain checks and browser interoperability. See [testing contracts](docs/TESTING.md). No signed release, physical-device acceptance or UI automation is implied.
