# KANTA physical-device acceptance

Status: **not run**. The simulator baseline and 120 package tests do not close this gate.
Use an internal TestFlight build from the manual workflow. No local build setup is required for testers.

## Evidence to record for each run

Commit SHA, marketing version/build number, TestFlight run URL, tester, date,
device model/OS, audio route, media kind, SF2 size, reproduction steps, actual
result, and an artifact reference (screen capture/diagnostic evidence without
user songs, keys, or private library paths). Record PASS, FAIL, or NOT RUN.
Never mark a row passed from source review alone.

| Area | Exercise | Pass criteria | Result |
|---|---|---|---|
| Baseline devices | iPhone XR-class and iPad 9th-generation device | Install, launch, controls usable; record exact OS | NOT RUN |
| Offline | Launch in airplane mode with previously downloaded library | Browse/play/queue/lyrics work without developer service | NOT RUN |
| Media | Authorized MIDI/KAR + selected SF2; MP3/WAV; matching indexed pair | Correct playback/fidelity; no guessed unsupported payload | NOT RUN |
| Queue | Reserve A/B/A, natural completion, manual Next near end, failed next asset, retry | FIFO, no lost reservations, no duplicate transitions | NOT RUN |
| Scoring | OFF; permission denied; ON; same song twice; pause; manual Next; natural end; ambiguous melody | No mic while OFF; one valid final score per completion; clean next session; no invented score | NOT RUN |
| Audio routes | Speaker, wired/Bluetooth; calls/Siri/interruption; route removal; pause/resume | No stuck audio, crash, duplicated playback, or invalid scoring; record latency | NOT RUN |
| Large SF2 | Preferred/fallback bank; repeat songs; switch while paused/playing; memory pressure | UI/audio responsive, no unintended reloads, correct fallback sound, preference preserved | NOT RUN |
| Performance | 30-minute session with stage/scoring on at baseline hardware | No crash, sustained audio dropouts, lost input, or uncontrolled memory growth; record thermal/memory/battery evidence | NOT RUN |
| Files | iCloud placeholder, provider offline, moved folder, revoked bookmark, corrupt file, insufficient disk | Clear recoverable error; originals preserved; reauthorize/retry works | NOT RUN |
| iCloud | Signed container access, save selected categories, interrupt/retry, delete backup | Entitlements work, prior backup survives failures, source files remain, honest upload status | NOT RUN |
| Companion | Trusted LAN, denied permission, wrong PIN, rotation, reconnect, rapid local + remote commands | Unpaired rejected, rotation revokes, queue remains authoritative; confidentiality remains a separate gate | NOT RUN |
| Accessibility/layout | Large Dynamic Type, VoiceOver, Switch Control, iPad rotation/split view, fullscreen | Controls reachable/labeled; lyrics legible; no clipping or duplicate transport | NOT RUN |

Attach results to a dated successor report in Docs and link it from the release
checklist. Failed rows require fixes and targeted retests against the new build.
A future external-release workflow must validate evidence for the intended
candidate and require explicit owner sign-off for any accepted exceptions.

