package ph.kanta.reborn.core;

/** Rejects clips that SoundPool would silently truncate after decoding to 16-bit PCM. */
public final class ShortClipBounds {
  public static boolean accepts(long milliseconds, int sampleRate, int channels) {
    if (milliseconds <= 0
        || milliseconds > 30000
        || sampleRate < 8000
        || sampleRate > 192000
        || channels < 1
        || channels > 2) return false;
    long frames = (milliseconds * sampleRate + 999) / 1000;
    return frames * channels * 2 <= 900 * 1024;
  }

  private ShortClipBounds() {}
}
