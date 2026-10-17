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
