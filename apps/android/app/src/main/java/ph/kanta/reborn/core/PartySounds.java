package ph.kanta.reborn.core;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Original synthesized pads; no third-party sound recordings are distributed. */
public final class PartySounds {
  public static final List<String> TITLES =
      Collections.unmodifiableList(
          Arrays.asList(
              "Applause",
              "Cheering",
              "Drum Roll",
              "Air Horn",
              "Laughter",
              "Ta-Da!",
              "Ding",
              "Sad Trombone"));
  private static final double[] NOTES = {180, 650, 100, 220, 420, 523.25, 1046.5, 174.6};

  public static byte[] wave(int sound) {
    if (sound < 0 || sound >= TITLES.size()) throw new IllegalArgumentException("Unknown pad");
    int rate = 22050, frames = rate * 2;
    ByteBuffer bytes = ByteBuffer.allocate(44 + frames * 2).order(ByteOrder.LITTLE_ENDIAN);
    bytes.put("RIFF".getBytes(StandardCharsets.US_ASCII)).putInt(36 + frames * 2);
    bytes
        .put("WAVEfmt ".getBytes(StandardCharsets.US_ASCII))
        .putInt(16)
        .putShort((short) 1)
        .putShort((short) 1);
    bytes.putInt(rate).putInt(rate * 2).putShort((short) 2).putShort((short) 16);
    bytes.put("data".getBytes(StandardCharsets.US_ASCII)).putInt(frames * 2);
    int seed = 0x4b414e54;
    double phase = 0;
    for (int i = 0; i < frames; i++) {
      double time = i / (double) rate;
      seed = seed * 1664525 + 1013904223;
      double noise = (seed >>> 16) / 32768.0 - 1;
      double frequency = NOTES[sound] * (sound == 7 ? Math.pow(2, -time / 4) : 1);
      phase += 2 * Math.PI * frequency / rate;
      double tone = Math.sin(phase) + .25 * Math.sin(phase * 1.5);
      double signal = sound <= 2 ? noise * (.4 + .6 * Math.abs(Math.sin(time * 38))) : tone * .5;
      double envelope = Math.exp(-time * (sound == 6 ? 4 : 1.8));
      envelope *= Math.min(1, time / .01) * Math.min(1, (2 - time) / .05);
      if (sound == 4) envelope *= Math.max(0, Math.sin(time * 24));
      bytes.putShort((short) (Math.max(-1, Math.min(1, signal * envelope)) * 24000));
    }
    return bytes.array();
  }

  private PartySounds() {}
}
