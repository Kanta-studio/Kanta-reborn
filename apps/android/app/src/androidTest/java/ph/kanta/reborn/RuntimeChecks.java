package ph.kanta.reborn;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.os.*;
import android.view.*;
import android.widget.TextView;
import java.io.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BooleanSupplier;
import ph.kanta.reborn.core.*;

/**
 * Instrumentation exercises real JNI, AudioTrack and activity lifecycle on a clean test install.
 */
public final class RuntimeChecks extends Instrumentation {
  private int checks;
  private boolean focusedVisual;
  private MainActivity activity;
  private SessionController session;

  @Override
  public void onCreate(Bundle arguments) {
    super.onCreate(arguments);
    focusedVisual = arguments != null && "focused".equals(arguments.getString("kanta.mode"));
    start();
  }

  private void check(boolean condition, String message) {
    checks++;
    if (!condition) throw new AssertionError(message);
  }

  private boolean state(BooleanSupplier predicate) {
    AtomicReference<Boolean> result = new AtomicReference<>(false);
    runOnMainSync(() -> result.set(predicate.getAsBoolean()));
    return result.get();
  }

  private void await(BooleanSupplier predicate, String message) {
    long deadline = SystemClock.uptimeMillis() + 15000;
    while (!state(predicate) && SystemClock.uptimeMillis() < deadline) SystemClock.sleep(50);
    check(state(predicate), message);
  }

  private boolean contains(View view, String text) {
    if (view instanceof TextView && ((TextView) view).getText().toString().contains(text))
      return true;
    if (view instanceof ViewGroup) {
      ViewGroup group = (ViewGroup) view;
      for (int i = 0; i < group.getChildCount(); i++)
        if (contains(group.getChildAt(i), text)) return true;
    }
    return false;
  }

