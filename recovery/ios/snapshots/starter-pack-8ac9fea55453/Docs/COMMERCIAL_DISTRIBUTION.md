# Commercial Distribution Boundary

**Current merged source baseline (October 10, 2026):** `kanta-ph/Gelo-Karaoke-iOS` `main`, merge commit [`6dcdf5f`](https://github.com/kanta-ph/Gelo-Karaoke-iOS/commit/6dcdf5f675572771f0377fe2197c2cee41b4bf5c), PR #44 merged and PR #40 closed as superseded. The last green Core CI ([run #38003895381](https://github.com/kanta-ph/Gelo-Karaoke-iOS/actions/runs/38003895381)) validated **173 Swift tests**, an unsigned Release iOS Simulator build, and live Host/CONTROL simulator startup on an earlier PR head; it **did not rebuild the final in-app Legal & Privacy edit or this merge commit**. KANTA has **no verified signed TestFlight upload or physical-device acceptance** for this merged batch. Website `/legal` and `/privacy` are live and were checked on production. Historical draft/pending paragraphs below record their original dates and must not supersede this status.


Status: **active product requirement**  
Reviewed: **2026-10-07**

## Bring Your Own Library

Commercial KANTA builds operate as an independent player and interoperability
layer, not as a distributor of third-party karaoke libraries.

Users choose their own folders and files through the iOS Files picker. Sources
may live On My iPhone/iPad, iCloud Drive, or another document provider exposed
through Files. KANTA stores only the access needed for the selected location and
reads compatible content from user-controlled storage.

Optional iCloud Save is separate: it copies only categories the user explicitly
selects into KANTA's private iCloud container.

## Runtime interoperability is allowed

Runtime import is intentionally filename-neutral.

- Any user-selected `.sf2` may be imported regardless of its filename.
- An SF2 is accepted only when its RIFF/SoundFont structure is valid.
- The selected SF2 remains user-supplied BYOL content and is loaded locally for
  MIDI/KAR playback.
- Compatible indexed libraries are detected from structure and safe
  index/container correlation, not from vendor-specific filenames.
- KANTA does not require or advertise one particular provider's library.

Interoperability support does not grant redistribution rights and is not a claim
that every third-party format or file is licensed for every use.

## Distribution rules

Source control, release artifacts, app bundles, downloadable assets, and KANTA
GitHub releases must not contain user or third-party karaoke media unless the
distributor has documented redistribution rights for the exact asset.

This includes, regardless of filename:

- SoundFonts
- MIDI/KAR song libraries
- packaged audio/song media
- catalog/container payloads
- lyrics, artwork, or videos supplied by third parties

Generated synthetic fixtures that contain no third-party content may be kept in
source when they are minimal and necessary for deterministic tests.

## Build enforcement

`Tools/verify-commercial-assets.sh` is a **distribution-only** guard.

It inspects tracked repository content. It does not inspect Files/iCloud folders
selected by a user at runtime and must never be used to block a valid user-owned
SF2 merely because of its name.

The separate media-provenance guard continues to cover first-party distributed
background assets.

## Interoperability boundary

Technical format handling is isolated behind a neutral compatibility boundary.
User-facing screens, App Store metadata, screenshots, product documentation, and
normal application architecture do not depend on a third-party brand identity.

The implementation is fail-closed:

1. scan user-selected files without relying on vendor filenames;
2. structurally identify a candidate index;
3. require one safely correlated media container;
4. sample only bounded payload prefixes to confirm a supported path;
5. expose titles only after validation;
6. materialize only the selected playable payload when necessary;
7. leave the original library untouched.

Low-level format constants that are technically required to recognize an
interoperable payload remain confined to the private compatibility
implementation and are not product identifiers.

## Product messaging

Use wording such as:

> KANTA is an independent offline karaoke player that imports user-owned
> compatible libraries and SoundFonts. KANTA does not provide or sell a
> third-party karaoke catalog.

Do not market KANTA as an official client, replacement product, or affiliated
service for any third-party provider unless such a relationship actually exists.

## Legal review

BYOL architecture reduces redistribution risk but does not create blanket legal
immunity. Before commercial release, review applicable interoperability,
copyright, trademark, public-performance, and distribution obligations for the
shipping jurisdictions and actual release binary.


## Optional downloadable multilingual speech engine (2026-10-08 draft)

KANTA's draft voice pack uses `argmaxinc/argmax-oss-swift`
(`WhisperKit` product, MIT, exact v1.1.0) and the public
`argmaxinc/whisperkit-coreml` model repository (Hugging Face listing:
MIT) with **multilingual Whisper Base**. OpenAI's upstream Whisper
checkpoints are documented as Apache-2.0; confirm model conversion
attribution and included repository notices before distribution.
This feature does **not** package model weights into the app IPA,
commercial music or Karaoke user media. The model and tokenizer are
downloaded from the external host on explicit user action, with
network request metadata disclosed. Confirm vendor-host revision,
artifact integrity/provenance, license notices, and Apple guidelines
before a signed public build. Third-party ASR package and model
licenses do not confer karaoke song licensing or distribution rights.

## Project-original starter exception (PR #45)

The exact three KAR files and `kanta-tone.sf2` under Resources/StarterKaraoke are
project-generated originals, with no third-party compositions or sampled recordings.
The commercial guard permits only those four paths after exact generator-byte and
SHA-256 validation. All other song/SoundFont distribution prohibitions remain.
This is not a CC0 dedication or legal clearance; existing external commercial review
gates remain. See Docs/STARTER_KARAOKE_PACK.md for the complete provenance.
