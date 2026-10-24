# Reconstruction evidence and work ledger

Date: 2026-10-15. Destination: kanta-gelo/Kanta-reborn.

## Current checkpoint

Canonical online repository: `usermalik20-del/Kanta-reborn`; the requested `kanta-gelo/Kanta-reborn` URL redirects to this owner. Main is at `ebe2f7ae42dcb578e6247adbd2be09a3cf24b57b` (`fix(web): remove stale build links and provenance`). On that exact main SHA, Vercel deploy run [40009517898](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009517898), website validation [40009517823](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009517823), unsigned iOS artifacts [40009518032](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032) and reconstruction validation [40009517716](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009517716) succeeded.

Release acceptance is still blocked. The latest full walkthrough on main is run [39992413296](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/39992413296) on older SHA `81148475474742cf417d386ff4713b44cf58df0e`; it failed iPhone accessibility uniqueness and iPad Search/keypad flows. PR #58 run [40003404013](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40003404013) passed iPhone but failed three iPad keypad cases. The active repair consolidates embedded Stage Search/Queue and Host panels under one root HostView sheet identity, with owner-specific gate completion. Changed-head reconstruction and full iPhone/iPad walkthrough are mandatory before release acceptance.

The latest main unsigned personal-signing artifact is `KANTA-personal-unsigned`, artifact [12526580325](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032/artifacts/12526580325), expiring 2026-10-30. It is not a signed or directly installable release. GitHub Releases has no published release, and verified-download packaging has not produced a release bundle for the latest main SHA.

## Completed preparation

- Read the original recovery report and architecture/engineering instructions.
- Selected the original stage-ui-66ac7381630c snapshot as the iOS working baseline without modifying its bytes.
- Retained scoring, backgrounds and starter-pack snapshots separately; omitted nested Git metadata and caches from the new repository import.
- Captured ten live HTML pages plus CSS and the private Songbook JavaScript from https://kanta-public.vercel.app. URL, size and SHA-256 are recorded in the website manifest.
- Compared every imported file byte-for-byte by SHA-256 with its source. docs/IMPORT_MANIFEST.json records provenance.

## Evidence boundaries

Recovered iOS source is partial. Across four original snapshots there were 131 distinct Swift paths. The recovery report lists 58 paths absent relative to an older cached tree. Original upstream history and the latest source are unavailable. The selected baseline is not verified buildable. Android source is absent.

Website claims are product evidence, not proof that reconstructed code works. Homepage/platform pages identify Android test build 5c555260a6f9 and unsigned iOS experimental build 0b287c76ccf2. They explicitly leave physical-device, signing, accessibility and security acceptance open. Some pages contain older plaintext-remote wording while Android describes encrypted companion pairing; resolve this by source/protocol tests, not guesswork. Captured download links still point at the old kanta-ph account and are not newly working releases.

## Website-derived requirements

| Area | Required behavior / acceptance boundary |
| --- | --- |
| Playback | Offline-first user-owned MIDI/KAR plus SF2 and MP3/WAV; unsupported catalog-only rows cannot be queued |
| Starter songs | Morning Light, Sing Together, Starlight Echo; synced lyrics, generated tone, remove/restore |
| Karaoke stage | Bold centered timed lyrics, responsive phone/tablet controls, fullscreen, independent TV stage |
| CONTROL | Title/artist/code search, number pad, reserve/cancel, combined play/pause and Next; user-approved voice search |
| Queue | FIFO with singer names, reorder, saved sessions, Favorites and editable playlists |
| Visuals | First-party scenic assets, user photos/videos and optional front-camera preview; no live video recording |
| Soundcard | Safe wired/USB routes, monitoring, FX, dry scoring, calibration and experimental pitch correction |
| Party | Eight first-party SFX, stop-all, independent volume, optional user clips and intermission music |
| Songbook | Private encrypted metadata export and local browser unlock, search, CSV/print; no public catalog |
| Companion | Pairing, authorization, revocation and replay protection; real-device cross-platform security acceptance open |
| Privacy | Local library, opt-in sensors, speech-provider disclosure, offline policies and software notices |
| Future | Vocal Fit, harmony and quizzes are future plans, not recovered shipping functionality |

## Next implementation sequence

1. Publish the recovery import using the now-verified kanta-gelo connection, on a branch without triggering CI.
2. Audit iOS references and missing dependencies; reconcile original snapshot variants and restore missing storage/compression/SFX infrastructure before UI additions.
3. Establish a native Android project and a tested domain model for imports, lyrics, playback identity and the authoritative FIFO controller.
4. Reconstruct native playback and KAR/SF2 handling, then responsive stage/control and persistence. Use original assets only with verified provenance.
5. Define interoperable encrypted Songbook fixtures and a reviewed companion protocol; implement neither by copying unsupported marketing assumptions.
6. Add opt-in microphone/camera/effects with permissions and route safety, legal/privacy screens and focused tests.
7. Run authorized cloud builds; retain failed acceptance items explicitly. Signing and release links require actual new artifacts.

## Checks actually performed

Public destination repository was read successfully. SHA-256 import verification passed. No Swift/Xcode/Android build, GitHub Actions run, merge, deployment or signing occurred. The kanta-gelo connection now reports admin/write access. Publication uses a dedicated recovery branch; the earlier suspension/authentication blocker is resolved.


## Native reconstruction checkpoint — October 15, 2026

Recovered 78 missing iOS paths, including 60 Swift files, individually without overwriting the stage baseline. Reconstructed absent Favorites/playlists, SQLite catalog, CSV/private Songbook, SFX and C compression infrastructure; repaired older LAN pagination and singer interfaces and restored asset-catalog metadata. New focused Swift storage/export tests require Apple/Swift execution.

Android now has a native Java/Gradle foundation for app-private imports, MIDI/KAR/audio playback, timed lyric lines, FIFO/singer queues, saved sets, scenic/fullscreen/TV stage, keypad/voice search and metadata exports. Missing advanced features are explicit in apps/android/README.md. Owner coding/context guide and conservative publishing policy are retained. Official YouTube playback is queued; no ad blocking or DNS workaround is included.

Actual checks: 50 recovered release-tooling tests, four starter-generation tests and resource guard passed. Nine Android runtime Java files compiled against official API 36 references and Java 17 libraries; 46 domain regression checks passed. New Swift files parsed with tree-sitter; five untouched original files exceed that grammar, so this is not a full Swift syntax/build result. C compiled on Linux for its unsupported-codec branch; Apple codec is untested. No Gradle APK/lint, simulator/device launch, CI run, signing, merge or deployment is claimed. Next gate: authorized cloud build validation before release claims.

Actual browser interoperability check also passed: a fresh synthetic Android export decrypted through the captured browser function; wrong-code and tampered-payload checks rejected. Current root workflows now run relevant reconstruction checks automatically for feature/main pushes and pull requests, with the full iOS runtime suite following same-repository iOS pull requests and successful main validation. Website checks and download-packaging contract tests are also automatic on relevant changes. Packaging accepted binaries remains owner-gated. Automatic trigger configuration is not evidence that a run has executed; inspect the final commit's Actions runs before reporting validation.
