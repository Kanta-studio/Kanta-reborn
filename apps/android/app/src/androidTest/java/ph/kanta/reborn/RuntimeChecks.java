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
  private MainActivity activity;
  private SessionController session;

  @Override
  public void onCreate(Bundle arguments) {
    super.onCreate(arguments);
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
      check(state(() -> session.songs.size() == 3), "Clean install starter catalog");
      check(
          state(() -> contains(activity.getWindow().getDecorView(), "KANTA")),
          "Native activity did not render");
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
      runOnMainSync(activity::toggleCamera);
      await(activity::cameraStreaming, "Camera did not coexist with native MIDI playback");
      long cameraPosition = position();
      await(
          () -> session.playing && session.position() > cameraPosition + 200,
          "Camera preview interrupted the audible karaoke clock");
      capture("runtime-camera.png");
      runOnMainSync(activity::toggleCamera);

      runOnMainSync(() -> session.controls(.7f, 1.5f, 3));
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
      // Missing private data must leave the remaining singer's reservation recoverable.
      runOnMainSync(
          () -> {
            session.remove(session.queue.peek().id);
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
      Song missing =
          new Song("missing-runtime-fixture", "Missing fixture", "", "999", "missing.mid", false);
      runOnMainSync(
          () -> {
            session.reserve(missing, "Retry");
            session.next();
          });
      await(() -> !session.loading, "Failed media preparation never completed");
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