  @Override
  public void onStart() {
    Bundle result = new Bundle();
    try {
      Intent launch =
          new Intent(getTargetContext(), MainActivity.class)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      activity = (MainActivity) startActivitySync(launch);
      session = ((KantaApplication) activity.getApplication()).session;
      await(() -> session.ready, "Library did not open");
      check(
          state(
              () -> !session.scoringEnabled && session.score == null && session.lastScore == null),
          "Fresh session enabled scoring or restored a completion");
      check(
          state(
              () -> !session.monitor.correctionEnabled() && !session.monitor.correctionAvailable()),
          "Fresh session enabled pitch correction or exposed an unverified output");
      check(state(() -> session.songs.size() == 3), "Clean install starter catalog");
      check(
          state(() -> contains(activity.getWindow().getDecorView(), "KANTA")),
          "Native activity did not render");
      if (focusedVisual) {
        focusedVisualChecks();
        result.putString("stream", "KANTA runtime: " + checks + " checks passed (focused visual UI)\n");
        finish(Activity.RESULT_OK, result);
        return;
      }
      companionChecks();
      Song song = session.songs.get(0);
      LibraryRepository isolated =
          new LibraryRepository(getTargetContext().createDeviceProtectedStorageContext());
      isolated.load();
      java.util.List<android.net.Uri> files =
          DocumentTreeScanner.scan(
              getTargetContext().getContentResolver(),
              android.provider.DocumentsContract.buildTreeDocumentUri(
                  FixtureProvider.AUTHORITY, "root"),
              () -> false);
      check(files.size() == 4, "SAF nested traversal or cycle bound");
      boolean cancelled = false;
      try {
        isolated.importBatch(
            java.util.Arrays.asList(FixtureProvider.file("song"), FixtureProvider.file("bank")),
            () -> isolated.songs().size() > 3);
      } catch (java.io.InterruptedIOException expected) {
        cancelled = true;
      }
      check(cancelled && isolated.songs().size() == 3, "Cancelled batch published staged songs");
      LibraryRepository afterCancel =
          new LibraryRepository(getTargetContext().createDeviceProtectedStorageContext());
      afterCancel.load();
      check(afterCancel.songs().size() == 3, "Cancelled batch changed durable catalog");
      int[] imported = isolated.importBatch(files, () -> false);
      check(
          imported[0] == 3 && imported[1] == 1 && isolated.songs().size() == 5,
          "SAF partial import or SoundFont selection");
      check(
          !isolated.soundFontName().equals("KANTA original tone"),
          "SoundFont override not retained");
      try (InputStream original =
          getTargetContext().getContentResolver().openInputStream(FixtureProvider.file("song"))) {
        Song copy =
            isolated.songs().stream()
                .filter(value -> value.title.equals("Original KAR"))
                .findFirst()
                .orElseThrow(() -> new AssertionError("Missing fixture song"));
        check(
            java.util.Arrays.equals(
                readFixture(original),
                java.nio.file.Files.readAllBytes(new File(isolated.media, copy.fileName).toPath())),
            "Imported source bytes changed");
      }
      runOnMainSync(
          () ->
              session.importSongs(
                  java.util.Collections.singletonList(FixtureProvider.file("audio"))));
      await(
          () -> !session.importing && session.songs.size() == 4, "Controller audio import failed");
      Song loopSong =
          session.songs.stream()
              .filter(SessionController::isAudio)
              .findFirst()
              .orElseThrow(() -> new AssertionError("Missing fixture song"));
      StageMediaStore visualStore =
          new StageMediaStore(getTargetContext().createDeviceProtectedStorageContext());
      visualStore.load();
      boolean cancelledPhoto = false;
      try {
        visualStore.importMedia(FixtureProvider.file("photo"), false, () -> true);
      } catch (java.io.InterruptedIOException expected) {
        cancelledPhoto = true;
      }
      check(
          cancelledPhoto && visualStore.selection().kind.equals("scenic"),
          "Cancelled photo import changed selection");
      StageMediaStore.Selection photo =
          visualStore.importMedia(FixtureProvider.file("photo"), false, () -> false);
      StageMediaStore reloadedVisuals =
          new StageMediaStore(getTargetContext().createDeviceProtectedStorageContext());
      check(reloadedVisuals.load().kind.equals("photo"), "Visual selection did not persist");
      try (InputStream original =
          getTargetContext().getContentResolver().openInputStream(FixtureProvider.file("photo"))) {
        check(
            java.util.Arrays.equals(
                readFixture(original), java.nio.file.Files.readAllBytes(photo.photo.toPath())),
            "Photo source bytes changed");
      }
      android.graphics.Bitmap decoded = StageMediaStore.displayPhoto(photo.photo);
      check(decoded.getWidth() == 80 && decoded.getHeight() == 60, "Photo display decode failed");
      decoded.recycle();
      boolean rejectedPhoto = false;
      try {
        visualStore.importMedia(FixtureProvider.file("bad"), false, () -> false);
      } catch (IOException expected) {
        rejectedPhoto = true;
      }
      check(
          rejectedPhoto && visualStore.selection().photo.equals(photo.photo),
          "Invalid photo replaced the saved image");
      StageMediaStore.Selection savedVideo =
          visualStore.importMedia(FixtureProvider.file("video"), true, () -> false);
      try (InputStream original =
          getTargetContext().getContentResolver().openInputStream(FixtureProvider.file("video"))) {
        check(
            java.util.Arrays.equals(
                readFixture(original), java.nio.file.Files.readAllBytes(savedVideo.video.toPath())),
            "Video source bytes changed");
      }
      check(
          new StageMediaStore(getTargetContext().createDeviceProtectedStorageContext())
              .load()
              .kind
              .equals("video"),
          "Video selection did not persist");
      boolean rejectedVideo = false;
      try {
        visualStore.importMedia(FixtureProvider.file("bad"), true, () -> false);
      } catch (IOException expected) {
        rejectedVideo = true;
      }
      check(
          rejectedVideo && visualStore.selection().video.equals(savedVideo.video),
          "Invalid video replaced the saved clip");
      check(
          visualStore.select("scenic").kind.equals("scenic")
              && visualStore.select("photo").photo.equals(photo.photo),
          "Switching visual kinds discarded saved media");
      await(() -> session.stageReady, "Visual storage did not become ready");
      runOnMainSync(() -> session.importStage(FixtureProvider.file("photo"), false));
      await(
          () ->
              !session.importing
                  && session.stageKind.equals("photo")
                  && session.scenic != null
                  && session.scenic.getWidth() == 80,
          "Controller photo import failed");
      AtomicReference<View> stableStage = new AtomicReference<>();
      runOnMainSync(
          () ->
              stableStage.set(
                  activity.getWindow().getDecorView().findViewWithTag("kanta.stage.primary")));
      runOnMainSync(session::publish);
      check(
          state(
              () ->
                  stableStage.get()
                      == activity
                          .getWindow()
                          .getDecorView()
                          .findViewWithTag("kanta.stage.primary")),
          "Controller update detached the stage subtree");
      await(() -> stableStage.get().getWidth() > 0, "Stage layout never became visible");
      check(
          state(
              () -> {
                for (String name : new String[] {"My Set", "Loop", "Scenic", "Realm", "Control"}) {
                  View tab =
                      activity.getWindow().getDecorView().findViewWithTag("kanta.nav." + name);
                  android.graphics.Rect visible = new android.graphics.Rect();
                  if (tab == null
                      || !tab.getGlobalVisibleRect(visible)
                      || visible.width() != tab.getWidth()
                      || visible.height() != tab.getHeight()) return false;
                }
                return true;
              }),
          "Navigation tab is clipped on the phone display");
      runOnMainSync(() -> session.importStage(FixtureProvider.file("video"), true));
      await(
          () -> !session.importing && session.stageKind.equals("video"),
          "Controller video import failed");
      await(
          () -> ((StageSurface) stableStage.get()).isVideoVisible(),
          "Muted video did not render under lyrics");
      runOnMainSync(() -> ((StageSurface) stableStage.get()).setVisualActive(false));
      check(
          state(() -> !((StageSurface) stableStage.get()).isVideoVisible()),
          "Inactive stage retained video rendering");
      runOnMainSync(() -> ((StageSurface) stableStage.get()).setVisualActive(true));
      await(
          () -> ((StageSurface) stableStage.get()).isVideoVisible(),
          "Video did not resume after reactivation");
      runOnMainSync(() -> session.scene("bayanDawn"));
      check(state(() -> session.stageVideo == null), "Scenic selection retained video playback");
      check(
          state(() -> !session.cameraPreviewEnabled && !activity.cameraStreaming()),
          "Camera was enabled without opt-in");
      check(
          getTargetContext().checkSelfPermission(android.Manifest.permission.CAMERA)
              != android.content.pm.PackageManager.PERMISSION_GRANTED,
          "Fresh installation unexpectedly had camera permission");
      shell("pm grant ph.kanta.reborn android.permission.CAMERA");
      runOnMainSync(activity::toggleCamera);
      await(
          () -> activity.cameraStreaming() && ((StageSurface) stableStage.get()).isCameraVisible(),
          "Opt-in front camera never rendered");
      runOnMainSync(activity::fullscreen);
      await(
          () -> activity.cameraStreaming() && !((StageSurface) stableStage.get()).isCameraVisible(),
          "Front camera did not move to fullscreen");
      runOnMainSync(activity::closeFullscreen);
      await(
          () -> activity.cameraStreaming() && ((StageSurface) stableStage.get()).isCameraVisible(),
          "Front camera did not return to the primary stage");
      runOnMainSync(activity::toggleCamera);
      check(
          state(
              () ->
                  !session.cameraPreviewEnabled
                      && !activity.cameraStreaming()
                      && !((StageSurface) stableStage.get()).isCameraVisible()),
          "Disabling the camera retained its preview");
      runOnMainSync(activity::toggleCamera);
      await(activity::cameraStreaming, "Camera did not reopen after explicit opt-in");
      shell("input keyevent KEYCODE_HOME");
      await(() -> !session.foreground, "Home did not background KANTA");
      check(
          state(() -> !session.cameraPreviewEnabled && !activity.cameraStreaming()),
          "Backgrounding KANTA retained camera preview");
      shell("am start -n ph.kanta.reborn/.MainActivity --activity-reorder-to-front");
      await(() -> session.foreground, "KANTA did not return to the foreground");
      check(
          state(() -> !session.cameraPreviewEnabled && !activity.cameraStreaming()),
          "Foregrounding KANTA re-enabled camera without opt-in");

      runOnMainSync(
          () ->
              activity
                  .getWindow()
                  .getDecorView()
                  .findViewWithTag("kanta.voice.settings")
                  .performClick());
      check(
          state(
              () ->
                  contains(activity.getWindow().getDecorView(), "Wired / USB monitoring")
                      && contains(activity.getWindow().getDecorView(), "Turn on microphone")),
          "Voice settings did not expand from Control");
      check(
          state(
              () -> {
                View correction =
                    activity
                        .getWindow()
                        .getDecorView()
                        .findViewWithTag("kanta.pitchcorrection.toggle");
                return correction != null
                    && !correction.isEnabled()
                    && contains(activity.getWindow().getDecorView(), "Turn on pitch correction");
              }),
          "Correction control was missing or enabled before verified monitoring");
      runOnMainSync(
          () ->
              activity
                  .getWindow()
                  .getDecorView()
                  .findViewWithTag("kanta.voice.settings")
                  .performClick());
      check(
          state(() -> !contains(activity.getWindow().getDecorView(), "Wired / USB monitoring")),
          "Collapsed voice settings still occupied Control");
      check(
          state(
              () ->
                  !session.microphone.enabled()
                      && !session.microphone.capturing()
                      && session.microphone.reading() == null),
          "Microphone enabled without opt-in");
      check(
          getTargetContext().checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)
              != android.content.pm.PackageManager.PERMISSION_GRANTED,
          "Fresh install unexpectedly had microphone permission");
      runOnMainSync(session::startMicrophone);
      check(state(() -> !session.microphone.enabled()), "Capture bypassed microphone permission");
      check(
          state(
              () ->
                  !session.monitor.enabled()
                      && !session.monitor.audible()
                      && session.monitor.resourcesReleased()),
          "Monitoring enabled without explicit opt-in");
      check(
          state(
              () ->
                  !session.monitor.correction(true)
                      && !session.monitor.enabled()
                      && !session.microphone.enabled()),
          "Correction selection activated output or microphone without monitoring");
      android.media.AudioManager audio =
          (android.media.AudioManager) getTargetContext().getSystemService(Context.AUDIO_SERVICE);
      android.media.AudioDeviceInfo speaker = null;
      for (android.media.AudioDeviceInfo device :
          audio.getDevices(android.media.AudioManager.GET_DEVICES_OUTPUTS))
        if (device.getType() == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
          speaker = device;
      check(
          speaker != null && !MicrophoneMonitor.supported(speaker),
          "Built-in speaker was an accepted monitor route");
      final android.media.AudioDeviceInfo rejectedSpeaker = speaker;
      check(
          state(() -> session.monitor.outputs().isEmpty()),
          "Clean emulator unexpectedly exposes wired/USB hardware");
      shell("pm grant ph.kanta.reborn android.permission.RECORD_AUDIO");
      runOnMainSync(activity::toggleMicrophone);
      await(
          () -> session.microphone.capturing() && session.microphone.reading() != null,
          "Opt-in AudioRecord did not produce input frames: " + session.message);
      runOnMainSync(() -> session.startMonitor(rejectedSpeaker));
      check(
          state(
              () ->
                  !session.monitor.enabled()
                      && !session.monitor.audible()
                      && session.microphone.capturing()),
          "Speaker rejection stopped input or produced monitor output");
      check(
          state(
              () ->
                  !session.monitor.correction(true)
                      && !session.monitor.correctionEnabled()
                      && session.microphone.capturing()),
          "Correction bypassed route rejection or stopped dry capture");
      runOnMainSync(activity::toggleMonitoring);
      check(
          state(() -> !session.monitor.enabled() && session.message.startsWith("Connect wired")),
          "Monitoring with no supported hardware did not explain rejection");
      runOnMainSync(
          () -> {
            session.monitor.mode(VocalMonitorEffects.Mode.HALL);
            session.monitor.gain(.9f);
          });
      check(
          state(() -> session.monitor.gain() == .35f && !session.monitor.enabled()),
          "Effect/volume setting enabled output or bypassed gain bound");
      runOnMainSync(() -> session.monitor.gain(Float.NaN));
      check(state(() -> session.monitor.gain() == .35f), "Nonfinite monitor gain accepted");
      runOnMainSync(() -> session.monitor.gain(-1));
      check(
          state(() -> session.monitor.gain() == 0 && !session.monitor.audible()),
          "Negative monitor gain accepted");
      check(
          state(() -> session.microphone.reading().pitch == null),
          "Silent emulator produced a vocal pitch");
      runOnMainSync(activity::toggleMicrophone);
      await(() -> session.microphone.resourcesReleased(), "AudioRecord did not release after stop");
      check(
          state(() -> session.monitor.resourcesReleased() && !session.monitor.audible()),
          "Stopping microphone retained monitor output");
      check(
          state(
              () -> !session.monitor.correctionEnabled() && !session.monitor.correctionAvailable()),
          "Stopping input retained correction activation");
      check(
          state(() -> !session.microphone.enabled() && session.microphone.reading() == null),
          "Explicit microphone stop retained measurements");
      runOnMainSync(activity::toggleMicrophone);
      await(
          () -> session.microphone.capturing(), "Microphone did not reopen after explicit opt-in");
      shell("input keyevent KEYCODE_HOME");
      await(() -> !session.foreground, "Home did not background microphone host");
      await(
          () -> session.microphone.resourcesReleased(),
          "Background retained AudioRecord resources");
      check(
          state(
              () ->
                  !session.microphone.enabled()
                      && !session.microphone.capturing()
                      && session.microphone.reading() == null),
          "Background retained capture or dry readings");
      shell("am start -n ph.kanta.reborn/.MainActivity --activity-reorder-to-front");
      await(() -> session.foreground, "Microphone host did not foreground");
      check(
          state(() -> !session.microphone.enabled()), "Returning automatically enabled microphone");
      check(
          state(() -> !session.monitor.enabled() && session.monitor.resourcesReleased()),
          "Foregrounding restored monitoring without opt-in");
      check(
          state(() -> !session.monitor.correctionEnabled() && !session.monitor.correction(true)),
          "Returning restored pitch correction without verified monitoring");
      runOnMainSync(
          () -> {
            session.hostVisible(false);
            session.startMicrophone();
            activity.onRequestPermissionsResult(
                17, new String[] {android.Manifest.permission.RECORD_AUDIO}, new int[] {0});
          });
      check(state(() -> !session.microphone.enabled()), "Late grant/background bypassed opt-in");
      runOnMainSync(() -> session.hostVisible(true));
      runOnMainSync(
          () -> {
            activity.toggleMicrophone();
            activity.toggleMicrophone();
            activity.toggleMicrophone();
          });
      await(() -> session.microphone.capturing(), "Rapid microphone replacement failed");
      runOnMainSync(activity::toggleMicrophone);
      check(
          state(() -> session.queue.snapshot().isEmpty() && session.current == null),
          "Microphone changed karaoke ownership");

      runOnMainSync(
          () -> {
            session.reserve(song, "First");
            session.reserve(song, "Second");
          });
      check(
          state(
              () ->
                  session.queue.snapshot().size() == 2
                      && !session
                          .queue
                          .snapshot()
                          .get(0)
                          .id
                          .equals(session.queue.snapshot().get(1).id)),
          "Distinct reservations");
      runOnMainSync(
          () -> {
            session.next();
            session.pause();
          });
      SystemClock.sleep(500);
      check(
          state(() -> !session.playing && !session.loading && session.queue.snapshot().size() == 2),
          "Cancelled preparation consumed a reservation");
      await(
          () -> {
            for (int slot = 0; slot < 8; slot++) if (!session.party.ready(slot)) return false;
            return true;
          },
          "Generated party pads did not load");
      runOnMainSync(
          () -> {
            for (int slot = 0; slot < 8; slot++) session.triggerPad(slot);
          });
      check(
          state(() -> session.party.activeVoices() <= 4 && session.queue.snapshot().size() == 2),
          "Party audio changed karaoke reservations or exceeded voice bound");
      runOnMainSync(session::stopParty);
      check(
          state(() -> session.party.activeVoices() == 0), "Party stop-all retained active voices");
      runOnMainSync(session::next);
      await(
          () -> session.playing && session.current != null,
          "Native MIDI player did not start: " + session.message);
      check(
          state(() -> session.queue.snapshot().size() == 1 && session.singer.equals("First")),
          "Start acknowledgement violated FIFO");
      await(() -> session.position() >= 300, "AudioTrack audible clock did not advance");
      runOnMainSync(() -> session.setScoring(true));
      await(session::scoreReady, "Scoring target did not prepare alongside real MIDI playback");
      check(
          state(() -> !session.microphone.enabled() && !session.monitor.enabled()),
          "Scoring opt-in implicitly enabled microphone or monitored output");
      AtomicReference<MelodyScoreSession> priorScore = new AtomicReference<>();
      runOnMainSync(() -> priorScore.set(session.score));
      runOnMainSync(() -> session.scoreLatency(100));
      await(
          () -> session.scoreReady() && session.score != priorScore.get(),
          "Latency change retained the old scoring accumulator");
      check(
          state(() -> session.score.estimate().matchedSlots == 0),
          "Latency change retained observations");
      runOnMainSync(() -> session.scoreLatency(Integer.MAX_VALUE));
      check(state(() -> session.scoreLatency == 1500), "Positive calibration bound failed");
      runOnMainSync(() -> session.scoreLatency(Integer.MIN_VALUE));
      check(state(() -> session.scoreLatency == -500), "Negative calibration bound failed");
      runOnMainSync(() -> session.scoreLatency(0));
      await(session::scoreReady, "Latest calibration request did not retire stale preparation");

      runOnMainSync(activity::toggleCamera);
      await(activity::cameraStreaming, "Camera did not coexist with native MIDI playback");
      long cameraPosition = position();
      await(
          () -> session.playing && session.position() > cameraPosition + 200,
          "Camera preview interrupted the audible karaoke clock");
      runOnMainSync(activity::toggleMicrophone);
      await(() -> session.microphone.capturing(), "Camera/MIDI/microphone concurrency failed");
      long microphonePosition = position();
      await(
          () -> session.playing && session.position() > microphonePosition + 200,
          "Microphone capture interrupted karaoke time");
      runOnMainSync(activity::toggleMicrophone);
      capture("runtime-camera.png");
      runOnMainSync(activity::toggleCamera);

      runOnMainSync(() -> priorScore.set(session.score));
      runOnMainSync(() -> session.controls(.7f, 1.5f, 3));
      await(
          () -> session.scoreReady() && session.score != priorScore.get(),
          "Key/tempo scoring reset or audible control acknowledgement failed");
      runOnMainSync(() -> priorScore.set(session.score));
      runOnMainSync(() -> session.setVolume(.6f));
      check(state(() -> session.score == priorScore.get()), "Volume-only change cleared scoring");
      runOnMainSync(() -> session.setVolume(.7f));
      long before = position();
      await(() -> session.position() > before + 300, "Controlled playback stopped advancing");
      Bitmap capture = getUiAutomation().takeScreenshot();
      if (capture != null) {
        try (FileOutputStream out =
            new FileOutputStream(new File(getTargetContext().getFilesDir(), "runtime-stage.png"))) {
          capture.compress(Bitmap.CompressFormat.PNG, 100, out);
        }
        capture.recycle();
      }
      runOnMainSync(session::pause);
      SystemClock.sleep(150);
      long paused = position();
      SystemClock.sleep(250);
      check(position() - paused < 50, "Paused audible clock advanced");
      runOnMainSync(session::toggle);
      await(() -> session.playing && session.position() > paused + 100, "Resume failed");
      runOnMainSync(session::stop);
      check(
          state(
              () ->
                  session.lastScore == null
                      && session.score == null
                      && session.playbackIdentity == null),
          "Manual stop fabricated a completion score");
      runOnMainSync(() -> session.remove(session.queue.peek().id));
      runOnMainSync(
          () -> {
            session.controls(.7f, 2, 0);
            session.startMicrophone();
            session.reserve(song, "Score A");
            session.reserve(song, "Score B");
            session.next();
          });
      await(
          () ->
              session.playing
                  && session.singer.equals("Score A")
                  && session.scoreReady()
                  && session.microphone.capturing(),
          "First natural-completion scoring playback did not start");
      AtomicReference<java.util.UUID> scoreA = new AtomicReference<>(),
          scoreB = new AtomicReference<>();
      runOnMainSync(() -> scoreA.set(session.playbackIdentity));
      await(
          () ->
              session.lastScore != null && session.lastScore.playbackIdentity.equals(scoreA.get()),
          "First natural ending did not publish its completion identity");
      check(
          state(
              () ->
                  !session.lastScore.estimate.reportable
                      && session.lastScore.estimate.matchedSlots == 0),
          "Silent dry input produced a reportable song score");
      await(
          () -> session.playing && session.singer.equals("Score B") && session.scoreReady(),
          "Scoring completion did not advance the existing FIFO");
      runOnMainSync(() -> scoreB.set(session.playbackIdentity));
      check(!scoreA.get().equals(scoreB.get()), "Repeated song reused scoring playback identity");
      await(
          () ->
              session.lastScore != null
                  && session.lastScore.playbackIdentity.equals(scoreB.get())
                  && session.current == null
                  && !session.playing,
          "Second natural completion did not retain its own final result");
      check(
          state(() -> !session.lastScore.estimate.reportable && session.queue.snapshot().isEmpty()),
          "Insufficient second input became a score or changed FIFO ownership");
      check(
          state(
              () ->
                  contains(
                      activity.getWindow().getDecorView(),
                      "Not enough stable voice input for a score")),
          "Last-song UI displayed a fabricated score for silence");
      runOnMainSync(
          () -> {
            session.stopMicrophone();
            session.setScoring(false);
            session.chooseIntermission(loopSong);
            session.toggleIntermission();
          });
      await(() -> session.party.loopPlaying(), "Idle intermission did not start");
      runOnMainSync(() -> session.assignPad(6, loopSong));
      await(() -> !session.assigningPad, "Custom pad decode never acknowledged");
      check(
          state(() -> session.customPads[6].equals(loopSong.id)),
          "Custom pad preference did not commit");
      runOnMainSync(() -> session.resetPad(6));
      check(state(() -> session.customPads[6].isEmpty()), "Custom pad reset failed");
      // Missing private data must leave the reservation recoverable.
      Song missing =
          new Song("missing-runtime-fixture", "Missing fixture", "", "999", "missing.mid", false);
      runOnMainSync(
          () -> {
            session.reserve(missing, "Retry");
            session.next();
          });
      await(() -> !session.loading, "Failed media preparation never completed");
      check(
          state(() -> session.lastScore.playbackIdentity.equals(scoreB.get())),
          "Failed preparation overwrote a completed score");
      check(!state(() -> session.party.loopPlaying()), "Intermission overlapped a reservation");
      check(
          state(
              () ->
                  !session.playing
                      && session.queue.peek() != null
                      && session.queue.peek().song.id.equals(missing.id)),
          "Failed preparation consumed reservation");
      runOnMainSync(
          () -> {
            session.remove(session.queue.peek().id);
            session.stopParty();
            activity.finish();
          });
      result.putString(
          "stream",
          "KANTA runtime: "
              + checks
              + " checks passed (native MIDI, FIFO, cancellation, controls, pause/resume, failed"
              + " prepare, UI)\n");
      finish(Activity.RESULT_OK, result);
    } catch (Throwable failure) {
      result.putString("stream", android.util.Log.getStackTraceString(failure));
      finish(Activity.RESULT_CANCELED, result);
    }
  }

