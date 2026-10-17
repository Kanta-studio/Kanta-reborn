package ph.kanta.reborn.core;

import java.util.Arrays;

/** Monitor-only delay network. Dry pitch/scoring input must bypass this processor. */
public final class VocalMonitorEffects {
  public enum Mode {
    DRY,
    ROOM,
    HALL,
    ECHO
  }

  private final float[][] delays = {
    new float[1426], new float[1781], new float[1973], new float[2098]
  };
  private final int[] positions = new int[4];
  private final float[] echo = new float[8640];
  private int echoPosition;
  private Mode mode = Mode.DRY;

  public void mode(Mode value) {
    if (value == null) throw new IllegalArgumentException();
    if (value != mode) {
      mode = value;
      reset();
    }
  }

  public void reset() {
    for (float[] delay : delays) Arrays.fill(delay, 0);
    Arrays.fill(positions, 0);
    Arrays.fill(echo, 0);
    echoPosition = 0;
  }

  public void process(float[] samples) {
    for (int i = 0; i < samples.length; i++) {
      float dry = Float.isFinite(samples[i]) ? Math.max(-1, Math.min(1, samples[i])) : 0;
      float value = dry;
      if (mode == Mode.ECHO) {
        float delayed = echo[echoPosition];
        echo[echoPosition] = dry + delayed * .3f;
        echoPosition = (echoPosition + 1) % echo.length;
        value = dry * .75f + delayed * .25f;
      } else if (mode != Mode.DRY) {
        float feedback = mode == Mode.HALL ? .68f : .45f;
        float wet = 0;
        for (int n = 0; n < delays.length; n++) {
          float delayed = delays[n][positions[n]];
          delays[n][positions[n]] = dry + delayed * feedback;
          positions[n] = (positions[n] + 1) % delays[n].length;
          wet += delayed * .25f;
        }
        float mix = mode == Mode.HALL ? .28f : .18f;
        value = dry * (1 - mix) + wet * mix;
      }
      samples[i] = Math.max(-.9f, Math.min(.9f, value));
    }
  }
}
