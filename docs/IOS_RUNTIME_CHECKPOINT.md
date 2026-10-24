# iOS runtime and personal-signing artifact checkpoint

Validated source: `3c12a1fb962ac956250a8f238c01eace13f560d2`.

[Run 38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805) passed full app/UI compilation, all three walkthrough tests on iPhone and iPad, and unsigned iPhoneOS archive/IPA packaging. The repaired tests reset orientation between cases and wait for stable visible controls; no assertions were removed. Captures distinguish real starter playback from named demo interactions.

Artifacts retained for seven days:

- `KANTA-personal-unsigned` — artifact 12007058242, unsigned device IPA, SHA-256 and source/run metadata.
- `ios-runtime-evidence` — artifact 12007023405, iPhone/iPad screenshots, videos, XCTest results and build diagnostics.
- `ios-iphone-runtime-evidence` — artifact 12006654573, early iPhone evidence.

The IPA is a separate personal-signing input with iCloud capabilities omitted. It is not signed, directly installable, TestFlight-uploaded or physical-device accepted. Ordinary builds retain original Apple identities/capabilities. Core package source remains unchanged from the 158-test passing checkpoint. This reconciliation changes documentation only after the validated source.


## iOS — Search request lost during sheet dismissal (2026-10-17)

**Fingerprint:** `KantaVisualWalkthroughUITests.testStarterPlaybackAndControls`; one tap on `stage.search` after Library sheet dismissal does not show the keypad.

**Prior failure evidence:** [runtime run 39014560050](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/39014560050), source SHA `6273e16b0b1c66b50a62e1026d87fbcb9c5ad7df`, on iPhone and iPad. The earlier ledger confirms the Library title wait was wrong; the exact topmost presenter in that failure remains unconfirmed.

**Confirmed code defect in PR #36 candidate:** after Done sets the navigation sheet identity to nil, `KantaPresentationGate` retains navigation ownership until SwiftUI's `onDismiss`. A Search tap in that interval received `false` from `acquire(.stage)` and the tap was discarded. This code-path defect is confirmed by inspection; its contribution to the historical simulator failure remains to be confirmed by runtime evidence.

**Candidate repair:** commit `ceafa768744c21e24a3ebe9b301eea814b7f42f2` queues one pending request per owner and activates it from `completeDismissal`; Root, Host and Stage now submit their sheet actions through that API. The existing walkthrough remains a one-tap regression. No assertions were removed and no waits/retries were added.

**Validation:** candidate. PR #36 reconstruction run `39024475624` passed the prior head `5d81f5d1addd9731c862d45c7a11308e1814a3f4`; it does not validate this commit. Current-head Swift compilation, package tests and iPhone/iPad walkthroughs remain pending. The exact original failure mechanism is still unconfirmed. Fullscreen UIKit coordination remains open.


## Fullscreen presentation-gate integration candidate — 2026-10-17

PR #36 now routes UIKit fullscreen acquisition and dismissal through the shared main-actor presentation gate. CONTROL-to-fullscreen handoff is queued before CONTROL releases its sheet owner. Search and Queue remain usable within fullscreen through a nested stage slot that restores the fullscreen parent after sheet dismissal. UIKit ownership is released only after the player dismissal completion callback. The walkthrough now exercises Search within fullscreen and again after exit. Current-head compilation, iPhone/iPad runtime and unsigned IPA remain pending; this is not runtime acceptance.

## iPad embedded Stage presentation — 2026-10-24

Candidate source tree: `fix/ipad-stage-sheet-host-20261024`, based on PR #57's `49e3f8ea111cf985c9e768e1d0a9a2a5d17bbc7b` release-acceptance candidate.

The full walkthrough [#39996051824](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/39996051824) compiled app and UI tests and completed the iPhone walkthrough, but the iPad Pro 11-inch run failed three Search/keypad cases. The exported hierarchy showed the embedded Host stage and Search button with no presented Stage sheet. The gate's runtime owner was not logged, so the internal SwiftUI failure path remains unconfirmed.

The candidate moves embedded Search/Queue presentation state to HostView and attaches the sheet to the stable scroll-container presenter. Fullscreen Search/Queue remain hosted inside the UIKit fullscreen controller; both use the same presentation gate and HostViewModel. Search accessibility IDs are now unique by projection. The test suite retains the failing flows and adds a bounded keypad-existence wait; the source guard checks the parent/child presenter boundary. No queue, playback, media, persistence or dependency changes.

Status: **candidate only**. Reconstruction and full iPhone/iPad walkthrough on the new candidate tree must pass before this is accepted for release.


## iPad Stage Search recurrence — 2026-10-24

The initial HostView-owned scroll-container sheet candidate did not resolve the iPad regression. PR #58 walkthrough [#40003404013](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40003404013) passed iPhone but failed iPad cases where embedded Search did not present `stage.keypad.0`. Source inspection found a root Host sheet and a second embedded-stage sheet on separate branches of the same SwiftUI hierarchy. The exact presenter failure remains uninstrumented, so this is a source-backed architectural hypothesis, not a claimed runtime trace.

The current candidate consolidates embedded Search/Queue with CONTROL/session-save/Favorites under the single root HostView sheet identity and completes the matching `.stage`/`.host` gate from `onDismiss`. Fullscreen Search/Queue remain nested under the UIKit fullscreen host. Changed-head reconstruction and both-device walkthrough are required before acceptance.


## iPad embedded Stage sheet recurrence and UIKit presenter candidate — 2026-10-24

Walkthrough #40070268797 (https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40070268797) on 2db140c passed iPhone but failed iPad in three keypad cases. Failure logs show stage.keypad.0 missing after embedded Search, including the direct smoke path and the post-Library path. The sibling-anchor change was not sufficient.

The current candidate uses KantaEmbeddedStageSheetPresentation and a dedicated UIKit UIHostingController for embedded Search/Queue, while Host panels and fullscreen child sheets keep their existing owners. The gate remains shared and dismissal-driven. The first focused smoke for source head d9d5fa1 failed at the static contract guard before app compilation; commit 4ff9a4d fixes the guard to match the captured gate callback. The new full walkthrough and reconstruction runs must complete on the exact latest head before this is considered accepted. No signed or installable release is established.
