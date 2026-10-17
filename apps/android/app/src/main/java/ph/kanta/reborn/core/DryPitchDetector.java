package ph.kanta.reborn.core;

/** Bounded YIN period estimate for monophonic input; it cannot identify the singer. */
public final class DryPitchDetector {
  public static final int FRAME_SIZE = 4096;
  private final double[] difference = new double[FRAME_SIZE / 2 + 1];

  public static final class Pitch {
    public final double frequencyHz, confidence, rms;

    Pitch(double frequencyHz, double confidence, double rms) {
      this.frequencyHz = frequencyHz;
      this.confidence = confidence;
      this.rms = rms;
    }
  }

  /** Worker-confined: the difference workspace is reused between frames. */
  public Pitch detect(float[] samples, int sampleRate) {
    if (samples == null || samples.length != FRAME_SIZE || sampleRate < 8000 || sampleRate > 96000)
      return null;
    double energy = 0, mean = 0;
    for (float sample : samples) {
      if (!Float.isFinite(sample) || Math.abs(sample) > 1.01f) return null;
      mean += sample;
    }
    mean /= samples.length;
    for (float sample : samples) energy += (sample - mean) * (sample - mean);
    double rms = Math.sqrt(energy / samples.length);
    if (rms < .008) return null;
    int maxLag = Math.min(FRAME_SIZE / 2 - 1, sampleRate / 70 + 1);
    int window = FRAME_SIZE - maxLag;
    double sum = 0;
    difference[0] = 1;
    // Search short periods too: an out-of-range fundamental must not become a subharmonic.
    for (int lag = 1; lag <= maxLag; lag++) {
      double value = 0;
      for (int i = 0; i < window; i++) {
        double delta = samples[i] - samples[i + lag];
        value += delta * delta;
      }
      sum += value;
      difference[lag] = sum > 0 ? value * lag / sum : 1;
    }
    for (int lag = 2; lag < maxLag; lag++) {
      double value = difference[lag];
      if (value >= .15 || value > difference[lag - 1] || value > difference[lag + 1]) continue;
      double curvature = difference[lag - 1] - 2 * value + difference[lag + 1];
      double offset =
          curvature > 0 ? .5 * (difference[lag - 1] - difference[lag + 1]) / curvature : 0;
      if (Math.abs(offset) > 1) offset = 0;
      double frequency = sampleRate / (lag + offset);
      if (!Double.isFinite(frequency) || frequency < 70 || frequency > 1000) return null;
      return new Pitch(frequency, Math.max(0, Math.min(1, 1 - value)), rms);
    }
    return null;
  }
}
