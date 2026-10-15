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
                .orElseThrow();
        check(
            java.util.Arrays.equals(
                original.readAllBytes(),
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
          session.songs.stream().filter(SessionController::isAudio).findFirst().orElseThrow();
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

  private long position() {
    AtomicReference<Long> value = new AtomicReference<>(0L);
    runOnMainSync(() -> value.set(session.position()));
    return value.get();
  }
}
