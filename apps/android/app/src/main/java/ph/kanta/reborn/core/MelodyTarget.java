package ph.kanta.reborn.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Conservative note reference. Unknown melody identity is never inferred from note height. */
public final class MelodyTarget {
  public static final class Window {
    public final long start, end;
    public final int note;

    public Window(long start, long end, int note) {
      if (start < 0 || end <= start || end > 21600000 || note < 0 || note > 127)
        throw new IllegalArgumentException();
      this.start = start;
      this.end = end;
      this.note = note;
    }
  }

  public final List<Window> windows;
  public final int track, channel;
  public final String unavailable;
  private static final Set<String> NAMES =
      new HashSet<>(
          java.util.Arrays.asList(
              "melody",
              "vocal",
              "vocals",
              "voice",
              "guide vocal",
              "guide vocals",
              "guide melody",
              "melody guide",
              "lead vocal",
              "lead vocals"));

  private MelodyTarget(List<Window> windows, int track, int channel, String unavailable) {
    this.windows = Collections.unmodifiableList(new ArrayList<>(windows));
    this.track = track;
    this.channel = channel;
    this.unavailable = unavailable;
  }

  private static MelodyTarget unavailable(String reason) {
    return new MelodyTarget(Collections.emptyList(), -1, -1, reason);
  }

  private static boolean named(String name) {
    String value =
        java.text.Normalizer.normalize(name, java.text.Normalizer.Form.NFKC)
            .toLowerCase(Locale.ROOT)
            .replace('-', ' ')
            .replace('_', ' ')
            .trim()
            .replaceAll("\\s+", " ");
    return NAMES.contains(value);
  }

  public boolean available() {
    return !windows.isEmpty();
  }

  public static MelodyTarget extract(MidiLyrics.Document document) {
    if (document == null) return unavailable("No melody reference for this audio file");
    MidiLyrics.Track candidate = null;
    int channel = -1;
    for (MidiLyrics.Track track : document.tracks) {
      int mask = track.noteChannelMask & ~(1 << 9);
      if (Integer.bitCount(mask) != 1
          || !(track.hasLyrics || named(track.name) || named(track.instrumentName))) continue;
      if (candidate != null) return unavailable("More than one melody candidate");
      candidate = track;
      channel = Integer.numberOfTrailingZeros(mask);
    }
    if (candidate == null) return unavailable("No single labelled melody in this MIDI");
    int active = -1;
    long start = 0;
    ArrayList<Window> windows = new ArrayList<>();
    for (MidiLyrics.Message event : document.messages) {
      if ((event.status & 15) != channel) continue;
      int kind = event.status & 0xf0;
      // Channel bend affects the instrument even when emitted by another track.
      if (kind == 0xe0 && (event.a | event.b << 7) != 8192)
        return unavailable("The melody uses pitch bend");
      if (event.track != candidate.index) continue;
      if (kind == 0x90 && event.b > 0) {
        if (active != -1) return unavailable("The melody has overlapping notes");
        active = event.a;
        start = event.milliseconds;
      } else if (kind == 0x80 || kind == 0x90 && event.b == 0) {
        if (active != event.a || event.milliseconds <= start)
          return unavailable("The melody has an incomplete note lifetime");
        windows.add(new Window(start, event.milliseconds, active));
        active = -1;
      }
    }
    if (active != -1) return unavailable("The melody has an incomplete note lifetime");
    if (windows.isEmpty()) return unavailable("No melody notes are available");
    return new MelodyTarget(windows, candidate.index, channel, "");
  }
}
