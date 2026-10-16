package ph.kanta.reborn.core;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;

/** No framework/JUnit dependency: run on a server JVM before allocating cloud CI. */
public final class CoreRegressionTests {
  private static int checks = 0;

  private static void check(boolean yes, String message) {
    checks++;
    if (!yes) throw new AssertionError(message);
  }

  private static Song song() {
    return new Song("one", "Morning Light", "KANTA Originals", "001", "morning-light.mid", true);
  }

  private static MidiLyrics.Document midiTrack(byte[] track) throws IOException {
    ByteArrayOutputStream bytes = new ByteArrayOutputStream();
    DataOutputStream out = new DataOutputStream(bytes);
    out.writeInt(0x4d546864);
    out.writeInt(6);
    out.writeShort(0);
    out.writeShort(1);
    out.writeShort(480);
    out.writeInt(0x4d54726b);
    out.writeInt(track.length);
    out.write(track);
    return MidiLyrics.decode(bytes.toByteArray());
  }

  private static float[] tone(double frequency, double amplitude) {
    float[] samples = new float[DryPitchDetector.FRAME_SIZE];
    for (int i = 0; i < samples.length; i++)
      samples[i] = (float) (amplitude * Math.sin(2 * Math.PI * frequency * i / 48000));
    return samples;
  }

  private static void microphonePitchChecks() {
    DryPitchDetector detector = new DryPitchDetector();
    for (double hz : new double[] {72, 82.41, 110, 220, 440, 523.25, 880, 990}) {
      DryPitchDetector.Pitch pitch = detector.detect(tone(hz, .2), 48000);
      check(
          pitch != null && Math.abs(1200 * Math.log(pitch.frequencyHz / hz) / Math.log(2)) < 8,
          "Dry pitch frequency: " + hz);
      check(
          pitch.confidence > .9 && Math.abs(pitch.rms - .2 / Math.sqrt(2)) < .01,
          "Dry pitch confidence/energy: " + hz);
    }
    for (double hz : new double[] {40, 53, 1200, 1801.3, 2000, 4999})
      check(
          detector.detect(tone(hz, .2), 48000) == null,
          "Out-of-range fundamental accepted as vocal pitch: " + hz);
    check(detector.detect(new float[4096], 48000) == null, "Silent pitch accepted");
    check(detector.detect(tone(440, .001), 48000) == null, "Subthreshold input accepted");
    float[] invalid = tone(440, .2);
    invalid[100] = Float.NaN;
    check(detector.detect(invalid, 48000) == null, "Nonfinite input accepted");
    invalid[100] = Float.POSITIVE_INFINITY;
    check(detector.detect(invalid, 48000) == null, "Infinite input accepted");
    check(detector.detect(null, 48000) == null, "Null pitch input accepted");
    check(detector.detect(new float[100], 48000) == null, "Partial frame accepted");
    check(detector.detect(tone(440, .2), 0) == null, "Invalid sample rate accepted");
    float[] noise = new float[4096];
    Random random = new Random(71);
    for (int i = 0; i < noise.length; i++) noise[i] = random.nextFloat() * .4f - .2f;
    check(detector.detect(noise, 48000) == null, "Aperiodic noise accepted as pitch");
    Arrays.fill(noise, .5f);
    check(detector.detect(noise, 48000) == null, "DC input accepted as pitch");
    float[] harmonic = tone(220, .2);
    for (int i = 0; i < harmonic.length; i++)
      harmonic[i] += (float) (.1 * Math.sin(2 * Math.PI * 440 * i / 48000));
    DryPitchDetector.Pitch pitch = detector.detect(harmonic, 48000);
    check(
        pitch != null && Math.abs(pitch.frequencyHz - 220) < 2,
        "Harmonic-rich input lost fundamental");
  }