  private void focusedVisualChecks() throws Exception {
    // Exercise native controls without running the long media, permissions and DSP suite.
    String[] tabs = {"Control", "My Set", "Scenic", "Realm", "Loop"};
    for (String name : tabs) {
      await(() -> activity.getWindow().getDecorView()
          .findViewWithTag("kanta.nav." + name) != null, "Missing navigation: " + name);
      runOnMainSync(() -> {
        View tab = activity.getWindow().getDecorView().findViewWithTag("kanta.nav." + name);
        tab.performClick();
      });
      check(state(() -> {
        View tab = activity.getWindow().getDecorView().findViewWithTag("kanta.nav." + name);
        return tab != null && tab.isSelected();
      }), "Navigation did not select " + name);
      capture("runtime-ui-" + name.toLowerCase(java.util.Locale.ROOT).replace(' ', '-') + ".png");
    }
    // The authoritative queue remains empty after purely visual navigation.
    check(state(() -> session.queue.snapshot().isEmpty()), "UI navigation changed the queue");
    runOnMainSync(activity::finish);
  }

  private void companionChecks() throws Exception {
    check(!state(() -> session.companion.enabled()), "Companion enabled without opt-in");
    java.util.List<String> addresses = CompanionControl.addresses();
    check(!addresses.isEmpty(), "Emulator has no private network interface");
    String address = addresses.get(0);
    runOnMainSync(() -> session.companion.startHost(address));
    await(() -> !session.companion.pairing.isEmpty(), "Companion host did not bind");
    AtomicReference<String> code = new AtomicReference<>();
    runOnMainSync(() -> code.set(session.companion.pairing));
    try (java.net.Socket socket = new java.net.Socket(address, CompanionControl.PORT)) {
      socket.setSoTimeout(5000);
      try (CompanionProtocol.Channel channel = CompanionProtocol.handshake(
          socket.getInputStream(), socket.getOutputStream(), code.get(), false)) {
        await(() -> session.companion.pairing.isEmpty(), "Connected host retained pairing code");
        CompanionProtocol.Request search = new CompanionProtocol.Request(java.util.UUID.randomUUID(), "search", "Morning", "");
        org.json.JSONObject found = companionRequest(channel, search);
        check(found.getJSONArray("songs").length() == 1, "Encrypted host search failed");
        check(!found.toString().contains("fileName"), "Companion exposed private media path");
        String songId = found.getJSONArray("songs").getJSONObject(0).getString("id");
        CompanionProtocol.Request reserve = new CompanionProtocol.Request(java.util.UUID.randomUUID(), "reserve", songId, "Companion test");
        org.json.JSONObject reserved = companionRequest(channel, reserve);
        check(reserved.getJSONArray("queue").length() == 1, "Companion did not reserve in authoritative FIFO");
        org.json.JSONObject replayed = companionRequest(channel, reserve);
        check(replayed.toString().equals(reserved.toString()), "Duplicate command did not return its original reply");
        check(state(() -> session.queue.snapshot().size() == 1), "Duplicate companion command reserved twice");
        companionRequest(channel, new CompanionProtocol.Request(java.util.UUID.randomUUID(), "reserve", songId, "Another turn"));
        check(state(() -> session.queue.snapshot().size() == 2), "Intentional repeated song was suppressed");
        String first = reserved.getJSONArray("queue").getJSONObject(0).getString("id");
        org.json.JSONObject remaining = companionRequest(channel, new CompanionProtocol.Request(java.util.UUID.randomUUID(), "cancel", first, ""));
        check(remaining.getJSONArray("queue").length() == 1, "Companion cancellation affected another turn");
        companionRequest(channel, new CompanionProtocol.Request(java.util.UUID.randomUUID(), "cancel", remaining.getJSONArray("queue").getJSONObject(0).getString("id"), ""));
        check(state(() -> session.queue.snapshot().isEmpty()), "Companion cancellation did not reach FIFO");
        check(!state(() -> session.microphone.enabled() || session.cameraPreviewEnabled || session.scoringEnabled), "Companion activated a sensor or scoring");
        runOnMainSync(() -> session.hostVisible(false));
        check(!state(() -> session.companion.enabled()), "Backgrounding did not revoke companion");
        boolean rejected = false;
        try { companionRequest(channel, search); } catch (IOException expected) { rejected = true; }
        check(rejected, "Revoked companion socket remained usable");
        runOnMainSync(() -> session.hostVisible(true));
        check(!state(() -> session.companion.enabled()), "Foregrounding restored companion automatically");
      }
    }
    runOnMainSync(() -> session.companion.startHost("0.0.0.0"));
    check(!state(() -> session.companion.enabled()), "Wildcard companion listener accepted");
  }

