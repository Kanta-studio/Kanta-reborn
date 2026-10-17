# Original offline starter karaoke pack — PR #45

## Resources and provenance

Morning Light (96 BPM), Sing Together (108 BPM), and Starlight Echo (84 BPM)
are short original four-line compositions generated for KANTA. The three actual
`.kar` files, SHA-256 `manifest.json`, and `kanta-tone.sf2` live under
`Resources/StarterKaraoke/`, copied as a folder resource by `project.yml`.
Regenerate with `python3 Tools/generate-starter-kar.py Resources/StarterKaraoke`.

Each KAR is Standard MIDI type 0, PPQ 480, with 16 paired melody notes, explicit
tempo/end-of-track metadata and word-timed 0xFF/0x05 lyrics. The first word of
each line carries a KAR `/` marker so the existing two/three-line stage groups
and highlights source-timed fragments correctly. These are short starter demos,
not a commercial song catalog or full-length backing arrangements.

The 100-frame looping triangle waveform in the SF2 is computed from integer
arithmetic by the same generator; it contains no sampled recording or third-party
instrument bank. It provides program 0 sound on a fresh offline installation.
Existing imported SF2 selection remains preferred, with the small bundled tone
as fallback **only for these starter songs**. No audio-engine fork is introduced.

All melodies, words, and oscillator samples were newly generated for this project.
No third-party license grant, CC0 dedication, exclusive copyright, or formal legal
clearance is asserted. Distribution uses this documented project-original
exception to the BYOL guard; external commercial publication retains the existing
publisher/legal review gates. User-imported songs and banks are never distributable
merely because the app can play them. `verify-starter-resources.py` compares exact
committed bytes and checksums against the generator; the commercial guard exempts
only the four named resource files, never an entire folder or file extension.

## Ownership, install, remove, restore

`AppServices` creates one optional `StarterKaraokeStore` and injects it into the
existing `BookmarkedKaraokeLibrary`. Initial library loading atomically copies
available KAR originals to Application Support/GeloKaraoke/StarterSongs. Stable
`starter:<slug>` IDs enter the same search index, song lookup, asset resolution,
lyric parser and scoring-target path used by Host, My Set and paired LAN search.
The original bundled SF2 remains read-only. No bookmarks or duplicate user source
registrations are created for app-owned files.

My Set/Library shows Play, Queue, Remove and individual Restore, plus Restore All
Missing Songs. The existing view model owns in-flight UI state before any await.
Play delegates to the controller's gated `playNow`, preserving FIFO reservations;
Queue uses the existing enqueue command. Open Host to see lyrics and transport.
The MIDI engine retains play/pause/seek/tempo and source-timed lyric behavior.

Removal first commits a durable tombstone, then deletes only the managed KAR copy.
It never deletes a bundled resource, imported file, or selected SoundFont.
Already loaded playback may finish; a removed song's waiting reservation remains
visible and reports unavailable if reached. Restore makes that stable reservation
playable again; the user may also remove it from Up Next normally.

Restoration copies/validates originals before clearing tombstones. Failed restore
preserves removal intent; corrupt tombstone JSON fails closed instead of silently
reinstalling removed songs. Explicit retry is safe after file/persistence failures.
Managed bytes are checked against the bundled original and repaired atomically;
symlink destinations and overlapping source/storage roots are rejected.

## Concurrency and cancellation

Store methods do not suspend during file/state transactions. Cancellation is checked
before side effects; after durable completion the library publishes the resulting
snapshot even if the UI caller cancels. Versioned store snapshots prevent delayed
actor continuations from overwriting newer catalog state. Reload adds the current
starter projection to imported entries without creating a competing catalog.
Store initialization failures leave BYOL services available and show a startup error.
Catalog mutation does not release imported scopes or delete active container caches.

## Validation and release evidence

Python tests cover deterministic bytes/checksums, MIDI structure/note pairing,
tempo/lyric timing, and SF2 RIFF/Hydra/sample structure. Swift tests cover actual
resource parsing, lyric pages/highlighting/seek state, native sampler non-silent
rendering, restart persistence, duplicate/concurrent installation and restoration,
cancellation, corrupt state, failure recovery, source isolation, catalog search and
imported SoundFont preference. Controller tests cover Play preserving reservations.

Core CI now also launches the built Release iOS Simulator app with real services
(no demo catalog): all three songs play through the native MIDI engine; pause,
seek, timed lyrics, queue, removal, process restart and offline restore are checked.
The acceptance path is compiled for Simulator only and requires an explicit CI
environment flag. JSON evidence and My Set screenshots join `kanta-core-host-smoke`.
This does not certify physical speakers, route latency, accessibility or signing.

Implementation validation status at this commit: four Python starter tests and
four existing smoke-workflow tests passed in the cloud workspace. Swift/Xcode are
not installed in that workspace; final hosted Core CI, merge and deployment remain
pending. The user explicitly authorized multiple CI/fix cycles on October 10; older
one-run-only handover text is superseded for PR #45. Update release evidence after
actual hosted results; skipped workflows never count as acceptance.
