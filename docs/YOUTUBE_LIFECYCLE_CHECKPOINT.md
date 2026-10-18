# PR #51 foreground player lifetime repair — October 18, 2026

Based on PR #51 source `77f9f1078efc05cf91cc06db4fbd93780007c87e`. The preceding reconstruction and focused iPhone smoke runs passed that base only. This batch does not inherit their green status.

Each online preview receives a distinct presentation UUID, including repeated links. `YouTubePreviewLifecycle` owns only that transient identity; it has no local transport, reservation, persistence or decoder reference. Token-matched retirement prevents a late failure/dismissal from closing a replacement. Native views have separate terminal retirement guards.

Android MainActivity synchronously releases/detaches the old WebView before constructing a replacement. Activity pause retires both preview and link-entry surfaces, and foreground return never reopens them. Dismissal/error cleanup is idempotent, main-frame load/HTTP errors are recoverable by explicit reopen, and renderer loss removes/destroys the unusable WebView without further load commands. Inactive callbacks cannot construct a new player. Android runtime instrumentation exercises native replace/repeat/pause/reopen/error/late-callback paths without depending on a remote response.

iOS uses a per-sheet native player owner to retire an existing WKWebView before attaching its replacement. UUID-based SwiftUI identity prevents same-link reuse across lifetimes. Resigning active, sheet disappearance, Stop and Done retire the native instance; suspension/blanking and delegate invalidation precede asynchronous cancellation callbacks. Picture-in-picture is disabled. Main-frame failures and WebKit process termination return to link entry with a recoverable notice. The domain tests cover repeated links, replacement, stale failure, background retirement, reopening, invalid-link preservation and distinct local reservation identities. These tests do not establish actual WKWebView/media teardown timing; iOS runtime lifecycle acceptance remains required.

Pre-push checks: Swift test-layout and presentation guards passed; 50 Python release-tooling tests and four starter-generator tests passed; deterministic starter guard and diff whitespace check passed. The Java 17 compiler module compiled the complete domain regression suite; all 479 assertions and captured-browser decrypt/wrong-code/tamper checks passed. No Swift compiler or Android SDK is available in this execution environment. Hosted Swift package/app build, Android lint/build/domain/runtime and iPhone smoke must validate the resulting head. No physical-device, signing, merge, packaging, deployment or release is claimed.

Native diagnostic: the unchanged ASan/UBSan harness compiled, but LeakSanitizer cannot enumerate process tasks under this execution environment. A diagnostic rerun with leak detection disabled passed audible pitch, transposition, truncation and 2,000 mutation checks. This does not establish leak-check success; hosted CI retains its unchanged full sanitizer command.

Remaining PR gates: audio-focus arbitration without forwarding transport commands, iOS native lifecycle runtime coverage, hosted changed-head checks, and physical-device embed/interruption/privacy/advertisement acceptance. This change does not claim simultaneous audio is prevented. Local/YouTube queues remain independent; the older mixed-source design is superseded by the owner decision in YOUTUBE_PLAYBACK_PLAN.md. UI restoration remains separate in PR #52.


## Validation follow-up — October 18, 2026

PR head `92e838c` passed Android validation (including emulator runtime), unsigned iOS simulator app build, and focused iPhone smoke run `39103776922`. Reconstruction run `39103777006` failed while compiling package tests: six direct mutating calls inside Swift Testing expectations expanded to immutable receivers. The test-only repair evaluates each call before asserting its Boolean result, preserving every assertion and production lifecycle behavior. Hosted compilation and package execution must validate the repair head before green status is recorded. See CI_FAILURE_REPAIR_LEDGER.md for the exact diagnostic and run/job identities.

## iOS local/online audio coexistence guard

Commits `2500f0bd1b951ec3f3cbabcc5882e11cc98f61be` and `ab2e2336171694ecc7e04583336b59cad7ebe2d5` pass the authoritative HostView transport into the opt-in online preview. While local transport is playing, opening an online video is disabled; if local playback becomes active during an online preview, the native player owner retires its WebView and clears its preview identity. No local queue mutations or remote transport forwarding are introduced.

This is an iOS UI/lifecycle guard, not complete audio-session arbitration: Android coordination, remote playback races, intermission/SFX, simulator runtime checks and physical-device audio interruption behavior remain open. The change has not yet been compiled or tested on its new head. Do not claim that simultaneous audio is universally prevented.


## Verified hosted checkpoint — October 18, 2026

Source `5c1b0f4eea9f92196b836a8bbf2980a5bb6793ad` passed reconstruction run [39106105837](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39106105837) and focused iPhone smoke run [39106105865](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39106105865). Reconstruction job steps confirm Swift package/test compilation, package execution, unsigned simulator application build, Android assembly/lint/domain regression, full native sanitizer gate and emulator runtime checks passed. This closes the earlier Swift Testing macro compilation failure after repair `1ca7454`; no assertions were removed. It also validates the subsequently added iOS/Android local-playing preview-entry guards on this source.

This is hosted evidence for the named SHA only. The smoke test is navigation coverage, not iOS native online-player lifecycle acceptance. General audio-focus/session arbitration, Android remote/asynchronous-start preview reconciliation, iOS runtime online lifecycle coverage and physical-device embed/interruption/ads acceptance remain open. No merge, signing, packaging, deployment or release is claimed.


## Android online preview follows authoritative playback publication — October 18, 2026

Baseline: PR #51 `5c1b0f4`, whose reconstruction and focused iPhone smoke checks passed. The online/local overlap guard previously ran only after primary Play/Next button callbacks. Encrypted companion commands bypass those callbacks, and backend start acknowledgement is asynchronous, so those paths could leave a visible online player alive after local playback started.

MainActivity now reconciles the preview at the start of the existing SessionController listener's render callback. All published local starts/resumes retire the online instance; primary buttons again issue only controller commands. The preview owner does not pause local transport, consume reservations or introduce a playback queue. Replacement/dismissal guards remain unchanged. This closes a controller-observation gap, not general OS audio-focus arbitration or a guarantee of zero overlapping audio frames. SFX/intermission, iOS native runtime and physical audio/session acceptance remain separate.

The Android instrumentation uses real KCP1 socket commands to reserve/start a local starter while a preview is open, waits for backend start acknowledgement, verifies native preview retirement, pauses, explicitly reopens the preview, resumes remotely and verifies retirement again. Reservation alone must preserve the preview, normal FIFO consumption remains checked, and local Stop must not reopen online playback. New-head APK/lint/emulator acceptance is pending. No website, dependency, permission, persistence or remote-protocol change.
