# Android camera checkpoint

Accepted source: `4da765035dd3cbeec6e69f38581138225b706e6d`.
Successful run: [38826875086](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38826875086).
Artifact: `12015651722`, android-reconstruction-checks.

The full Android pipeline passed: APK/instrumentation assembly, lint, native ASan/UBSan tone/truncation/mutation checks, all 201 domain assertions, browser interoperability and 60 actual API 35 emulator checks. The built APK has CAMERA as its only Android platform permission and includes the generated exact upstream runtime notices, 115,422 bytes. No existing regression assertions were removed.

Camera checks cover fresh-install default-off/permission state, explicit opt-in, actual front-preview rendering, fullscreen transfer and return, disable/reopen, real Home/foreground lifecycle and no automatic restart. MIDI playback's audible clock continued advancing with the camera active. The retained camera screenshot was inspected: emulated front-camera content is behind the actual original KAR lyrics and transport. These are emulator results, not physical orientation, quality, latency or thermal acceptance.

CameraX 1.5.3 and Activity 1.10.1 are pinned. Only Preview is bound; no capture, analysis or recording is implemented. The main activity uses singleTask to retain one host. Activation is transient, permission callbacks and asynchronous provider work are generation-fenced, and backgrounding unbinds/removes observers/views. Saved personal media remains byte-preserved.

Version 0.5.0 source. Microphone monitoring/scoring/DSP, secure companion networking and official YouTube remain unfinished. No Apple changes, signing materials or store release are included. Download packaging is a separate read-only action against this accepted run; only Markdown checkpoint reconciliation follows the validated source.
