# iOS runtime and personal-signing artifact checkpoint

Validated source: `3c12a1fb962ac956250a8f238c01eace13f560d2`.

[Run 38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805) passed full app/UI compilation, all three walkthrough tests on iPhone and iPad, and unsigned iPhoneOS archive/IPA packaging. The repaired tests reset orientation between cases and wait for stable visible controls; no assertions were removed. Captures distinguish real starter playback from named demo interactions.

Artifacts retained for seven days:

- `KANTA-personal-unsigned` — artifact 12007058242, unsigned device IPA, SHA-256 and source/run metadata.
- `ios-runtime-evidence` — artifact 12007023405, iPhone/iPad screenshots, videos, XCTest results and build diagnostics.
- `ios-iphone-runtime-evidence` — artifact 12006654573, early iPhone evidence.

The IPA is a separate personal-signing input with iCloud capabilities omitted. It is not signed, directly installable, TestFlight-uploaded or physical-device accepted. Ordinary builds retain original Apple identities/capabilities. Core package source remains unchanged from the 158-test passing checkpoint. This reconciliation changes documentation only after the validated source.
