package ph.kanta.reborn;

import android.content.*;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.AtomicFile;
import java.io.*;
import java.security.*;
import java.util.*;
import org.json.*;
import ph.kanta.reborn.core.*;

/** Called on one IO executor. Only app-private copies and metadata are mutable. */
final class LibraryRepository {
  static final String[] STARTERS = {"morning-light", "sing-together", "starlight-echo"};
  static final String[] TITLES = {"Morning Light", "Sing Together", "Starlight Echo"};

  static final class SavedSet {
    final String id, name;
    final List<String> songs;

    SavedSet(String id, String name, List<String> songs) {
      this.id = id;
      this.name = name;
      this.songs = Collections.unmodifiableList(new ArrayList<>(songs));
    }
  }

  final File media;
  private final Context context;
  private final AtomicFile state;
  private final ArrayList<Song> songs = new ArrayList<>();
  private final ArrayList<SavedSet> sets = new ArrayList<>();
  private final Set<String> removed = new HashSet<>();
  private List<ReservationQueue.Entry> queue = new ArrayList<>();

  LibraryRepository(Context context) throws IOException {
    this.context = context;
    media = new File(context.getFilesDir(), "media");
    if (!media.isDirectory() && !media.mkdirs()) throw new IOException("Cannot open music storage");
    state = new AtomicFile(new File(context.getFilesDir(), "library-v1.json"));
  }

  void load() throws Exception {
    if (state.getBaseFile().exists() || new File(state.getBaseFile().getPath() + ".bak").exists()) {
      if (Math.max(
              state.getBaseFile().length(),
              new File(state.getBaseFile().getPath() + ".bak").length())
          > 16 * 1024 * 1024) throw new IOException("Saved library is too large");
      JSONObject root =
          new JSONObject(new String(state.readFully(), java.nio.charset.StandardCharsets.UTF_8));
      if (root.getInt("version") != 1) throw new IOException("Unsupported library version");
      JSONArray rows = root.getJSONArray("songs");
      if (rows.length() > 150000) throw new IOException("Too many library rows");
      Set<String> ids = new HashSet<>();
      for (int i = 0; i < rows.length(); i++) {
        JSONObject o = rows.getJSONObject(i);
        Song s =
            new Song(
                o.getString("id"),
                o.getString("title"),
                o.optString("artist"),
                o.optString("code"),
                o.getString("file"),
                o.optBoolean("starter"));
        if (!ids.add(s.id)) throw new IOException("Duplicate song ID");
        songs.add(s);
      }
      JSONArray hidden = root.optJSONArray("removed");
      if (hidden != null)
        for (int i = 0; i < hidden.length(); i++) removed.add(hidden.getString(i));
      JSONArray collections = root.optJSONArray("sets");
      if (collections != null) {
        if (collections.length() > 1000) throw new IOException("Too many saved sets");
        for (int i = 0; i < collections.length(); i++) {
          JSONObject o = collections.getJSONObject(i);
          ArrayList<String> idsInSet = new ArrayList<>();
          JSONArray a = o.getJSONArray("songs");
          if (a.length() > 10000) throw new IOException("Saved set too large");
          for (int j = 0; j < a.length(); j++) idsInSet.add(a.getString(j));
          sets.add(new SavedSet(o.getString("id"), o.getString("name"), idsInSet));
        }
      }
      JSONArray reservations = root.optJSONArray("queue");
      if (reservations != null) {
        if (reservations.length() > 1000) throw new IOException("Queue too large");
        for (int i = 0; i < reservations.length(); i++) {
          JSONObject o = reservations.getJSONObject(i);
          Song s = find(o.getString("song"));
          if (s != null)
            queue.add(
                new ReservationQueue.Entry(
                    UUID.fromString(o.getString("id")), s, o.optString("singer")));
        }
      }
    }
    for (int i = 0; i < STARTERS.length; i++) {
      String id = "starter:" + STARTERS[i], file = STARTERS[i] + ".mid";
      File target = new File(media, file);
      if (!target.exists()) {
        File temp = File.createTempFile("starter-", ".tmp", media);
        try (InputStream in = context.getAssets().open("starter/" + STARTERS[i] + ".kar");
            FileOutputStream out = new FileOutputStream(temp)) {
          byte[] b = new byte[8192];
          int n;
          while ((n = in.read(b)) != -1) out.write(b, 0, n);
          out.getFD().sync();
        }
        if (!temp.renameTo(target)) {
          temp.delete();
          throw new IOException("Cannot install starter song");
        }
      }
      if (!removed.contains(id) && find(id) == null)
        songs.add(new Song(id, TITLES[i], "KANTA Originals", "S00" + (i + 1), file, true));
    }
    persist();
  }

