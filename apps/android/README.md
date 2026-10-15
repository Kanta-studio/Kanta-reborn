# KANTA Android reconstruction preview

New native Java/Android Views source reconstructed from documented behavior and original first-party assets. This is not recovered original Android source or a complete feature-parity release.

Implemented in source: original starter songs and scenic images; app-private MIDI/KAR/MP3/WAV import; native SF2 MIDI synthesis and platform MP3/WAV playback; folder-tree import with cancellation; tempo/pitch/volume controls; source-timed highlighted lyric fragments, adjustable type and optional Realm lights; synthesized/custom party pads and opt-in between-song music; one singer/FIFO reservation queue; saved playlists and played-session Favorites; starter remove/restore; keypad/RES and optional device-provider voice search; fullscreen/TV stage; explicit CSV/private encrypted Songbook export; offline privacy/rights notices and audio-focus handling.

Remaining: microphone monitoring/scoring/DSP, camera/video backgrounds, companion networking. Loop and Realm now expose their implemented audio and animated-stage controls. No YouTube player or ad blocker is implemented.

Source b3a6cd7c passed cloud run 38807243721: NDK APK/instrumentation assembly, lint, 201 core assertions, native sanitizer checks, browser interoperability and 28 real API 35 emulator checks, including transactional SAF imports, byte integrity, party clips and intermission. Physical-device audio and performance acceptance remain open.

Build: AGP 8.13.2, verified Gradle 8.13 wrapper, Java 17, minSdk 26, targetSdk 36. The new reconstruction package is `ph.kanta.reborn`; the original Android package/signing identity has not been recovered. No signing keys are bundled. TinySoundFont is included under MIT; see THIRD_PARTY_NOTICES.md. Native builds use NDK 27.2.12479018 and CMake 3.22.1.

See ../../docs/ARCHITECTURE.md and ../../docs/CODEBASE_CONTEXT_PACKET.md.

Import bounds: MIDI 16 MiB / 250,000 events / six hours; SF2 32 MiB with strict structure and sample validation; folder scan 10,000 entries, 1,024 directories and depth 16. SF3, negative coarse sample offsets (unsupported safely by the pinned loader), and unsupported/oversized banks are rejected. MIDI poly/channel pressure, SoundFont modulators and effects are not implemented by the selected renderer. Folder selection makes private copies; it does not watch or edit the source. Bank changes apply to subsequent playback.

Party pads are first-party synthesized WAVs with at most four concurrent SoundPool voices. Import a short MP3/WAV into My Set to assign a custom pad (8 MiB / 30 seconds maximum, also bounded below SoundPool’s 1 MiB decoded limit). Between-song music selects an imported MP3/WAV, starts only when explicitly enabled and the karaoke queue is idle, and stops for karaoke, focus loss or leaving the foreground. Enabling is not restored automatically. Party volume is independent of karaoke volume.

Custom pads must also decode within a 900 KiB PCM allowance (with space below SoundPool's 1 MiB limit); high-quality stereo clips need to be shorter. Rejected files remain playable in My Set, and are never truncated or rewritten by KANTA. See https://developer.android.com/reference/android/media/SoundPool .


Validated Android stage/party checkpoint: source b3a6cd7c795e2aaea4e48254ede290b4f616d671 passed run 38807243721 with 201 domain assertions, 28 actual API 35 emulator checks, NDK APK/instrumentation assembly, lint, native sanitizer checks and browser interoperability. Covered nested/cyclic SAF traversal, partial failure, cancellation/reopen, byte identity, custom pad decode/reset, bounded voices, stop-all, intermission gating and real karaoke playback. Only Markdown reconciliation follows that source. Personal photo/video, camera, microphone, companion and official YouTube work remain separate; no physical-device or signed-release claim is made.
