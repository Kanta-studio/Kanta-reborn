# Android personal-media checkpoint

Accepted source: `2ced06c5c6063e15e227cc094b2462a36a03e7f2`.
Successful run: [38825170997](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38825170997).
Artifact: `12014902550`, android-reconstruction-checks.

The complete Android pipeline passed: APK and instrumentation assembly, lint, all 201 domain assertions, native ASan/UBSan tone/truncation/2,000-mutation checks, actual browser Songbook interoperability and 47 actual API 35 emulator checks. The original playback, FIFO, cancellation, controls, pause/resume, failed preparation, folder, pad and intermission assertions remain enabled.

New checks cover photo/video byte identity and persisted selection, cancellation and malformed-media rollback, switching back to saved media, stable stage-subtree identity, all five unclipped navigation tabs, actual muted-video first-frame rendering and deactivation/reactivation. The retained runtime screenshot was inspected and shows original starter playback with timed lyrics, the original app mark and all five visible tabs. Instrumentation diagnostics survive emulator shutdown.

Version 0.4.0-reconstruction adds bounded private photo/video stage imports. No source media is rewritten; no camera/microphone/network permission or second karaoke queue is introduced. Hardware decoder compatibility, image orientation across physical devices, audio quality/latency and external displays remain separate acceptance work. Camera, microphone processing, companion and official YouTube remain unfinished.

The existing download bundles still refer to their recorded earlier accepted builds until the packaging workflow is explicitly updated and verified. No production signing or app-store release is implied. Only Markdown reconciliation follows the source validated above.
