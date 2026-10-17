package ph.kanta.reborn;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRouting;
import android.media.AudioTrack;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import ph.kanta.reborn.core.ChromaticPitchCorrector;
import ph.kanta.reborn.core.MonitorBuffer;
import ph.kanta.reborn.core.MonitorRouteGuard;
import ph.kanta.reborn.core.VocalMonitorEffects;

/** Optional voice output. Actual routing, not device availability, controls audibility. */
final class MicrophoneMonitor {
  private static final int RATE = 48000;
  private final AudioManager audio;
  private final Handler main = new Handler(Looper.getMainLooper());
  private final Consumer<String> notice;
  private final Runnable changed;
  private final java.util.function.Supplier<MicrophoneInput.Reading> readings;
  private final ExecutorService worker =
      new ThreadPoolExecutor(
          1,
          1,
          0L,
          TimeUnit.MILLISECONDS,
          new ArrayBlockingQueue<>(1),
          new ThreadPoolExecutor.DiscardOldestPolicy());
  private volatile Run active, outputOwner;
  private volatile float gain = .1f;
  private volatile VocalMonitorEffects.Mode mode = VocalMonitorEffects.Mode.DRY;

  private static final class Run {
    final AudioDeviceInfo device;
    final MonitorBuffer buffer = new MonitorBuffer();
    final MonitorRouteGuard guard;
    volatile boolean cancelled, audible, ready;
    volatile CorrectionChoice correction = CorrectionChoice.OFF;
    AudioTrack track;

    Run(AudioDeviceInfo device) {
      this.device = device;
      guard = new MonitorRouteGuard(device.getId(), SystemClock.elapsedRealtime());
    }
  }

  private static final class CorrectionChoice {
    static final CorrectionChoice OFF = new CorrectionChoice(false, 0);
    final boolean enabled;
    final long epoch;

    CorrectionChoice(boolean enabled, long epoch) {
      this.enabled = enabled;
      this.epoch = epoch;
    }
  }

  MicrophoneMonitor(
      Context context,
      Runnable changed,
      Consumer<String> notice,
      java.util.function.Supplier<MicrophoneInput.Reading> readings) {
    audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
    this.changed = changed;
    this.notice = notice;
    this.readings = readings;
  }

  static boolean supported(AudioDeviceInfo device) {
    if (device == null || !device.isSink()) return false;
    switch (device.getType()) {
      case AudioDeviceInfo.TYPE_WIRED_HEADSET:
      case AudioDeviceInfo.TYPE_WIRED_HEADPHONES:
      case AudioDeviceInfo.TYPE_USB_DEVICE:
      case AudioDeviceInfo.TYPE_USB_HEADSET:
      case AudioDeviceInfo.TYPE_LINE_ANALOG:
        return true;
      default:
        return false;
    }
  }

