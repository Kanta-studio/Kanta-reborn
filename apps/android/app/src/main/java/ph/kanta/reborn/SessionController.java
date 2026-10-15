package ph.kanta.reborn;

import android.content.*;
import android.media.*;
import android.net.Uri;
import android.os.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import ph.kanta.reborn.core.*;

/** One app-lifetime state owner. All MediaPlayer access stays on the main Looper. */
final class SessionController {
  interface Listener {
    void changed();
  }

  final ReservationQueue queue = new ReservationQueue();
  final ExecutorService io = Executors.newSingleThreadExecutor();
  final ExecutorService preparation = Executors.newSingleThreadExecutor();
  final ExecutorService folderWorker = Executors.newSingleThreadExecutor();
  final java.util.concurrent.atomic.AtomicBoolean importCancelled =
      new java.util.concurrent.atomic.AtomicBoolean();
  private File selectedSoundFont;
  final Handler main = new Handler(Looper.getMainLooper());
  final Context context;
  android.graphics.Bitmap scenic;
  String scenicName = "bayanDawn";
  private boolean savingSet = false;
  private LibraryRepository repository;
  List<Song> songs = Collections.emptyList();
  List<LibraryRepository.SavedSet> savedSets = Collections.emptyList();
  List<MidiLyrics.Cue> lyrics = Collections.emptyList();
  final ArrayList<Song> played = new ArrayList<>();
  Song current;
  String singer = "", message = "Opening your library…";
  boolean ready = false, loading = false, playing = false, importing = false;
  private Listener listener;
  private PlaybackBackend player, pending;
  float volume = 1, tempo = 1;
  int pitch;
  String soundFontName = "KANTA original tone";
  private long generation = 0;
  private final AudioManager audio;
  private final AudioFocusRequest focus;

