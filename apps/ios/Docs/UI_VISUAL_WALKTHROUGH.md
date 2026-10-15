# KANTA real simulator visual walkthrough

October 11 update: source prepared; the updated tests have not run on iOS.

The default app surface is now the stage. The retained manual screenshot/video
workflow builds `KantaUITests` and captures both iPhone and iPad. No Actions
were dispatched for this implementation.

- `testStarterPlaybackAndControls` uses real bundled Morning Light through
  More → Song Library, then returns to the stage and taps Play/Pause and Search.
- `testMainMenuButtonsAndScreens` opens real destinations via More.
- `testDemoKeypadCancelAndRepeatedIntentionalReservations` is explicitly DEMO
  evidence. It checks all digits including zero, Cancel, double-tap suppression,
  distinct repeat reservations, and landscape keypad reachability.
- Attachment names separate `real-*` from `demo-*`. Simulator video may be silent.
- Camera hardware is unavailable on simulator: never label an illustrative camera
  image or permission alert as a working camera capture.

Before release run the approved capture workflow, inspect its actual artifacts,
and test front-camera permission/denial, portrait/landscape, stop while requesting,
background/foreground, interruptions, and simultaneous karaoke/audio/scoring on
physical iPhone XR and iPad 9 or newer. Existing artifacts from older commits
cannot validate this stage redesign. See Docs/STAGE_UI_ACCEPTANCE.md.