  List<AudioDeviceInfo> outputs() {
    ArrayList<AudioDeviceInfo> devices = new ArrayList<>();
    for (AudioDeviceInfo device : audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS))
      if (supported(device)) devices.add(device);
    return devices;
  }

  boolean enabled() {
    return active != null;
  }

  boolean audible() {
    Run run = active;
    return run != null && run.audible;
  }

  boolean resourcesReleased() {
    return active == null && outputOwner == null;
  }

  boolean correctionAvailable() {
    Run run = active;
    return current(run) && run.ready;
  }

  boolean correctionEnabled() {
    Run run = active;
    return current(run) && run.correction.enabled;
  }

  boolean correction(boolean enabled) {
    Run run = active;
    if (run == null) return false;
    synchronized (run) {
      if (!current(run) || enabled && !run.ready) return false;
      run.correction =
          enabled
              ? new CorrectionChoice(true, SystemClock.elapsedRealtime())
              : CorrectionChoice.OFF;
    }
    changed.run();
    return true;
  }

  float gain() {
    return gain;
  }

  VocalMonitorEffects.Mode mode() {
    return mode;
  }

  void gain(float value) {
    if (Float.isFinite(value)) gain = Math.max(0, Math.min(.35f, value));
  }

  void mode(VocalMonitorEffects.Mode value) {
    if (value != null) mode = value;
  }

  boolean start(AudioDeviceInfo selected) {
    if (enabled() || !supported(selected)) return false;
    boolean connected = outputs().stream().anyMatch(d -> d.getId() == selected.getId());
    if (!connected) return false;
    gain = .1f;
    mode = VocalMonitorEffects.Mode.DRY;
    Run run = new Run(selected);
    active = run;
    worker.execute(() -> output(run));
    changed.run();
    return true;
  }

  void offer(short[] input, int count) {
    Run run = active;
    if (current(run)) run.buffer.offer(input, count);
  }

  void stop() {
    Run run = active;
    active = null;
    if (run != null) retire(run);
  }

  private boolean current(Run run) {
    return run != null && active == run && !run.cancelled;
  }

  private void retire(Run run) {
    run.cancelled = true;
    run.audible = false;
    run.ready = false;
    run.correction = CorrectionChoice.OFF;
    run.guard.close();
    synchronized (run) {
      if (run.track != null) {
        try {
          run.track.setVolume(0);
          run.track.pause();
          run.track.flush();
        } catch (RuntimeException ignored) {
        }
      }
    }
    run.buffer.clear();
  }

  private void fail(Run run, String message) {
    if (!current(run)) return;
    retire(run);
    main.post(
        () -> {
          if (active != run) return;
          active = null;
          notice.accept(message);
          changed.run();
        });
  }

  private int[] routed(AudioTrack track) {
    if (Build.VERSION.SDK_INT >= 36) {
      List<AudioDeviceInfo> devices = track.getRoutedDevices();
      int[] ids = new int[devices.size()];
      for (int i = 0; i < ids.length; i++)
        ids[i] = supported(devices.get(i)) ? devices.get(i).getId() : -1;
      return ids;
    }
    AudioDeviceInfo device = track.getRoutedDevice();
    return device == null ? new int[0] : new int[] {supported(device) ? device.getId() : -1};
  }

  private void output(Run run) {
    outputOwner = run;
    float[] block = new float[480];
    VocalMonitorEffects effects = new VocalMonitorEffects();
    ChromaticPitchCorrector corrector = new ChromaticPitchCorrector();
    CorrectionChoice priorChoice = CorrectionChoice.OFF;
    AudioDeviceCallback deviceChanges =
        new AudioDeviceCallback() {
          @Override
          public void onAudioDevicesRemoved(AudioDeviceInfo[] removed) {
            for (AudioDeviceInfo device : removed)
              if (device.getId() == run.device.getId()) {
                fail(
                    run,
                    "Monitoring stopped: the selected output disconnected. Reconnect and enable it"
                        + " again.");
                return;
              }
          }
        };
    AudioRouting.OnRoutingChangedListener routing =
        router -> {
          if (!current(run)) return;
          synchronized (run) {
            if (run.track != null
                && run.guard.verify(routed(run.track), SystemClock.elapsedRealtime())
                    == MonitorRouteGuard.Decision.STOP)
              fail(
                  run,
                  "Monitoring stopped because the audio route changed. Enable it again when"
                      + " ready.");
          }
        };
    boolean callbackRegistered = false;
    AudioTrack track = null;
    try {
      if (!current(run)) return;
      int minimum =
          AudioTrack.getMinBufferSize(
              RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT);
      if (minimum <= 0 || minimum > RATE / 5 * 4) throw new IllegalStateException();
      track =
          new AudioTrack.Builder()
              .setAudioAttributes(
                  new AudioAttributes.Builder()
                      .setUsage(AudioAttributes.USAGE_MEDIA)
                      .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                      .build())
              .setAudioFormat(
                  new AudioFormat.Builder()
                      .setSampleRate(RATE)
                      .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                      .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                      .build())
              .setTransferMode(AudioTrack.MODE_STREAM)
              .setBufferSizeInBytes(Math.max(minimum, 3840))
              .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
              .build();
      synchronized (run) {
        run.track = track;
      }
      if (track.getState() != AudioTrack.STATE_INITIALIZED) throw new IllegalStateException();
      if (!current(run)) return;
      if (track.setVolume(0) != AudioTrack.SUCCESS) throw new IllegalStateException();
      if (!track.setPreferredDevice(run.device)) throw new IllegalStateException();
      track.addOnRoutingChangedListener(routing, main);
      audio.registerAudioDeviceCallback(deviceChanges, main);
      callbackRegistered = true;
      // Only zeroes are queued before actual routing has been verified.
      int warmupFrames = track.getBufferSizeInFrames();
      if (warmupFrames <= 0 || warmupFrames > RATE / 5) throw new IllegalStateException();
      float[] warmup = new float[warmupFrames];
      track.write(warmup, 0, warmup.length, AudioTrack.WRITE_NON_BLOCKING);
      track.play();
      boolean ready = false;
      while (current(run)) {
        MonitorRouteGuard.Decision decision =
            run.guard.verify(routed(track), SystemClock.elapsedRealtime());
        if (decision == MonitorRouteGuard.Decision.STOP) {
          fail(run, "Monitoring stopped: wired or USB output could not be verified.");
          return;
        }
        if (decision == MonitorRouteGuard.Decision.ALLOW) {
          ready = true;
          break;
        }
        SystemClock.sleep(4);
      }
      if (!ready || !current(run)) return;
      run.buffer.clear();
      run.ready = true;
      main.post(
          () -> {
            if (current(run)) changed.run();
          });
      long correctionFloor = SystemClock.elapsedRealtime();
      int offset = block.length;
      long lastWrite = SystemClock.elapsedRealtime(), discontinuity = run.buffer.discontinuities();
      boolean hasInput = false;
      while (current(run)) {
        synchronized (run) {
          if (!current(run)) break;
          if (run.guard.verify(routed(track), SystemClock.elapsedRealtime())
              != MonitorRouteGuard.Decision.ALLOW) {
            fail(run, "Monitoring stopped because the selected output changed.");
            break;
          }
          if (offset == block.length) {
            hasInput = run.buffer.drain(block);
            long currentDiscontinuity = run.buffer.discontinuities();
            CorrectionChoice choice = run.correction;
            if (!hasInput || currentDiscontinuity != discontinuity || choice != priorChoice) {
              effects.reset();
              corrector.reset();
              correctionFloor = SystemClock.elapsedRealtime();
            }
            discontinuity = currentDiscontinuity;
            priorChoice = choice;
            if (choice.enabled) {
              MicrophoneInput.Reading reading = readings.get();
              long now = SystemClock.elapsedRealtime();
              if (reading != null
                  && reading.pitch != null
                  && reading.measuredAt - 86 >= Math.max(choice.epoch, correctionFloor))
                corrector.update(
                    reading.pitch.frequencyHz,
                    reading.pitch.confidence,
                    reading.pitch.rms,
                    reading.measuredAt,
                    now);
              else corrector.update(0, 0, 0, 0, now);
              corrector.process(block);
            }
            effects.mode(mode);
            effects.process(block);
            offset = 0;
          }
          float volume = hasInput ? gain : 0;
          if (track.setVolume(volume) != AudioTrack.SUCCESS) throw new IllegalStateException();
          run.audible = volume > 0;
          int written =
              track.write(block, offset, block.length - offset, AudioTrack.WRITE_NON_BLOCKING);
          if (written < 0) throw new IllegalStateException();
          offset += written;
          if (written > 0) lastWrite = SystemClock.elapsedRealtime();
          else if (SystemClock.elapsedRealtime() - lastWrite > 500)
            throw new IllegalStateException();
        }
        SystemClock.sleep(2);
      }
    } catch (RuntimeException failure) {
      fail(
          run,
          "Monitoring stopped because the output is unavailable. Microphone input is unchanged.");
    } finally {
      retire(run);
      if (callbackRegistered) {
        try {
          audio.unregisterAudioDeviceCallback(deviceChanges);
        } catch (RuntimeException ignored) {
        }
      }
      if (track != null) {
        synchronized (run) {
          try {
            track.setVolume(0);
            track.removeOnRoutingChangedListener(routing);
            track.pause();
            track.flush();
          } catch (RuntimeException ignored) {
          }
          try {
            track.release();
          } catch (RuntimeException ignored) {
          }
          run.track = null;
        }
      }
      effects.reset();
      corrector.reset();
      java.util.Arrays.fill(block, 0);
      outputOwner = null;
    }
  }
}