  private Song find(String id) {
    for (Song s : songs) if (s.id.equals(id)) return s;
    return null;
  }

  List<Song> songs() {
    return Collections.unmodifiableList(new ArrayList<>(songs));
  }

  List<SavedSet> sets() {
    return Collections.unmodifiableList(new ArrayList<>(sets));
  }

  List<ReservationQueue.Entry> queue() {
    return new ArrayList<>(queue);
  }

  void saveQueue(List<ReservationQueue.Entry> next) throws Exception {
    List<ReservationQueue.Entry> old = queue;
    queue = new ArrayList<>(next);
    try {
      persist();
    } catch (Exception e) {
      queue = old;
      throw e;
    }
  }

  Song importSong(Uri uri) throws Exception {
    String name = "Imported song";
    try (Cursor c =
        context
            .getContentResolver()
            .query(uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
      if (c != null && c.moveToFirst() && !c.isNull(0)) name = c.getString(0);
    }
    if (songs.size() >= 150000) throw new IOException("Library capacity reached");
    String lower = name.toLowerCase(Locale.ROOT);
    String ext =
        lower.endsWith(".kar") || lower.endsWith(".mid") || lower.endsWith(".midi")
            ? "mid"
            : lower.endsWith(".mp3") ? "mp3" : lower.endsWith(".wav") ? "wav" : null;
    if (ext == null) throw new IOException("Choose MIDI, KAR, MP3 or WAV music");
    File temp = File.createTempFile("import-", ".tmp", media);
    boolean installed = false;
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      long total = 0;
      byte[] buffer = new byte[65536];
      try (InputStream input = context.getContentResolver().openInputStream(uri);
          FileOutputStream out = new FileOutputStream(temp)) {
        if (input == null) throw new IOException("Cannot open selected file");
        int count;
        while ((count = input.read(buffer)) != -1) {
          if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
          total += count;
          if (total > 512L * 1024 * 1024) throw new IOException("Music file exceeds 512 MB");
          digest.update(buffer, 0, count);
          out.write(buffer, 0, count);
        }
        out.getFD().sync();
      }
      if (total == 0) throw new IOException("Selected file is empty");
      byte[] signature = new byte[12];
      try (FileInputStream in = new FileInputStream(temp)) {
        if (in.read(signature) < 4) throw new IOException("Music file is incomplete");
      }
      if (ext.equals("mid")) {
        if (total > 16 * 1024 * 1024) throw new IOException("MIDI file exceeds 16 MB");
        MidiLyrics.parse(java.nio.file.Files.readAllBytes(temp.toPath()));
      } else if (ext.equals("wav")
          && !(new String(signature, 0, 4, java.nio.charset.StandardCharsets.US_ASCII)
                  .equals("RIFF")
              && new String(signature, 8, 4, java.nio.charset.StandardCharsets.US_ASCII)
                  .equals("WAVE"))) throw new IOException("Not a WAVE file");
      else if (ext.equals("mp3")
          && !(signature[0] == 'I' && signature[1] == 'D' && signature[2] == '3')
          && !((signature[0] & 255) == 255 && (signature[1] & 224) == 224))
        throw new IOException("Not a supported MP3 file");
      StringBuilder hex = new StringBuilder();
      for (byte b : digest.digest()) hex.append(String.format(Locale.ROOT, "%02x", b & 255));
      String id = hex.toString();
      Song existing = find(id);
      if (existing != null) return existing;
      File destination = new File(media, id + "." + ext);
      if (destination.exists())
        throw new IOException(
            "An unindexed music copy already exists; original files are untouched");
      if (!temp.renameTo(destination)) throw new IOException("Cannot save imported song");
      installed = true;
      String title = name.replaceFirst("\\.[^.]+$", "");
      Set<String> codes = new HashSet<>();
      for (Song existingSong : songs) codes.add(existingSong.code);
      int reference = 100000;
      while (codes.contains(String.valueOf(reference))) reference++;
      Song song = new Song(id, title, "", String.valueOf(reference), destination.getName(), false);
      songs.add(song);
      try {
        persist();
      } catch (Exception e) {
        songs.remove(song);
        destination.delete();
        throw e;
      }
      return song;
    } finally {
      if (!installed) temp.delete();
    }
  }

