# Silent stage fixture

`stage-color.mp4` is an original, generated two-second solid-color H.264 baseline video, 160 × 120 at 10 fps, with no audio or external media. It is packaged only in the instrumentation APK.

Generated with FFmpeg 6.1.1:

```sh
ffmpeg -f lavfi -i color=c=0x14465a:s=160x120:r=10:d=2 -an -c:v libx264 -pix_fmt yuv420p -profile:v baseline -g 10 -movflags +faststart -map_metadata -1 stage-color.mp4
```

SHA-256: `0673a46b13ecabba277f34bc7b693f1db0ea044a036da506e348589f6a983017`.
