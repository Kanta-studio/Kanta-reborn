package ph.kanta.reborn.core;

import java.util.Arrays;

/** Bounded interpolation between independent nominal-48-kHz capture/output clocks. */
public final class MonitorBuffer {
  private static final int CAPACITY = 8192, TARGET = 1440;
  private final float[] ring = new float[CAPACITY];
  private int head, size;
  private double fraction;
  private boolean primed;
  private long discontinuities;

  public synchronized void offer(short[] input, int count) {
    if (input == null || count < 0 || count > input.length || count > CAPACITY)
      throw new IllegalArgumentException();
    if (size + count > CAPACITY) clear();
    for (int i = 0; i < count; i++) ring[(head + size + i) % CAPACITY] = input[i] / 32768f;
    size += count;
  }

  public synchronized boolean drain(float[] output) {
    if (output == null || output.length == 0 || output.length > TARGET)
      throw new IllegalArgumentException();
    if (!primed && size < TARGET) {
      Arrays.fill(output, 0);
      return false;
    }
    primed = true;
    double step = 1 + Math.max(-.005, Math.min(.005, (size - TARGET) / (TARGET * 200.0)));
    for (int i = 0; i < output.length; i++) {
      if (size < 3) {
        clear();
        Arrays.fill(output, 0);
        return false;
      }
      float left = ring[head], right = ring[(head + 1) % CAPACITY];
      output[i] = (float) (left + fraction * (right - left));
      fraction += step;
      int consumed = (int) fraction;
      fraction -= consumed;
      for (int n = 0; n < consumed; n++) {
        ring[head] = 0;
        head = (head + 1) % CAPACITY;
      }
      size -= consumed;
    }
    return true;
  }

  public synchronized int bufferedFrames() {
    return size;
  }

  public synchronized long discontinuities() {
    return discontinuities;
  }

  public synchronized void clear() {
    Arrays.fill(ring, 0);
    head = size = 0;
    fraction = 0;
    primed = false;
    discontinuities++;
  }
}
