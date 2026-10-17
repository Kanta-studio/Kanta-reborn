package ph.kanta.reborn;

/** Native handles and their allocations belong to the calling synthesis worker. */
final class NativeSoundFont {
  static {
    System.loadLibrary("kanta_audio");
  }

  static native long open(String path);

  static native void close(long handle);

  static native void midi(long handle, int status, int a, int b);

  static native void tune(long handle, float semitones);

  static native void render(long handle, float[] output, int offset, int frames);
}
