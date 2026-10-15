# KANTA Android reconstruction preview

New native Java/Android Views source reconstructed from documented behavior and original first-party assets. This is not recovered original Android source or a complete feature-parity release.

Implemented in source: original starter songs and scenic images; app-private MIDI/KAR/MP3/WAV import; native SF2 MIDI synthesis and platform MP3/WAV playback; folder-tree import with cancellation; tempo/pitch/volume controls; source-timed highlighted lyric fragments, adjustable type and optional Realm lights; synthesized/custom party pads and opt-in between-song music; one singer/FIFO reservation queue; saved playlists and played-session Favorites; starter remove/restore; keypad/RES and optional device-provider voice search; fullscreen/TV stage; explicit CSV/private encrypted Songbook export; offline privacy/rights notices and audio-focus handling.

Remaining: microphone monitoring/scoring/DSP, camera/video backgrounds, companion networking. Loop and Realm now expose their implemented audio and animated-stage controls. No YouTube player or ad blocker is implemented.

Hosted validation passed Gradle APK assembly, Android lint, all 46 domain regression checks and browser interoperability for the encrypted Songbook export. Debug APK and lint reports are retained in CI artifacts for seven days. This validated baseline is merged as PR #1. The media branch passes 167 local core assertions, native sanitizer/malformed-bank checks and Java API compilation; hosted NDK/lint and the new emulator runtime checks remain pending. Physical-device playback acceptance remains open.

Build: AGP 8.13.2, verified Gradle 8.13 wrapper, Java 17, minSdk 26, targetSdk 36. The new reconstruction package is `ph.kanta.reborn`; the original Android package/signing identity has not been recovered. No signing keys are bundled. TinySoundFont is included under MIT; see THIRD_PARTY_NOTICES.md. Native builds use NDK 27.2.12479018 and CMake 3.22.1.

See ../../docs/ARCHITECTURE.md and ../../docs/CODEBASE_CONTEXT_PACKET.md.

Import bounds: MIDI 16 MiB / 250,000 events / six hours; SF2 32 MiB with strict structure and sample validation; folder scan 10,000 entries, 1,024 directories and depth 16. SF3, negative coarse sample offsets (unsupported safely by the pinned loader), and unsupported/oversized banks are rejected. MIDI poly/channel pressure, SoundFont modulators and effects are not implemented by the selected renderer. Folder selection makes private copies; it does not watch or edit the source. Bank changes apply to subsequent playback.

Party pads are first-party synthesized WAVs with at most four concurrent SoundPool voices. Import a short MP3/WAV into My Set to assign a custom pad (8 MiB / 30 seconds maximum). Between-song music selects an imported MP3/WAV, starts only when explicitly enabled and the karaoke queue is idle, and stops for karaoke, focus loss or leaving the foreground. Enabling is not restored automatically. Party volume is independent of karaoke volume.