  void setStarter(String id, boolean enabled) throws Exception {
    int index = Arrays.asList(STARTERS).indexOf(id.replace("starter:", ""));
    if (index < 0) throw new IOException("Unknown starter song");
    ArrayList<Song> before = new ArrayList<>(songs);
    Set<String> previous = new HashSet<>(removed);
    if (enabled) {
      removed.remove(id);
      if (find(id) == null)
        songs.add(
            new Song(
                id,
                TITLES[index],
                "KANTA Originals",
                "S00" + (index + 1),
                STARTERS[index] + ".mid",
                true));
    } else {
      removed.add(id);
      songs.removeIf(s -> s.id.equals(id));
    }
    try {
      persist();
    } catch (Exception e) {
      songs.clear();
      songs.addAll(before);
      removed.clear();
      removed.addAll(previous);
      throw e;
    }
  }

  void saveSet(String name, List<Song> values) throws Exception {
    if (sets.size() >= 1000 || values.size() > 10000)
      throw new IOException("Saved-set limit reached");
    name = name.trim();
    if (name.isEmpty() || name.length() > 120)
      throw new IOException("Enter a set name under 120 characters");
    ArrayList<String> ids = new ArrayList<>();
    for (Song s : values) ids.add(s.id);
    SavedSet set = new SavedSet(UUID.randomUUID().toString(), name, ids);
    sets.add(set);
    try {
      persist();
    } catch (Exception e) {
      sets.remove(set);
      throw e;
    }
  }

  void deleteSet(String id) throws Exception {
    ArrayList<SavedSet> old = new ArrayList<>(sets);
    sets.removeIf(s -> s.id.equals(id));
    try {
      persist();
    } catch (Exception e) {
      sets.clear();
      sets.addAll(old);
      throw e;
    }
  }

  private void persist() throws Exception {
    JSONObject root = new JSONObject().put("version", 1);
    JSONArray rows = new JSONArray();
    for (Song s : songs)
      rows.put(
          new JSONObject()
              .put("id", s.id)
              .put("title", s.title)
              .put("artist", s.artist)
              .put("code", s.code)
              .put("file", s.fileName)
              .put("starter", s.starter));
    root.put("songs", rows);
    root.put("removed", new JSONArray(removed));
    JSONArray q = new JSONArray();
    for (ReservationQueue.Entry e : queue)
      q.put(
          new JSONObject()
              .put("id", e.id.toString())
              .put("song", e.song.id)
              .put("singer", e.singer));
    root.put("queue", q);
    JSONArray saved = new JSONArray();
    for (SavedSet s : sets)
      saved.put(
          new JSONObject()
              .put("id", s.id)
              .put("name", s.name)
              .put("songs", new JSONArray(s.songs)));
    root.put("sets", saved);
    FileOutputStream out = null;
    try {
      out = state.startWrite();
      byte[] encoded = root.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
      if (encoded.length > 16 * 1024 * 1024)
        throw new IOException("Library metadata capacity reached");
      out.write(encoded);
      state.finishWrite(out);
    } catch (Exception e) {
      if (out != null) state.failWrite(out);
      throw e;
    }
  }
}
