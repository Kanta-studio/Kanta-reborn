# KANTA Reborn

KANTA iPhone/iPad and Android reconstruction in one repository.

**Status (2026-10-15): recovery import prepared; neither application is verified buildable.**
The iOS directory contains a historical original working snapshot. Android original source was not recovered. This is not a release and does not reproduce the latest apps yet.

| Location | Purpose |
| --- | --- |
| `apps/ios/` | Original stage-ui iOS snapshot, preserving its internal structure |
| `apps/android/` | Android reconstruction requirements; no original Kotlin/Gradle project |
| `recovery/ios/` | Separate historical snapshots and known missing paths |
| `docs/evidence/website/2026-10-15/` | Captured live website, guide, platform pages and Songbook reader |
| `docs/ARCHITECTURE.md` | Monorepo boundaries and reconstruction contracts |
| `docs/RECONSTRUCTION.md` | Evidence, current gaps and implementation sequence |

See `docs/RECONSTRUCTION.md` before making feature or release claims. Historical iOS documentation describes earlier source states and is not current verification evidence.
