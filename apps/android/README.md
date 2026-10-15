# KANTA Android reconstruction preview

New native Java/Android Views source reconstructed from documented behavior and original first-party assets. This is not recovered original Android source or a complete feature-parity release.

Implemented in source: original starter songs and scenic images; app-private MIDI/KAR/MP3/WAV import; platform playback; timed lyric lines; one singer/FIFO reservation queue; saved playlists and played-session Favorites; starter remove/restore; keypad/RES and optional device-provider voice search; fullscreen/TV stage; explicit CSV/private encrypted Songbook export; offline privacy/rights notices and audio-focus handling.

Remaining: custom SF2 rendering, folder-tree import, microphone monitoring/scoring/DSP, camera/video backgrounds, intermission music, SFX and companion networking. Loop and Realm show availability honestly. No YouTube player or ad blocker is implemented.

All nine runtime Java files passed source compilation against official Android API 36 definitions plus Java 17 host libraries. Forty-six domain regression checks pass. This is not a Gradle APK build, Android lint, emulator launch or device acceptance.

Build: AGP 8.13.2, verified Gradle 8.13 wrapper, Java 17, minSdk 26, targetSdk 36. The new reconstruction package is `ph.kanta.reborn`; the original Android package/signing identity has not been recovered. No signing keys or runtime third-party dependencies are bundled.

See ../../docs/ARCHITECTURE.md and ../../docs/CODEBASE_CONTEXT_PACKET.md.
