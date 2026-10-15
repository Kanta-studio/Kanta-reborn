# Stage UI acceptance — October 11, 2026

Status: implemented source; iOS build, screenshots and camera hardware not yet verified.

## Automated gate (owner-approved macOS capacity required)

1. Run one consolidated Swift Core CI on the finished PR head. Verify Swift
   package tests, Release iOS build and Host smoke, not merely a workflow start.
2. Run the retained opt-in UI screenshot/video workflow on that same head.
   Inspect iPhone/iPad portrait and landscape, Search, 0–9 keypad, Cancel,
   explicit Reserve, Queue and one Play/Pause + Next. No progress/Previous.
3. Check real original-starter playback screenshots separately from demo tests.
   Confirm double Reserve taps add one item; two separate reservations add two.
   Cancel must not mutate the queue. Rapid A→B→A search must never select stale data.
4. Verify More destinations, detailed CONTROL/Favorites/audio settings, no lyric
   clipping at default/Large Dynamic Type, VoiceOver focus, 44-point controls,
   keyboard dismissal, iPad Split View and narrow Stage Manager windows.

## Physical camera gate

On iPhone XR and iPad 9 or newer running iOS/iPadOS 17+:

- Fresh launch is scenic; only explicit Camera triggers video permission.
- Grant/deny/restrict/revoke permission; deny must leave scenic BGV usable.
- Cancel while permission is pending; background before responding; late grants
  must not resurrect capture. Repeat camera on/off quickly and reopen app.
- Rotate both landscape directions and portrait: preview must be upright,
  mirrored, aspect-fill, with readable synchronized foreground lyrics.
- Stop Camera, More/CONTROL, app background, screen lock, incoming call,
  camera-in-use and runtime interruption restore scenery and release capture.
- Enable while a song is playing; verify no microphone prompt/audio-session
  reroute and no disturbance to wired/USB soundcard or room scoring. Voice search
  retains its existing microphone-busy guard and is independent of video.
- After Stop, audio and FIFO completion/scoring still work, no camera files or
  uploads exist, and camera does not reactivate on foreground without a tap.
- Test sustained 720p/30 fps load, thermal behavior and battery on older hardware.
- Independent TV output retains scenic BGV. OS mirroring can display camera;
  no independent TV camera-feed support is claimed in this batch.

Approval to implement is not evidence of signing or successful deployment.
