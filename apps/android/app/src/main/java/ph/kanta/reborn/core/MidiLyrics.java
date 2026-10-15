package ph.kanta.reborn.core;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Bounded SMF 0/1 parser. Tempo events from all tracks share one tick timeline. */
public final class MidiLyrics {
  public static final class Cue {
    public final long milliseconds;
    public final String line;

    Cue(long ms, String line) {
      milliseconds = ms;
      this.line = line;
    }
  }

  public static final class Message {
    public final long milliseconds;
    public final int status, a, b;

    Message(long ms, int status, int a, int b) {
      milliseconds = ms;
      this.status = status;
      this.a = a;
      this.b = b;
    }
  }

  public static final class Document {
    public final List<Cue> cues;
    public final List<Message> messages;
    public final long durationMilliseconds;

    Document(List<Cue> cues, List<Message> messages, long duration) {
      this.cues = Collections.unmodifiableList(cues);
      this.messages = Collections.unmodifiableList(messages);
      durationMilliseconds = duration;
    }
  }

  private static final class Event {
    long tick;
    int tempo, type, status, a, b;
    String text;
    int sequence;

    Event(long t, int tempo, int type, String text, int seq) {
      tick = t;
      this.tempo = tempo;
      this.type = type;
      this.text = text;
      sequence = seq;
    }
  }

  private static final class Reader {
    final byte[] b;
    int p, end;

    Reader(byte[] b, int p, int end) {
      this.b = b;
      this.p = p;
      this.end = end;
    }

    int u8() throws IOException {
      if (p >= end) throw new IOException("Truncated MIDI");
      return b[p++] & 255;
    }

    int u16() throws IOException {
      return (u8() << 8) | u8();
    }

    long u32() throws IOException {
      return ((long) u16() << 16) | u16();
    }

    long vlq() throws IOException {
      long n = 0;
      for (int i = 0; i < 4; i++) {
        int v = u8();
        n = (n << 7) | (v & 127);
        if ((v & 128) == 0) return n;
      }
      throw new IOException("Invalid MIDI length");
    }

    void skip(long n) throws IOException {
      if (n < 0 || n > end - p) throw new IOException("Invalid MIDI chunk");
      p += (int) n;
    }

    String text(int n) throws IOException {
      if (n < 0 || n > end - p || n > 65536) throw new IOException("Invalid MIDI text");
      String s = new String(b, p, n, StandardCharsets.UTF_8);
      p += n;
      return s;
    }

    boolean magic(String s) throws IOException {
      return text(4).equals(s);
    }
  }

  public static List<Cue> parse(byte[] data) throws IOException {
    return decode(data).cues;
  }

  public static Document decode(byte[] data) throws IOException {
    if (data.length > 16 * 1024 * 1024) throw new IOException("MIDI too large");
    Reader r = new Reader(data, 0, data.length);
    if (!r.magic("MThd")) throw new IOException("Not MIDI");
    long header = r.u32();
    if (header < 6 || header > 1024) throw new IOException("Invalid MIDI header");
    int format = r.u16(), tracks = r.u16(), ppq = r.u16();
    if (format > 1
        || tracks < 1
        || tracks > 256
        || ppq == 0
        || (ppq & 0x8000) != 0
        || (format == 0 && tracks != 1)) throw new IOException("Unsupported MIDI timing");
    r.skip(header - 6);
    ArrayList<Event> events = new ArrayList<>();
    int seq = 0, total = 0;
    for (int track = 0; track < tracks; track++) {
      if (!r.magic("MTrk")) throw new IOException("Missing MIDI track");
      long length = r.u32();
      if (length > r.end - r.p) throw new IOException("Truncated MIDI track");
      Reader t = new Reader(data, r.p, r.p + (int) length);
      r.skip(length);
      long tick = 0;
      int running = 0;
      while (t.p < t.end) {
        if (++total > 250000) throw new IOException("Too many MIDI events");
        tick += t.vlq();
        if (tick > Integer.MAX_VALUE * 16L) throw new IOException("MIDI timeline too long");
        int status = t.u8();
        if (status < 128) {
          if (running == 0) throw new IOException("Invalid running status");
          t.p--;
          status = running;
        }
        if (status == 255) {
          running = 0;
          int type = t.u8();
          long n = t.vlq();
          if (n > t.end - t.p) throw new IOException("Truncated MIDI event");
          if (type == 0x51) {
            if (n != 3) throw new IOException("Invalid tempo");
            int tempo = (t.u8() << 16) | (t.u8() << 8) | t.u8();
            if (tempo <= 0) throw new IOException("Invalid tempo");
            events.add(new Event(tick, tempo, type, null, seq++));
          } else if (type == 1 || type == 5) {
            String text = t.text((int) n);
            if (!text.startsWith("@") && !text.trim().isEmpty())
              events.add(new Event(tick, 0, type, text, seq++));
          } else t.skip(n);
          if (type == 0x2f) {
            events.add(new Event(tick, 0, type, null, seq++));
            break;
          }
        } else if (status == 0xf0 || status == 0xf7) {
          running = 0;
          t.skip(t.vlq());
        } else if (status >= 0x80 && status <= 0xef) {
          running = status;
          int n = (status & 0xe0) == 0xc0 ? 1 : 2;
          int a = t.u8(), b = n == 2 ? t.u8() : 0;
          if (a > 127 || b > 127) throw new IOException("Invalid MIDI data");
          Event message = new Event(tick, 0, 0, null, seq++);
          message.status = status;
          message.a = a;
          message.b = b;
          events.add(message);
        } else throw new IOException("Unsupported MIDI status");
      }
    }
    events.sort(Comparator.comparingLong((Event e) -> e.tick).thenComparingInt(e -> e.sequence));
    boolean lyrics = events.stream().anyMatch(e -> e.type == 5);
    ArrayList<Cue> cues = new ArrayList<>();
    ArrayList<Message> messages = new ArrayList<>();
    long last = 0;
    double micros = 0;
    int tempo = 500000;
    StringBuilder line = new StringBuilder();
    long lineStart = 0;
    for (Event e : events) {
      micros += (e.tick - last) * (double) tempo / ppq;
      last = e.tick;
      if (micros > 6L * 60 * 60 * 1000000) throw new IOException("MIDI exceeds six hours");
      if (e.status != 0) {
        messages.add(new Message((long) (micros / 1000), e.status, e.a, e.b));
        continue;
      }
      if (e.tempo > 0) {
        tempo = e.tempo;
        continue;
      }
      if (e.type != (lyrics ? 5 : 1)) continue;
      String raw = e.text;
      boolean newline = raw.startsWith("/") || raw.startsWith("\\") || raw.startsWith("\n");
      if (newline && line.length() > 0) {
        cues.add(new Cue(lineStart, line.toString().trim()));
        line.setLength(0);
      }
      if (line.length() == 0) lineStart = (long) (micros / 1000);
      String clean = raw.replace('/', ' ').replace('\\', ' ').replace('\r', ' ').replace('\n', ' ');
      if (line.length() + clean.length() > 4096) throw new IOException("Lyric line too long");
      line.append(clean);
    }
    if (line.length() > 0) cues.add(new Cue(lineStart, line.toString().trim()));
    return new Document(cues, messages, (long) (micros / 1000));
  }

  public static int activeIndex(List<Cue> cues, long milliseconds) {
    int low = 0, high = cues.size() - 1, result = -1;
    while (low <= high) {
      int mid = (low + high) >>> 1;
      if (cues.get(mid).milliseconds <= milliseconds) {
        result = mid;
        low = mid + 1;
      } else high = mid - 1;
    }
    return result;
  }
}