  private static void monitorChecks() {
    MonitorRouteGuard guard = new MonitorRouteGuard(7, 100);
    check(
        guard.verify(new int[0], 101) == MonitorRouteGuard.Decision.WAIT,
        "Unknown route was audible");
    check(
        guard.verify(new int[] {7}, 200) == MonitorRouteGuard.Decision.ALLOW,
        "Selected route rejected");
    check(
        guard.verify(new int[0], 201) == MonitorRouteGuard.Decision.STOP,
        "Lost route remained audible");
    check(
        guard.verify(new int[] {7}, 202) == MonitorRouteGuard.Decision.STOP,
        "Reconnect reenabled monitoring");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[] {8}, 101) == MonitorRouteGuard.Decision.STOP,
        "Preferred route substituted for actual route");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[] {7, 8}, 101)
            == MonitorRouteGuard.Decision.STOP,
        "Multiple simultaneous outputs accepted");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[] {-1}, 101)
            == MonitorRouteGuard.Decision.STOP,
        "Unsafe route accepted");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[0], 1600) == MonitorRouteGuard.Decision.STOP,
        "Route readiness exceeded bound");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[] {7}, 1600)
            == MonitorRouteGuard.Decision.STOP,
        "Late initial route bypassed readiness deadline");
    check(
        new MonitorRouteGuard(7, 100).verify(new int[] {7}, 99) == MonitorRouteGuard.Decision.STOP,
        "Invalid monotonic time accepted");
    MonitorRouteGuard fresh = new MonitorRouteGuard(7, 300);
    check(
        fresh.verify(new int[] {7}, 301) == MonitorRouteGuard.Decision.ALLOW,
        "Explicit new activation inherited old rejection");
    fresh.close();
    check(
        fresh.verify(new int[] {7}, 302) == MonitorRouteGuard.Decision.STOP,
        "Closed route reopened");

    MonitorBuffer buffer = new MonitorBuffer();
    float[] output = new float[480];
    check(!buffer.drain(output), "Empty monitor buffer produced audio");
    short[] input = new short[480];
    Arrays.fill(input, (short) 8192);
    buffer.offer(input, input.length);
    check(!buffer.drain(output), "Monitor bypassed warmup floor");
    buffer.offer(input, input.length);
    buffer.offer(input, input.length);
    check(
        buffer.drain(output) && Math.abs(output[100] - .25f) < .00001,
        "Nominal monitor interpolation changed level");
    check(input[100] == 8192, "Monitor modified dry capture bytes");
    buffer.clear();
    check(
        !buffer.drain(output) && output[100] == 0 && buffer.bufferedFrames() == 0,
        "Clearing monitor retained old voice");
    long before = buffer.discontinuities();
    for (int i = 0; i < 25; i++) buffer.offer(input, input.length);
    check(
        buffer.bufferedFrames() <= 8192 && buffer.discontinuities() > before,
        "Monitor overrun was unbounded or undetected");
    for (int ppm : new int[] {-2000, -500, 500, 2000}) {
      MonitorBuffer drift = new MonitorBuffer();
      drift.offer(new short[1440], 1440);
      double produced = 0;
      short[] incoming = new short[484];
      int failures = 0, maximum = 0;
      for (int block = 0; block < 10000; block++) {
        produced += 480 * (1 + ppm / 1000000.0);
        int count = (int) produced;
        produced -= count;
        drift.offer(incoming, count);
        if (!drift.drain(output)) failures++;
        maximum = Math.max(maximum, drift.bufferedFrames());
      }
      check(
          failures == 0 && maximum < 3000 && drift.discontinuities() == 0,
          "Independent audio clocks lost bounded continuity at " + ppm + " ppm");
    }
    boolean invalid = false;
    try {
      buffer.offer(input, 481);
    } catch (IllegalArgumentException expected) {
      invalid = true;
    }
    check(invalid, "Invalid dry block accepted");

    for (VocalMonitorEffects.Mode mode : VocalMonitorEffects.Mode.values()) {
      VocalMonitorEffects effects = new VocalMonitorEffects();
      effects.mode(mode);
      float[] impulse = new float[48000];
      impulse[0] = .5f;
      effects.process(impulse);
      double tail = 0;
      for (int i = 1; i < impulse.length; i++) tail += impulse[i] * impulse[i];
      check(
          mode == VocalMonitorEffects.Mode.DRY ? tail == 0 : tail > .00001,
          "Monitor effect impulse contract: " + mode);
      effects.reset();
      float[] zero = new float[48000];
      effects.process(zero);
      boolean silent = true;
      for (float value : zero) silent &= value == 0;
      check(silent, "Stopped/reset effect retained a voice tail: " + mode);
      Arrays.fill(impulse, 1000);
      impulse[17] = Float.NaN;
      impulse[18] = Float.POSITIVE_INFINITY;
      effects.process(impulse);
      boolean bounded = true;
      for (float value : impulse) bounded &= Float.isFinite(value) && Math.abs(value) <= .9f;
      check(bounded, "Monitor effect limiter/nonfinite contract: " + mode);
    }
  }

  public static void main(String[] args) throws Exception {
    microphonePitchChecks();
    monitorChecks();
    ReservationQueue queue = new ReservationQueue();
    UUID request = UUID.randomUUID();
    ReservationQueue.Entry first = queue.reserve(request, song(), "Ana"),
        retry = queue.reserve(request, song(), "Ana");
    check(first.id.equals(retry.id), "Replay duplicates a reservation");
    ReservationQueue.Entry second = queue.reserve(UUID.randomUUID(), song(), "Ben");
    check(!first.id.equals(second.id), "Intentional duplicate song lost");
    check(queue.snapshot().size() == 2, "Queue size");
    queue.move(second.id, 0);
    check(queue.peek().id.equals(second.id), "Reorder failed");
    queue.remove(first.id);
    queue.reserve(request, song(), "Ana");
    check(queue.snapshot().size() == 1, "Removed request was replayed");
    ArrayList<ReservationQueue.Entry> restored = new ArrayList<>(queue.snapshot());
    ReservationQueue reopened = new ReservationQueue();
    reopened.restore(restored);
    check(reopened.peek().id.equals(second.id), "Reservation identity changed");
    boolean duplicateRejected = false;
    restored.add(restored.get(0));
    try {
      reopened.restore(restored);
    } catch (IllegalArgumentException e) {
      duplicateRejected = true;
    }
    check(duplicateRejected, "Duplicate queue identity accepted");
    check(song().matches("morning originals"), "Multi-term search");
    check(song().matches("001"), "Code search");
    check(!song().matches("missing"), "False search match");
    boolean traversal = false;
    try {
      new Song("x", "x", "", "", "../outside.mid", false);
    } catch (IllegalArgumentException e) {
      traversal = true;
    }
    check(traversal, "Unsafe media path accepted");
    for (String name : new String[] {"morning-light", "sing-together", "starlight-echo"}) {
      byte[] midi = Files.readAllBytes(Paths.get(args[0], name + ".kar"));
      MidiLyrics.Document document = MidiLyrics.decode(midi);
      List<MidiLyrics.Cue> cues = document.cues;
      check(!document.messages.isEmpty(), "Starter MIDI events missing");
      check(
          document.durationMilliseconds > cues.get(cues.size() - 1).milliseconds,
          "End of track duration lost");
      boolean noteOn = false, noteOff = false;
      long previousTime = -1;
      for (MidiLyrics.Message message : document.messages) {
        check(message.milliseconds >= previousTime, "Nonmonotonic MIDI event time");
        previousTime = message.milliseconds;
        noteOn |= (message.status & 0xf0) == 0x90 && message.b > 0;
        noteOff |=
            (message.status & 0xf0) == 0x80 || (message.status & 0xf0) == 0x90 && message.b == 0;
      }
      check(noteOn && noteOff, "Starter note lifetime missing");
      check(cues.size() >= 3, "Starter lyrics missing " + name);
      check(cues.get(0).milliseconds == 0, "First lyric time");
      for (int i = 1; i < cues.size(); i++)
        check(
            cues.get(i).milliseconds >= cues.get(i - 1).milliseconds, "Nonmonotonic lyric timing");
      check(MidiLyrics.activeIndex(cues, -1) == -1, "Early lyric displayed");
      check(MidiLyrics.activeIndex(cues, cues.get(1).milliseconds) == 1, "Lyric boundary");
      boolean bad = false;
      try {
        MidiLyrics.parse(Arrays.copyOf(midi, midi.length - 6));
      } catch (IOException e) {
        bad = true;
      }
      check(bad, "Truncated MIDI accepted");
    }
    java.util.concurrent.ExecutorService workers =
        java.util.concurrent.Executors.newFixedThreadPool(8);
    ReservationQueue concurrentQueue = new ReservationQueue();
    UUID sharedRequest = UUID.randomUUID();
    Set<UUID> responseIds = new HashSet<>();
    List<java.util.concurrent.Future<ReservationQueue.Entry>> futures = new ArrayList<>();
    for (int i = 0; i < 32; i++)
      futures.add(workers.submit(() -> concurrentQueue.reserve(sharedRequest, song(), "Singer")));
    for (java.util.concurrent.Future<ReservationQueue.Entry> future : futures)
      responseIds.add(future.get().id);
    workers.shutdown();
    check(responseIds.size() == 1, "Concurrent replay returned different identities");
    check(concurrentQueue.snapshot().size() == 1, "Concurrent replay duplicated queue state");
    check(
        new Song("accent", "Kántá", "", "", "accent.mid", false).matches("kanta"),
        "Accent-insensitive search");
    ByteArrayOutputStream midiBytes = new ByteArrayOutputStream();
    DataOutputStream midiOut = new DataOutputStream(midiBytes);
    midiOut.writeInt(0x4d546864);
    midiOut.writeInt(6);
    midiOut.writeShort(1);
    midiOut.writeShort(2);
    midiOut.writeShort(480);
    byte[] tempoTrack = {
      0,
      (byte) 255,
      81,
      3,
      7,
      (byte) 161,
      32,
      (byte) 131,
      96,
      (byte) 255,
      81,
      3,
      15,
      66,
      64,
      0,
      (byte) 255,
      47,
      0
    };
    byte[] lyricTrack = {
      0, (byte) 255, 5, 2, 47, 65, (byte) 135, 64, (byte) 255, 5, 2, 47, 66, 0, (byte) 255, 47, 0
    };
    for (byte[] track : new byte[][] {tempoTrack, lyricTrack}) {
      midiOut.writeInt(0x4d54726b);
      midiOut.writeInt(track.length);
      midiOut.write(track);
    }
    check(
        MidiLyrics.parse(midiBytes.toByteArray()).get(1).milliseconds == 1500,
        "Cross-track tempo mapping");
    boolean malformed = false;
    try {
      MidiLyrics.parse(new byte[20]);
    } catch (IOException e) {
      malformed = true;
    }
    check(malformed, "Invalid MIDI magic accepted");
    RenderedPlaybackClock clock = new RenderedPlaybackClock(1000);
    check(clock.position(0) == 0, "Empty playback clock");
    clock.append(0, 0, 1);
    clock.append(1000, 1000, 2);
    clock.append(2000, 3000, .5);
    check(clock.position(500) == 500, "Buffered tempo applied before audible boundary");
    check(clock.position(1000) == 1000, "Tempo boundary discontinuity");
    check(clock.position(1500) == 2000, "Audible fast tempo clock");
    check(clock.position(2500) == 3250, "Audible slow tempo clock");
    boolean invalidClock = false;
    try {
      clock.append(3000, 3500, Double.NaN);
    } catch (IllegalArgumentException e) {
      invalidClock = true;
    }
    check(invalidClock, "Nonfinite tempo accepted");
    boolean backwardsClock = false;
    try {
      clock.append(2000, 3500, 1);
    } catch (IllegalArgumentException e) {
      backwardsClock = true;
    }
    check(backwardsClock, "Backwards render clock accepted");
    byte[] channelTrack = {
      0,
      (byte) 0xc0,
      12,
      0,
      (byte) 0xb0,
      7,
      90,
      0,
      (byte) 0xe0,
      0,
      64,
      0,
      (byte) 0x90,
      69,
      127,
      (byte) 0x83,
      0x60,
      69,
      0,
      (byte) 0x83,
      0x60,
      (byte) 0xff,
      0x2f,
      0
    };
    ByteArrayOutputStream channelBytes = new ByteArrayOutputStream();
    DataOutputStream channelOut = new DataOutputStream(channelBytes);
    channelOut.writeInt(0x4d546864);
    channelOut.writeInt(6);
    channelOut.writeShort(0);
    channelOut.writeShort(1);
    channelOut.writeShort(480);
    channelOut.writeInt(0x4d54726b);
    channelOut.writeInt(channelTrack.length);
    channelOut.write(channelTrack);
    MidiLyrics.Document channels = MidiLyrics.decode(channelBytes.toByteArray());
    check(channels.messages.size() == 5, "Typed channel events lost");
    check(
        channels.messages.get(0).status == 0xc0 && channels.messages.get(0).a == 12,
        "Program event");
    check(
        channels.messages.get(1).status == 0xb0 && channels.messages.get(1).b == 90,
        "Control event");
    check(
        channels.messages.get(2).status == 0xe0 && channels.messages.get(2).b == 64,
        "Pitch wheel event");
    check(
        channels.messages.get(4).milliseconds == 500 && channels.messages.get(4).b == 0,
        "Running-status note off");
    check(channels.durationMilliseconds == 1000, "Silent ending duration lost");
    byte[] fragmentsTrack = {
      0,
      (byte) 255,
      5,
      4,
      '/',
      'H',
      'e',
      'l',
      (byte) 0x83,
      0x60,
      (byte) 255,
      5,
      3,
      'l',
      'o',
      ' ',
      (byte) 0x83,
      0x60,
      (byte) 255,
      5,
      10,
      'w',
      'o',
      'r',
      'l',
      'd',
      '\n',
      'N',
      'e',
      'x',
      't',
      0,
      (byte) 255,
      47,
      0
    };
    MidiLyrics.Document fragmented = midiTrack(fragmentsTrack);
    check(
        fragmented.cues.size() == 2
            && fragmented.cues.get(0).line.equals("Hello world")
            && fragmented.cues.get(1).line.equals("Next"),
        "Inline lyric line markers");
    MidiLyrics.Cue timed = fragmented.cues.get(0);
    check(timed.highlightedCharacters(-1) == 0, "Early fragment highlight");
    check(
        timed.highlightedCharacters(0) == 3 && timed.highlightedCharacters(499) == 3,
        "Invented fragment timing");
    check(
        timed.highlightedCharacters(500) == 6 && timed.highlightedCharacters(1000) == 11,
        "Source fragment boundary");
    byte[] unmarked = {
      0,
      (byte) 255,
      5,
      3,
      'O',
      'n',
      'e',
      (byte) 0x83,
      0x60,
      (byte) 255,
      5,
      3,
      'T',
      'w',
      'o',
      0,
      (byte) 255,
      47,
      0
    };
    check(midiTrack(unmarked).cues.size() == 2, "Unmarked lyrics collapsed into one line");
    for (int sound = 0; sound < PartySounds.TITLES.size(); sound++) {
      byte[] wave = PartySounds.wave(sound);
      check(Arrays.equals(wave, PartySounds.wave(sound)), "Nondeterministic first-party sound");
      try (javax.sound.sampled.AudioInputStream audio =
          javax.sound.sampled.AudioSystem.getAudioInputStream(new ByteArrayInputStream(wave))) {
        check(
            audio.getFormat().getSampleRate() == 22050 && audio.getFrameLength() == 44100,
            "Invalid party WAV format/duration");
        byte[] pcm = audio.readAllBytes();
        int peak = 0;
        for (int offset = 0; offset < pcm.length; offset += 2)
          peak = Math.max(peak, Math.abs((short) ((pcm[offset] & 255) | (pcm[offset + 1] << 8))));
        check(peak > 100 && peak <= 24000, "Silent or clipped party sound");
      }
    }
    check(ShortClipBounds.accepts(2000, 44100, 2), "Small stereo clip rejected");
    check(!ShortClipBounds.accepts(30000, 44100, 2), "Truncated SoundPool clip accepted");
    check(!ShortClipBounds.accepts(Long.MAX_VALUE, 44100, 2), "Clip duration overflow");
    check(
        !ShortClipBounds.accepts(1000, -1, 2) && !ShortClipBounds.accepts(1000, 44100, 8),
        "Invalid clip format accepted");
    boolean invalidPad = false;
    try {
      PartySounds.wave(8);
    } catch (IllegalArgumentException e) {
      invalidPad = true;
    }
    check(invalidPad, "Unknown pad accepted");
    Song dangerous = new Song("x", "=SUM(1,2)", "A\"B", "7", "x.wav", false);
    String csv = PrivateSongbook.csv(Arrays.asList(dangerous));
    check(csv.contains("\"'=SUM(1,2)\""), "Formula not neutralized");
    check(csv.contains("\"A\"\"B\""), "CSV quote escape");
    PrivateSongbook.Export export = PrivateSongbook.seal(csv), another = PrivateSongbook.seal(csv);
    check(export.accessCode.length() == 32, "Code entropy representation");
    check(!export.accessCode.equals(another.accessCode), "Export secret reused");
    String marker = "\"payload\":\"";
    int start = export.envelope.indexOf(marker) + marker.length();
    byte[] combined =
        Base64.getDecoder()
            .decode(export.envelope.substring(start, export.envelope.indexOf('"', start)));
    byte[] key =
        MessageDigest.getInstance("SHA-256")
            .digest(("KANTA-SONGBOOK-V1:" + export.accessCode).getBytes(StandardCharsets.UTF_8));
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(
        Cipher.DECRYPT_MODE,
        new SecretKeySpec(key, "AES"),
        new GCMParameterSpec(128, Arrays.copyOf(combined, 12)));
    String plain =
        new String(
            cipher.doFinal(Arrays.copyOfRange(combined, 12, combined.length)),
            StandardCharsets.UTF_8);
    check(plain.equals(csv), "Browser envelope round trip");
    combined[combined.length - 1] ^= 1;
    boolean tampered = false;
    try {
      cipher.init(
          Cipher.DECRYPT_MODE,
          new SecretKeySpec(key, "AES"),
          new GCMParameterSpec(128, Arrays.copyOf(combined, 12)));
      cipher.doFinal(Arrays.copyOfRange(combined, 12, combined.length));
    } catch (AEADBadTagException e) {
      tampered = true;
    }
    check(tampered, "Tampering accepted");
    if (args.length > 1) {
      String fixture =
          "{\"code\":\""
              + export.accessCode
              + "\",\"envelope\":"
              + export.envelope
              + ",\"csvBase64\":\""
              + Base64.getEncoder().encodeToString(csv.getBytes(StandardCharsets.UTF_8))
              + "\"}";
      Files.write(Paths.get(args[1]), fixture.getBytes(StandardCharsets.UTF_8));
    }
    System.out.println("KANTA Android core: " + checks + " regression checks passed");
  }
}