  private org.json.JSONObject companionRequest(CompanionProtocol.Channel channel, CompanionProtocol.Request request) throws Exception {
    channel.send(request.encode());
    org.json.JSONObject response = new org.json.JSONObject(new String(channel.receive(), java.nio.charset.StandardCharsets.UTF_8));
    check(request.id.toString().equals(response.getString("request")), "Companion response identity mismatch");
    return response;
  }

  private void capture(String name) throws IOException {
    Bitmap image = getUiAutomation().takeScreenshot();
    if (image == null) throw new IOException("Missing runtime screenshot");
    try (FileOutputStream output =
        new FileOutputStream(new File(getTargetContext().getFilesDir(), name))) {
      if (!image.compress(Bitmap.CompressFormat.PNG, 100, output))
        throw new IOException("Cannot save runtime screenshot");
    } finally {
      image.recycle();
    }
  }

  private void shell(String command) throws IOException {
    try (InputStream result =
        new android.os.ParcelFileDescriptor.AutoCloseInputStream(
            getUiAutomation().executeShellCommand(command))) {
      readFixture(result);
    }
  }

  private byte[] readFixture(InputStream input) throws IOException {
    ByteArrayOutputStream bytes = new ByteArrayOutputStream();
    byte[] block = new byte[4096];
    int count;
    while ((count = input.read(block)) != -1) {
      if (bytes.size() + count > 16 * 1024 * 1024) throw new IOException("Fixture too large");
      bytes.write(block, 0, count);
    }
    return bytes.toByteArray();
  }

  private long position() {
    AtomicReference<Long> value = new AtomicReference<>(0L);
    runOnMainSync(() -> value.set(session.position()));
    return value.get();
  }
}
