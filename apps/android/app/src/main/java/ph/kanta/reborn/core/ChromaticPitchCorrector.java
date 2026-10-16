package ph.kanta.reborn.core;

import java.util.Arrays;

/** Bounded chromatic correction for the optional 48 kHz monitor, never dry analysis. */
public final class ChromaticPitchCorrector {
  private static final int RATE = 48000, CAPACITY = 8192, SPAN = 4096, BASE = 480;
  private static final double LIMIT = Math.pow(2, .6 / 12);
  private final float[] history = new float[CAPACITY];
  private final float[] window = new float[SPAN + 1];
  private int head;
  private double phase, ratio = 1, desiredRatio = 1, wet, desiredWet;
  private double note = Double.NaN;

  public ChromaticPitchCorrector() {
    for (int i = 0; i <= SPAN; i++)
      window[i] = (float) (.5 - .5 * Math.cos(2 * Math.PI * i / SPAN));
  }

  /** Uncertain or stale estimates relax to unshifted, equally delayed input. */
  public void update(double frequency, double confidence, double rms, long measuredAt, long now) {
    if (!Double.isFinite(frequency)
        || frequency < 70
        || frequency > 1000
        || !Double.isFinite(confidence)
        || confidence < .85
        || confidence > 1
        || !Double.isFinite(rms)
        || rms < .008
        || rms > 1
        || measuredAt < 0
        || now < measuredAt
        || now - measuredAt > 300) {
      desiredRatio = 1;
      desiredWet = 0;
      note = Double.NaN;
      return;
    }
    double detected = 69 + 12 * Math.log(frequency / 440) / Math.log(2);
    // A small hysteresis band avoids oscillating between adjacent semitones.
    if (!Double.isFinite(note) || Math.abs(detected - note) > .6) note = Math.rint(detected);
    desiredRatio = Math.max(1 / LIMIT, Math.min(LIMIT, Math.pow(2, (note - detected) / 12)));
    desiredWet = 1;
  }

  public boolean hasTarget() {
    return desiredWet != 0;
  }

  public double targetRatio() {
    return desiredRatio;
  }

  public void reset() {
    Arrays.fill(history, 0);
    head = 0;
    phase = 0;
    ratio = desiredRatio = 1;
    wet = desiredWet = 0;
    note = Double.NaN;
  }

  private float read(double delay) {
    double position = head - delay;
    if (position < 0) position += CAPACITY;
    int left = (int) position;
    double fraction = position - left;
    return (float) (history[left] + fraction * (history[(left + 1) % CAPACITY] - history[left]));
  }

  /** Two faded delay taps consume and produce the same fixed number of frames. */
  public void process(float[] samples) {
    if (samples == null || samples.length > 1440) throw new IllegalArgumentException();
    for (int i = 0; i < samples.length; i++) {
      history[head] = Float.isFinite(samples[i]) ? Math.max(-1, Math.min(1, samples[i])) : 0;
      ratio += (desiredRatio - ratio) / (RATE * .04);
      wet += (desiredWet - wet) / (RATE * .01);
      double second = phase + .5;
      if (second >= 1) second -= 1;
      double index = phase * SPAN;
      int left = (int) index;
      double weight = window[left] + (index - left) * (window[left + 1] - window[left]);
      double shifted =
          read(BASE + phase * SPAN) * weight + read(BASE + second * SPAN) * (1 - weight);
      double dry = read(BASE + SPAN / 2.0);
      double value = dry + wet * (shifted - dry);
      samples[i] = (float) Math.max(-.9, Math.min(.9, value));
      phase += (1 - ratio) / SPAN;
      if (phase < 0) phase += 1;
      else if (phase >= 1) phase -= 1;
      head = (head + 1) % CAPACITY;
    }
  }
}
