# KANTA Reborn architecture

## Repository boundaries

`apps/ios` retains the original Swift app structure, project.yml, Package.swift, Sources, Resources and Tests. The original stage-ui snapshot is the selected baseline because it includes the latest recovered stage implementation; missing paths have been restored individually and absent infrastructure reconstructed; Apple build acceptance remains open. Original Apple bundle identities and iOS 17 minimum remain subject to the recovered project configuration.

`apps/android` contains a new native Java/Android Views reconstruction, explicitly distinct from original source, with its own Gradle build and signing boundary. See its README for implemented and missing features.

`recovery/ios/snapshots` contains other original snapshots without nested Git databases. They are evidence, not dependencies. Complete recovery ZIPs remain preserved separately. Historical source variants must be reconciled file by file.

`docs/evidence/website/2026-10-15` stores exact public-site bytes, extracted readable text and URL/SHA-256 manifest. It is evidence only, not a newly deployed website. No public song catalog may be added.

## Runtime contracts

Each platform has one playback controller and FIFO reservation queue. UI, lyrics, fullscreen/TV stage and companion control project that owner's state. Import and persistence run away from latency-sensitive playback/UI work; commits are atomic and stale async results cannot replace newer state. Retry suppression applies to the same operation ID, never separate intentional reservations.

Scoring is default off and observes dry microphone input without storing audio. Completion scores belong to immutable playback identities and are emitted only once. Monitoring and pitch processing are separate opt-in services and must mute on unsafe output routes. Source media and user SF2 are byte-preserved.

Companion commands require explicit pairing, authorization, bounded replay protection and revocation. Website descriptions conflict between older plaintext PIN control and newer encrypted Android pairing; do not implement or advertise cross-platform transport compatibility without an explicit reviewed protocol and tests.

## Build isolation

Historical `.github` directories nested inside app/recovery folders do not run as root GitHub workflows. The new root reconstruction-validation workflow runs only by explicit manual dispatch or an owner-applied owner-approved-validation label. It has no push/synchronize trigger, read-only repository permissions, bounded timeouts and pinned action revisions. Publishing code does not launch it. Signing secrets never belong in Git. The iOS job explicitly selects Xcode 26.2 on macos-15 to satisfy Package.swift tools version 6.2; the image default Xcode 16.4 is insufficient.

## Shared material

Shared future files are limited to independently verified first-party assets and documented interoperability formats. Native playback state and UI code remain platform specific. The captured Songbook JavaScript may inform a compatibility specification; a claim of compatibility requires cross-platform fixture tests.

## Reconstructed storage and export boundaries

On iOS, SavedKaraokeSetStore performs synchronous atomic write-before-publication transactions inside its actor, retaining durable Save operation keys. SQLiteSongCatalog is owned solely by BookmarkedKaraokeLibrary; validated metadata replaces atomically and query terms are bound. CSV is metadata-only with quoting/formula neutralization. Private Songbooks derive an AES-GCM key from a random per-export 128-bit code using the captured browser format. The SFX actor owns at most four independent AVAudioPlayer voices and bounded private clip copies. The C codec uses bounded streaming buffers and private exclusive temporary files; Apple compilation and legacy licensing acceptance remain open. Older LAN pagination and singer APIs were reconciled; its transport remains plaintext.

## Android ownership and media

KantaApplication owns one SessionController. MediaPlayer creation, commands and callbacks stay on the main Looper. ReservationQueue gives intentional reservations distinct UUIDs with bounded replay tracking. A serial IO executor owns LibraryRepository writes and heavy file work. Search uses cached normalized song keys, immutable snapshots, a separate executor and stale-result fencing. Visible song results and reservation rows are paginated.

SAF imports create hash-identified, byte-preserved private files; AtomicFile commits metadata, queue references, saved sets and starter tombstones. SMF 0/1 lyric parsing bounds files, tracks, events, text and timing while merging tempo across tracks. Android's built-in MIDI renderer is used; SF2 overrides are not implemented. Failed prepare retains the reservation; stale or removed reservations cannot start. Native StageView, fullscreen and TV Presentation project the same playback time without a second queue or progress bar.

Explicit Android exports use the shared CSV/AES-GCM browser format. The manifest has no Internet, microphone or camera permissions. Device-provider speech is user initiated and disclosed. Advanced audio, camera/video, intermission/SFX, folder import and encrypted companion transport remain unfinished. The official YouTube integration is queued in docs/YOUTUBE_PLAYBACK_PLAN.md.


The recovered iOS LAN connection now suppresses duplicate command envelope IDs through a bounded 512-entry cache on the main actor. Completed results may be evicted; in-flight commands stay pinned. This is connection-scoped, not durable replay protection across reconnects, and does not encrypt the recovered plaintext protocol.

Final scoring uses the complete target timeline, including unheard ending windows; live scoring uses elapsed windows. Latency changes invalidate accumulated observations. Host completion applies RoomScoreReliability before publishing a final estimate. These recovered scoring contracts are reconciled from the scoring snapshot without replacing stage UI.