  SessionController(Context context) {
    this.context = context;
    audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
    focus =
        new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build())
            .setOnAudioFocusChangeListener(
                change -> {
                  if (change < 0) pause();
                },
                main)
            .build();
    BroadcastReceiver noisy =
        new BroadcastReceiver() {
          @Override
          public void onReceive(Context c, Intent i) {
            pause();
          }
        };
    if (Build.VERSION.SDK_INT >= 33)
      context.registerReceiver(
          noisy,
          new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
          Context.RECEIVER_NOT_EXPORTED);
    else
      context.registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    io.execute(
        () -> {
          try {
            repository = new LibraryRepository(context);
            repository.load();
            File bank = repository.soundFont();
            String bankLabel = repository.soundFontName();
            List<Song> loaded = repository.songs();
            List<LibraryRepository.SavedSet> sets = repository.sets();
            List<ReservationQueue.Entry> restored = repository.queue();
            main.post(
                () -> {
                  songs = loaded;
                  savedSets = sets;
                  queue.restore(restored);
                  selectedSoundFont = bank;
                  soundFontName = bankLabel;
                  ready = true;
                  message = "Your music. Your stage.";
                  publish();
                });
          } catch (Exception e) {
            main.post(
                () -> {
                  message =
                      "Could not open saved library. Your original files have not been changed.";
                  publish();
                });
          }
        });
  }

  void listen(Listener l) {
    listener = l;
    if (l != null) l.changed();
  }

  void publish() {
    if (listener != null) listener.changed();
  }

  void reserve(Song song, String singer) {
    if (!ready) return;
    try {
      queue.reserve(UUID.randomUUID(), song, singer);
      message = "Reserved " + song.title;
      saveQueue();
      publish();
    } catch (Exception e) {
      message = "Up Next is full";
      publish();
    }
  }

  void remove(UUID id) {
    queue.remove(id);
    saveQueue();
    publish();
  }

  void move(UUID id, int destination) {
    queue.move(id, destination);
    saveQueue();
    publish();
  }

  private void saveQueue() {
    if (repository == null) return;
    List<ReservationQueue.Entry> saved = queue.snapshot();
    io.execute(
        () -> {
          try {
            repository.saveQueue(saved);
          } catch (Exception e) {
            main.post(
                () -> {
                  message = "The queue could not be saved. It remains available for this session.";
                  publish();
                });
          }
        });
  }

  void next() {
    if (loading || !ready) return;
    ReservationQueue.Entry entry = queue.peek();
    if (entry == null) {
      message = "Reserve a song first";
      publish();
      return;
    }
    prepare(entry);
  }

  private void prepare(ReservationQueue.Entry entry) {
    loading = true;
    long token = ++generation;
    message = "Opening " + entry.song.title;
    publish();
    File selectedBank = selectedSoundFont;
    preparation.execute(
        () -> {
          try {
            File file = new File(repository.media, entry.song.fileName);
            MidiLyrics.Document midi =
                entry.song.fileName.endsWith(".mid")
                    ? MidiLyrics.decode(java.nio.file.Files.readAllBytes(file.toPath()))
                    : null;
            File bank = selectedBank;
            List<MidiLyrics.Cue> cues = midi == null ? Collections.emptyList() : midi.cues;
            main.post(
                () -> {
                  if (token != generation) return;
                  PlaybackBackend.Callback callbacks =
                      new PlaybackBackend.Callback() {
                        public void ready(PlaybackBackend candidate) {
                          if (token != generation || pending != candidate) {
                            candidate.release();
                            return;
                          }
                          if (queue.snapshot().stream().noneMatch(e -> e.id.equals(entry.id))) {
                            pending = null;
                            candidate.release();
                            loading = false;
                            publish();
                            return;
                          }
                          if (audio.requestAudioFocus(focus)
                              != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                            pending = null;
                            candidate.release();
                            loading = false;
                            message = "Audio is busy. Try Play again.";
                            publish();
                            return;
                          }
                          try {
                            candidate.controls(volume, tempo, pitch);
                            candidate.start();
                          } catch (Exception e) {
                            failed(candidate);
                          }
                        }

                        public void started(PlaybackBackend candidate) {
                          if (player == candidate) {
                            playing = true;
                            publish();
                            return;
                          }
                          if (token != generation
                              || pending != candidate
                              || queue.snapshot().stream().noneMatch(e -> e.id.equals(entry.id))) {
                            candidate.release();
                            if (pending == candidate) {
                              pending = null;
                              loading = false;
                              publish();
                            }
                            return;
                          }
                          releaseCurrent();
                          player = candidate;
                          pending = null;
                          queue.remove(entry.id);
                          current = entry.song;
                          singer = entry.singer;
                          lyrics = cues;
                          playing = true;
                          loading = false;
                          message = entry.song.title;
                          saveQueue();
                          publish();
                        }

                        public void completed(PlaybackBackend completed) {
                          if (player != completed) return;
                          played.add(current);
                          if (played.size() > 10000) played.remove(0);
                          releaseCurrent();
                          current = null;
                          lyrics = Collections.emptyList();
                          publish();
                          if (!loading) nextIfReserved();
                        }

                        public void failed(PlaybackBackend failed) {
                          if (pending == failed) {
                            pending = null;
                            failed.release();
                            loading = false;
                            message =
                                "This song or SoundFont could not be played. The reservation"
                                    + " remains in Up Next.";
                          } else if (player == failed) {
                            releaseCurrent();
                            message = "Playback stopped because the media could not be decoded.";
                          } else {
                            failed.release();
                            return;
                          }
                          publish();
                        }
                      };
                  try {
                    pending =
                        midi == null
                            ? new FileAudioPlayback(file, callbacks)
                            : new SoundFontPlayback(bank, midi, callbacks);
                  } catch (Exception | LinkageError e) {
                    loading = false;
                    message = "Could not prepare this song. Your reservation remains in Up Next.";
                    publish();
                  }
                });
          } catch (Exception e) {
            main.post(
                () -> {
                  if (token != generation) return;
                  loading = false;
                  message = "This music file is unreadable or exceeds supported MIDI limits.";
                  publish();
                });
          }
        });
  }

  void setVolume(float value) {
    if (!Float.isFinite(value)) return;
    volume = Math.max(0, Math.min(1, value));
    try {
      if (player != null) player.controls(volume, tempo, pitch);
    } catch (Exception e) {
      message = "Could not apply volume";
    }
  }

  void controls(float volume, float tempo, int pitch) {
    if (!Float.isFinite(volume) || !Float.isFinite(tempo)) return;
    this.volume = Math.min(1, Math.max(0, volume));
    this.tempo = Math.min(2, Math.max(0.5f, tempo));
    this.pitch = Math.min(12, Math.max(-12, pitch));
    try {
      if (player != null) player.controls(this.volume, this.tempo, this.pitch);
    } catch (Exception e) {
      message = "This audio decoder cannot apply that playback setting.";
    }
    publish();
  }

  private void nextIfReserved() {
    if (queue.peek() != null) next();
    else {
      message = "Set finished. Save your played songs in My Set.";
      audio.abandonAudioFocusRequest(focus);
      publish();
    }
  }

  void toggle() {
    if (loading) return;
    if (player == null) {
      next();
      return;
    }
    if (playing) pause();
    else if (audio.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
      try {
        player.start();
      } catch (IllegalStateException e) {
        message = "Please choose Next to reopen this song";
        publish();
      }
    }
  }

  void pause() {
    if (loading || pending != null) {
      ++generation; // Also retire work still parsing on IO, before a player exists.
      if (pending != null) pending.release();
      pending = null;
      loading = false;
      publish();
    }
    if (player != null && playing) {
      try {
        player.pause();
      } catch (IllegalStateException ignored) {
      }
      playing = false;
      publish();
    }
  }

  void stop() {
    ++generation;
    if (pending != null) {
      pending.release();
      pending = null;
    }
    loading = false;
    releaseCurrent();
    current = null;
    lyrics = Collections.emptyList();
    audio.abandonAudioFocusRequest(focus);
    publish();
  }

  private void releaseCurrent() {
    if (player != null) {
      player.release();
      player = null;
    }
    playing = false;
  }

  long position() {
    try {
      return player == null ? 0 : player.position();
    } catch (IllegalStateException e) {
      return 0;
    }
  }

  void importSongs(List<Uri> files) {
    if (!ready || importing) return;
    importCancelled.set(false);
    importing = true;
    message = "Importing your selected songs…";
    publish();
    io.execute(
        () -> {
          int good = 0, failed = 0;
          try {
            int[] counts = repository.importBatch(files, importCancelled::get);
            good = counts[0];
            failed = counts[1];
          } catch (Exception e) {
            failed = files.size();
          }
          List<Song> loaded = repository.songs();
          File bank = repository.soundFont();
          String bankLabel = repository.soundFontName();
          String result =
              "Imported "
                  + good
                  + " file(s)"
                  + (failed > 0
                      ? ". " + failed + " unsupported or unreadable file(s) were skipped."
                      : ".");
          main.post(
              () -> {
                songs = loaded;
                selectedSoundFont = bank;
                soundFontName = bankLabel;
                importing = false;
                message = result;
                publish();
              });
        });
  }

  void cancelImports() {
    importCancelled.set(true);
  }

  void importFolder(Uri tree) {
    if (!ready || importing) return;
    importing = true;
    importCancelled.set(false);
    message = "Finding music in your selected folder…";
    publish();
    folderWorker.execute(
        () -> {
          try {
            List<Uri> files =
                DocumentTreeScanner.scan(context.getContentResolver(), tree, importCancelled::get);
            main.post(
                () -> {
                  importing = false;
                  if (importCancelled.get()) {
                    message = "Folder import cancelled.";
                    publish();
                    return;
                  }
                  importSongs(files);
                });
          } catch (Exception e) {
            main.post(
                () -> {
                  importing = false;
                  message = "The folder is unavailable, cancelled or exceeds the scan limit.";
                  publish();
                });
          }
        });
  }

  void starter(String id, boolean enabled) {
    if (!ready) return;
    io.execute(
        () -> {
          try {
            repository.setStarter(id, enabled);
            List<Song> loaded = repository.songs();
            main.post(
                () -> {
                  songs = loaded;
                  message = enabled ? "Starter song restored" : "Starter song removed from My Set";
                  publish();
                });
          } catch (Exception e) {
            main.post(
                () -> {
                  message = "Could not change starter song";
                  publish();
                });
          }
        });
  }

  void saveSet(String name, List<Song> values) {
    if (!ready || savingSet) return;
    savingSet = true;
    List<Song> captured = new ArrayList<>(values);
    io.execute(
        () -> {
          try {
            repository.saveSet(name, captured);
            List<LibraryRepository.SavedSet> sets = repository.sets();
            main.post(
                () -> {
                  savingSet = false;
                  savedSets = sets;
                  message = "Saved your set";
                  publish();
                });
          } catch (Exception e) {
            main.post(
                () -> {
                  savingSet = false;
                  message = "Could not save the set. Use a name under 120 characters.";
                  publish();
                });
          }
        });
  }

  void scene(String name) {
    scenicName = name;
    io.execute(
        () -> {
          try {
            android.graphics.BitmapFactory.Options options =
                new android.graphics.BitmapFactory.Options();
            options.inJustDecodeBounds = true;
            try (InputStream in = context.getAssets().open("scenic/" + name + ".png")) {
              android.graphics.BitmapFactory.decodeStream(in, null, options);
            }
            options.inSampleSize = 1;
            while (options.outWidth / options.inSampleSize > 1600
                || options.outHeight / options.inSampleSize > 1600) options.inSampleSize *= 2;
            options.inJustDecodeBounds = false;
            android.graphics.Bitmap bitmap;
            try (InputStream in = context.getAssets().open("scenic/" + name + ".png")) {
              bitmap = android.graphics.BitmapFactory.decodeStream(in, null, options);
            }
            main.post(
                () -> {
                  if (scenicName.equals(name)) {
                    scenic = bitmap;
                    publish();
                  }
                });
          } catch (IOException e) {
            main.post(
                () -> {
                  message = "Could not open scenic background";
                  publish();
                });
          }
        });
  }

  void loadSet(LibraryRepository.SavedSet set) {
    Map<String, Song> catalog = new HashMap<>();
    for (Song s : songs) catalog.put(s.id, s);
    int added = 0;
    for (String id : set.songs) {
      Song song = catalog.get(id);
      if (song != null && queue.snapshot().size() < 1000) {
        queue.reserve(UUID.randomUUID(), song, "");
        added++;
      }
    }
    message = "Added " + added + " available song(s) to Up Next";
    saveQueue();
    publish();
  }
}
