package ph.kanta.reborn;

import android.app.*;
import android.content.*;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.hardware.display.DisplayManager;
import android.net.Uri;
import android.os.*;
import android.speech.RecognizerIntent;
import android.text.*;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import ph.kanta.reborn.core.*;

public final class MainActivity extends Activity {
  private static final int MUSIC = 10, VOICE = 11, EXPORT = 12, FOLDER = 13;
  private static final int NAVY = 0xFF0B1023,
      PANEL = 0xFF19213E,
      CYAN = 0xFF6FE5E8,
      GOLD = 0xFFF6CE77;
  private SessionController session;
  private LinearLayout root, body, results;
  private StageView stage, fullscreenStage, externalStage;
  private Dialog fullscreen;
  private Presentation presentation;
  private DisplayManager displays;
  private String tab = "Control", query = "", singer = "";
  private EditText queryInput;
  private int resultLimit = 50;
  private int queueLimit = 20;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private final ExecutorService searchWorker = Executors.newSingleThreadExecutor();
  private int searchGeneration = 0;
  private boolean preparingExport = false;
  private byte[] exportBytes;
  private String exportCode;
  private final Runnable tick =
      new Runnable() {
        public void run() {
          if (stage != null) stage.refresh();
          if (fullscreenStage != null) fullscreenStage.refresh();
          if (externalStage != null) externalStage.refresh();
          handler.postDelayed(this, 100);
        }
      };
  private final DisplayManager.DisplayListener displayListener =
      new DisplayManager.DisplayListener() {
        public void onDisplayAdded(int id) {
          refreshDisplay();
        }

        public void onDisplayChanged(int id) {
          refreshDisplay();
        }

        public void onDisplayRemoved(int id) {
          refreshDisplay();
        }
      };

  @Override
  public void onCreate(Bundle saved) {
    super.onCreate(saved);
    session = ((KantaApplication) getApplication()).session;
    if (saved != null) {
      tab = saved.getString("tab", "Control");
      query = saved.getString("query", "");
      singer = saved.getString("singer", "");
    }
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    displays = (DisplayManager) getSystemService(DISPLAY_SERVICE);
    if (session.scenic == null) session.scene(session.scenicName);
  }

  @Override
  protected void onStart() {
    super.onStart();
    session.hostVisible(true);
    session.listen(this::render);
    handler.post(tick);
    displays.registerDisplayListener(displayListener, handler);
    refreshDisplay();
  }

  @Override
  protected void onStop() {
    handler.removeCallbacksAndMessages(null);
    displays.unregisterDisplayListener(displayListener);
    session.listen(null);
    session.hostVisible(false);
    if (!isChangingConfigurations()) session.pause();
    if (presentation != null) presentation.dismiss();
    presentation = null;
    externalStage = null;
    super.onStop();
  }

  @Override
  protected void onDestroy() {
    searchGeneration++;
    searchWorker.shutdownNow();
    if (fullscreen != null) fullscreen.dismiss();
    super.onDestroy();
  }

  @Override
  protected void onSaveInstanceState(Bundle out) {
    super.onSaveInstanceState(out);
    out.putString("tab", tab);
    out.putString("query", query);
    out.putString("singer", singer);
  }

  private int dp(int n) {
    return (int) (n * getResources().getDisplayMetrics().density);
  }

  private TextView text(String label, int size, int color) {
    TextView v = new TextView(this);
    v.setText(label);
    v.setTextColor(color);
    v.setTextSize(size);
    v.setPadding(dp(6), dp(6), dp(6), dp(6));
    return v;
  }

  private LinearLayout column() {
    LinearLayout v = new LinearLayout(this);
    v.setOrientation(LinearLayout.VERTICAL);
    return v;
  }

  private LinearLayout row() {
    LinearLayout v = new LinearLayout(this);
    v.setOrientation(LinearLayout.HORIZONTAL);
    v.setGravity(Gravity.CENTER_VERTICAL);
    return v;
  }

  private Button button(String label, Runnable action) {
    Button b = new Button(this);
    b.setText(label);
    b.setAllCaps(false);
    b.setTextColor(Color.WHITE);
    b.setTextSize(14);
    b.setMinHeight(dp(48));
    b.setBackgroundTintList(ColorStateList.valueOf(PANEL));
    b.setOnClickListener(v -> action.run());
    return b;
  }

  private void addWeighted(LinearLayout row, View view) {
    row.addView(view, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
  }

  private void render() {
    if (isFinishing() || isDestroyed()) return;
    searchGeneration++;
    queryInput = null;
    results = null;
    root = column();
    root.setBackgroundColor(NAVY);
    root.setPadding(dp(12), 0, dp(12), 0);
    root.setOnApplyWindowInsetsListener(
        (v, insets) -> {
          v.setPadding(
              dp(12),
              insets.getSystemWindowInsetTop(),
              dp(12),
              insets.getSystemWindowInsetBottom());
          return insets.consumeSystemWindowInsets();
        });
    setContentView(root);
    root.requestApplyInsets();
    LinearLayout header = row();
    TextView brand = text("KANTA · ᜃᜈ᜔ᜆ", 22, GOLD);
    brand.setTypeface(null, android.graphics.Typeface.BOLD);
    header.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));
    header.addView(button("Help", this::help));
    root.addView(header);
    LinearLayout main = new LinearLayout(this);
    boolean wide = getResources().getConfiguration().screenWidthDp >= 700;
    main.setOrientation(wide ? LinearLayout.HORIZONTAL : LinearLayout.VERTICAL);
    root.addView(main, new LinearLayout.LayoutParams(-1, 0, 1));
    LinearLayout stagePane = column();
    stage = new StageView(this, session);
    stage.setOnClickListener(v -> fullscreen());
    stage.setContentDescription("Karaoke stage. Double tap to open fullscreen.");
    stagePane.addView(stage, new LinearLayout.LayoutParams(-1, 0, 1));
    TextView now =
        text(
            session.current == null
                ? "Ready for your next song"
                : session.current.title + (session.singer.isEmpty() ? "" : " · " + session.singer),
            15,
            Color.WHITE);
    stagePane.addView(now);
    LinearLayout transport = row();
    Button play = button(session.playing ? "Pause" : "Play", session::toggle);
    play.setEnabled(session.ready && !session.loading);
    addWeighted(transport, play);
    Button next = button("Next", session::next);
    next.setEnabled(session.ready && !session.loading);
    addWeighted(transport, next);
    addWeighted(transport, button("Fullscreen", this::fullscreen));
    stagePane.addView(transport);
    if (wide) main.addView(stagePane, new LinearLayout.LayoutParams(0, -1, 1.2f));
    else
      main.addView(
          stagePane,
          new LinearLayout.LayoutParams(
              -1, dp(getResources().getConfiguration().orientation == 2 ? 200 : 300)));
    ScrollView scroll = new ScrollView(this);
    scroll.setFillViewport(true);
    body = column();
    body.setPadding(dp(4), 0, dp(4), dp(14));
    scroll.addView(body);
    if (wide) main.addView(scroll, new LinearLayout.LayoutParams(0, -1, 1));
    else main.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
    body.addView(text(session.message, 13, CYAN));
    switch (tab) {
      case "My Set":
        mySet();
        break;
      case "Scenic":
        scenic();
        break;
      case "Loop":
        loop();
        break;
      case "Realm":
        realm();
        break;
      default:
        control();
    }
    HorizontalScrollView navigation = new HorizontalScrollView(this);
    navigation.setHorizontalScrollBarEnabled(false);
    LinearLayout tabs = row();
    for (String name : new String[] {"My Set", "Loop", "Scenic", "Realm", "Control"}) {
      Button b =
          button(
              name,
              () -> {
                tab = name;
                render();
              });
      if (name.equals(tab)) b.setTextColor(GOLD);
      tabs.addView(b);
    }
    navigation.addView(tabs);
    root.addView(navigation);
    stage.refresh();
  }

  private void control() {
    body.addView(text("Sound & pace", 18, GOLD));
    LinearLayout tuning = row();
    addWeighted(
        tuning,
        button("Key −", () -> session.controls(session.volume, session.tempo, session.pitch - 1)));
    addWeighted(
        tuning,
        button(
            "Key " + (session.pitch > 0 ? "+" : "") + session.pitch,
            () -> session.controls(session.volume, session.tempo, 0)));
    addWeighted(
        tuning,
        button("Key +", () -> session.controls(session.volume, session.tempo, session.pitch + 1)));
    body.addView(tuning);
    LinearLayout pace = row();
    addWeighted(
        pace,
        button(
            "Slower",
            () -> session.controls(session.volume, session.tempo - 0.05f, session.pitch)));
    addWeighted(
        pace,
        button(
            String.format(java.util.Locale.ROOT, "%.0f%%", session.tempo * 100),
            () -> session.controls(session.volume, 1, session.pitch)));
    addWeighted(
        pace,
        button(
            "Faster",
            () -> session.controls(session.volume, session.tempo + 0.05f, session.pitch)));
    body.addView(pace);
    SeekBar volume = new SeekBar(this);
    volume.setContentDescription("Music volume");
    volume.setMax(100);
    volume.setProgress(Math.round(session.volume * 100));
    volume.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onStartTrackingTouch(SeekBar b) {}

          public void onStopTrackingTouch(SeekBar b) {
            session.publish();
          }

          public void onProgressChanged(SeekBar b, int value, boolean user) {
            if (user) session.setVolume(value / 100f);
          }
        });
    body.addView(volume);
    body.addView(text("Find your next song", 20, Color.WHITE));
    queryInput = new EditText(this);
    queryInput.setSingleLine();
    queryInput.setTextColor(Color.WHITE);
    queryInput.setTextSize(18);
    queryInput.setHintTextColor(0xFFAFB8D0);
    queryInput.setHint("Song code, title or artist");
    queryInput.setText(query);
    body.addView(queryInput);
    queryInput.addTextChangedListener(
        new TextWatcher() {
          public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

          public void onTextChanged(CharSequence s, int start, int before, int count) {
            query = s.toString();
            resultLimit = 50;
            search();
          }

          public void afterTextChanged(Editable e) {}
        });
    EditText singerInput = new EditText(this);
    singerInput.setSingleLine();
    singerInput.setTextColor(Color.WHITE);
    singerInput.setHintTextColor(0xFFAFB8D0);
    singerInput.setHint("Singer name (optional)");
    singerInput.setText(singer);
    body.addView(singerInput);
    singerInput.addTextChangedListener(
        new TextWatcher() {
          public void beforeTextChanged(CharSequence s, int a, int c, int f) {}

          public void onTextChanged(CharSequence s, int a, int b, int c) {
            singer = s.toString();
          }

          public void afterTextChanged(Editable e) {}
        });
    LinearLayout tools = row();
    addWeighted(tools, button("Voice search", this::voiceSearch));
    addWeighted(
        tools,
        button(
            "Cancel",
            () -> {
              query = "";
              queryInput.setText("");
            }));
    body.addView(tools);
    for (String[] digits :
        new String[][] {{"1", "2", "3"}, {"4", "5", "6"}, {"7", "8", "9"}, {"RES", "0", "⌫"}}) {
      LinearLayout keys = row();
      for (String digit : digits)
        addWeighted(
            keys,
            button(
                digit,
                () -> {
                  if (digit.equals("RES")) {
                    List<Song> matches = new ArrayList<>();
                    for (Song s : session.songs) if (s.matches(query)) matches.add(s);
                    if (matches.size() == 1) session.reserve(matches.get(0), singer);
                    else
                      new AlertDialog.Builder(this)
                          .setMessage("Choose Reserve beside the song you want below.")
                          .setPositiveButton("OK", null)
                          .show();
                  } else if (digit.equals("⌫")) {
                    if (!query.isEmpty())
                      queryInput.setText(query.substring(0, query.length() - 1));
                  } else queryInput.setText(query + digit);
                }));
      body.addView(keys);
    }
    results = column();
    body.addView(results);
    search();
    queue();
  }

  private void search() {
    if (results == null) return;
    int token = ++searchGeneration;
    String requested = query;
    String[] terms = Song.searchTerms(requested);
    LinearLayout target = results;
    int limit = resultLimit;
    List<Song> catalog = session.songs;
    searchWorker.execute(
        () -> {
          ArrayList<Song> found = new ArrayList<>();
          int total = 0;
          for (Song s : catalog) {
            if (Thread.currentThread().isInterrupted()) return;
            if (s.matchesTerms(terms)) {
              total++;
              if (found.size() < limit) found.add(s);
            }
          }
          int count = total;
          handler.post(
              () -> {
                if (token != searchGeneration || target != results || isDestroyed()) return;
                target.removeAllViews();
                target.addView(text(count + " matching songs", 13, GOLD));
                for (Song s : found) {
                  LinearLayout item = row();
                  TextView name =
                      text(
                          (s.code.isEmpty() ? "" : s.code + " · ")
                              + s.title
                              + (s.artist.isEmpty() ? "" : "\n" + s.artist),
                          15,
                          Color.WHITE);
                  item.addView(name, new LinearLayout.LayoutParams(0, -2, 1));
                  item.addView(button("Reserve", () -> session.reserve(s, singer)));
                  target.addView(item);
                }
                if (count > found.size())
                  target.addView(
                      button(
                          "Show more songs",
                          () -> {
                            resultLimit = Math.min(resultLimit + 50, 150000);
                            search();
                          }));
              });
        });
  }

  private void queue() {
    body.addView(text("Up Next · " + session.queue.snapshot().size(), 20, GOLD));
    int n = 0;
    for (ReservationQueue.Entry e : session.queue.snapshot()) {
      if (n >= queueLimit) break;
      final int position = n++;
      LinearLayout item = row();
      item.addView(
          text(
              (position + 1) + ". " + e.song.title + (e.singer.isEmpty() ? "" : " · " + e.singer),
              15,
              Color.WHITE),
          new LinearLayout.LayoutParams(0, -2, 1));
      if (position > 0) item.addView(button("↑", () -> session.move(e.id, position - 1)));
      item.addView(button("Remove", () -> session.remove(e.id)));
      body.addView(item);
    }
    if (session.queue.snapshot().size() > queueLimit)
      body.addView(
          button(
              "Show more reservations",
              () -> {
                queueLimit += 20;
                render();
              }));
    if (n == 0) body.addView(text("Reserve a song, then choose Play to begin.", 14, 0xFFAFB8D0));
  }

  private void mySet() {
    body.addView(text("My Set", 22, Color.WHITE));
    Button importButton =
        button(
            session.importing ? "Importing…" : "Add music or SoundFont",
            () -> {
              Intent i =
                  new Intent(Intent.ACTION_OPEN_DOCUMENT)
                      .setType("*/*")
                      .addCategory(Intent.CATEGORY_OPENABLE)
                      .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
              startActivityForResult(i, MUSIC);
            });
    importButton.setEnabled(session.ready && !session.importing);
    body.addView(importButton);
    Button folder =
        button(
            "Import a music folder",
            () -> startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), FOLDER));
    folder.setEnabled(session.ready && !session.importing);
    body.addView(folder);
    if (session.importing) body.addView(button("Cancel import", session::cancelImports));
    body.addView(text("SoundFont: " + session.soundFontName, 14, CYAN));
    body.addView(
        text(
            "SoundFonts up to 32 MB. MIDI/KAR up to 16 MB and six hours. Original files stay"
                + " unchanged.",
            13,
            0xFFAFB8D0));

    body.addView(button("Save Up Next as a playlist", () -> nameSet(false)));
    body.addView(button("Save played songs as Favorites", () -> nameSet(true)));
    body.addView(button("Export private Songbook", () -> export(true)));
    body.addView(button("Export song list (CSV)", () -> export(false)));
    body.addView(text("Saved sets", 20, GOLD));
    for (LibraryRepository.SavedSet set : session.savedSets)
      body.addView(
          button(set.name + " · " + set.songs.size() + " songs", () -> session.loadSet(set)));
    body.addView(text("Original starter songs", 20, GOLD));
    for (int i = 0; i < LibraryRepository.STARTERS.length; i++) {
      final String id = "starter:" + LibraryRepository.STARTERS[i];
      boolean present = session.songs.stream().anyMatch(s -> s.id.equals(id));
      LinearLayout item = row();
      item.addView(
          text(LibraryRepository.TITLES[i], 15, Color.WHITE),
          new LinearLayout.LayoutParams(0, -2, 1));
      item.addView(button(present ? "Remove" : "Restore", () -> session.starter(id, !present)));
      body.addView(item);
    }
    body.addView(
        button(
            "TinySoundFont license",
            () -> policy("tinysoundfont-license.txt", "TinySoundFont · MIT")));
    body.addView(button("Privacy", () -> policy("privacy.txt", "Privacy")));
    body.addView(button("Music rights", () -> policy("legal.txt", "Music rights")));
  }

  private void nameSet(boolean played) {
    ArrayList<Song> songs = new ArrayList<>();
    if (played) songs.addAll(session.played);
    else for (ReservationQueue.Entry e : session.queue.snapshot()) songs.add(e.song);
    if (songs.isEmpty()) {
      new AlertDialog.Builder(this)
          .setMessage(
              played
                  ? "Finish a song first to save the songs you sang."
                  : "Reserve songs first to save a playlist.")
          .setPositiveButton("OK", null)
          .show();
      return;
    }
    EditText name = new EditText(this);
    name.setHint("Set name");
    new AlertDialog.Builder(this)
        .setTitle(played ? "Save Favorites" : "Save playlist")
        .setView(name)
        .setPositiveButton("Save", (d, w) -> session.saveSet(name.getText().toString(), songs))
        .setNegativeButton("Cancel", null)
        .show();
  }

  private void scenic() {
    body.addView(text("Choose your stage", 22, Color.WHITE));
    String[] names = {
      "bayanDawn",
      "bambooMist",
      "coralHaze",
      "deepLagoon",
      "emberSunset",
      "indigoHorizon",
      "mangoGlow",
      "moonlitBay",
      "orchidNight",
      "pearlSky"
    };
    for (String name : names) {
      String title = name.replaceAll("([a-z])([A-Z])", "$1 $2");
      body.addView(
          button((session.scenicName.equals(name) ? "✓ " : "") + title, () -> session.scene(name)));
    }
  }

  private void loop() {
    body.addView(text("Loop & party sounds", 22, GOLD));
    body.addView(
        text(
            "Choose an imported MP3/WAV for between-song music. It stops for karaoke and when you"
                + " leave the app. Party clips can be assigned from My Set (up to 8 MB / 30"
                + " seconds).",
            15,
            Color.WHITE));
    Song loopSong =
        session.songs.stream()
            .filter(song -> song.id.equals(session.loopSongId))
            .findFirst()
            .orElse(null);
    body.addView(
        button(
            loopSong == null ? "Choose between-song music" : "Music: " + loopSong.title,
            () -> chooseAudio("Between-song music", session::chooseIntermission)));
    Button enabled =
        button(
            session.loopEnabled ? "Turn off between-song music" : "Turn on between-song music",
            session::toggleIntermission);
    enabled.setEnabled(loopSong != null);
    body.addView(enabled);
    volumeControl(
        "Between-song volume",
        session.party.loopVolume,
        value -> session.partyVolumes(session.party.sfxVolume, value));
    volumeControl(
        "Party sound volume",
        session.party.sfxVolume,
        value -> session.partyVolumes(value, session.party.loopVolume));
    body.addView(text("Original synthesized party sounds", 18, GOLD));
    body.addView(button("Stop all party audio", session::stopParty));
    for (int i = 0; i < PartySounds.TITLES.size(); i++) {
      final int slot = i;
      LinearLayout row = row();
      Button trigger =
          button(
              PartySounds.TITLES.get(i) + (session.customPads[i].isEmpty() ? "" : " · custom"),
              () -> session.triggerPad(slot));
      trigger.setEnabled(session.party.ready(i));
      row.addView(trigger, new LinearLayout.LayoutParams(0, -2, 1));
      Button assign =
          button(
              "Assign clip",
              () ->
                  chooseAudio(PartySounds.TITLES.get(slot), song -> session.assignPad(slot, song)));
      assign.setEnabled(!session.assigningPad);
      row.addView(assign);
      if (!session.customPads[i].isEmpty())
        row.addView(button("Reset", () -> session.resetPad(slot)));
      body.addView(row);
    }
    queue();
  }

  private void chooseAudio(String title, java.util.function.Consumer<Song> selected) {
    List<Song> audio = new ArrayList<>();
    for (Song song : session.songs) if (SessionController.isAudio(song)) audio.add(song);
    if (audio.isEmpty()) {
      new AlertDialog.Builder(this)
          .setTitle(title)
          .setMessage("Add an MP3 or WAV in My Set first. Your originals stay unchanged.")
          .setPositiveButton("OK", null)
          .show();
      return;
    }
    String[] names = audio.stream().map(song -> song.title).toArray(String[]::new);
    new AlertDialog.Builder(this)
        .setTitle(title)
        .setItems(names, (dialog, index) -> selected.accept(audio.get(index)))
        .setNegativeButton("Cancel", null)
        .show();
  }

  private void volumeControl(
      String title, float initial, java.util.function.Consumer<Float> apply) {
    body.addView(text(title, 16, GOLD));
    SeekBar bar = new SeekBar(this);
    bar.setMax(100);
    bar.setProgress(Math.round(initial * 100));
    bar.setContentDescription(title);
    bar.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onProgressChanged(SeekBar seek, int progress, boolean user) {
            if (user) apply.accept(progress / 100f);
          }

          public void onStartTrackingTouch(SeekBar seek) {}

          public void onStopTrackingTouch(SeekBar seek) {}
        });
    body.addView(bar);
  }

  private void realm() {
    body.addView(text("Realm", 22, GOLD));
    body.addView(
        text(
            "Animated lights behind your lyrics. Turn this off for a still stage.",
            16,
            Color.WHITE));
    body.addView(
        button(
            session.realm ? "Turn off animated lights" : "Turn on animated lights",
            () -> {
              session.realm = !session.realm;
              session.publish();
            }));
    body.addView(text("Lyric size", 18, GOLD));
    SeekBar size = new SeekBar(this);
    size.setMax(75);
    size.setProgress(Math.round((session.lyricScale - .75f) * 100));
    size.setContentDescription("Lyric size");
    size.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onProgressChanged(SeekBar bar, int value, boolean user) {
            if (user) session.lyricSize(.75f + value / 100f);
          }

          public void onStartTrackingTouch(SeekBar bar) {}

          public void onStopTrackingTouch(SeekBar bar) {
            session.publish();
          }
        });
    body.addView(size);
  }

  private void fullscreen() {
    if (fullscreen != null && fullscreen.isShowing()) return;
    fullscreen = new Dialog(this, android.R.style.Theme_Material_NoActionBar_Fullscreen);
    LinearLayout content = column();
    content.setBackgroundColor(Color.BLACK);
    fullscreenStage = new StageView(this, session);
    content.addView(fullscreenStage, new LinearLayout.LayoutParams(-1, 0, 1));
    LinearLayout controls = row();
    addWeighted(controls, button("Play / Pause", session::toggle));
    addWeighted(controls, button("Next", session::next));
    addWeighted(controls, button("Close", () -> fullscreen.dismiss()));
    content.addView(controls);
    fullscreen.setContentView(content);
    fullscreen.setOnDismissListener(d -> fullscreenStage = null);
    fullscreen.show();
  }

  private void refreshDisplay() {
    if (presentation != null) {
      presentation.dismiss();
      presentation = null;
      externalStage = null;
    }
    for (Display display : displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)) {
      if (display.getDisplayId() == getWindowManager().getDefaultDisplay().getDisplayId()) continue;
      try {
        presentation = new Presentation(this, display);
        externalStage = new StageView(presentation.getContext(), session);
        presentation.setContentView(externalStage);
        presentation.show();
        break;
      } catch (WindowManager.InvalidDisplayException e) {
        presentation = null;
        externalStage = null;
      }
    }
  }

  private void voiceSearch() {
    new AlertDialog.Builder(this)
        .setTitle("Voice search")
        .setMessage(
            "Your device's speech provider may process your voice online. KANTA uses the result"
                + " only to search; it will not reserve a song automatically.")
        .setPositiveButton(
            "Continue",
            (d, w) -> {
              Intent i =
                  new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                      .putExtra(
                          RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                          RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                      .putExtra(RecognizerIntent.EXTRA_PROMPT, "Say a song title or artist");
              try {
                startActivityForResult(i, VOICE);
              } catch (ActivityNotFoundException e) {
                Toast.makeText(
                        this, "Voice search is not available on this device", Toast.LENGTH_LONG)
                    .show();
              }
            })
        .setNegativeButton("Cancel", null)
        .show();
  }

  private void export(boolean encrypted) {
    if (exportBytes != null || preparingExport) return;
    preparingExport = true;
    List<Song> captured = session.songs;
    session.io.execute(
        () -> {
          try {
            String csv = PrivateSongbook.csv(captured);
            PrivateSongbook.Export book = encrypted ? PrivateSongbook.seal(csv) : null;
            byte[] bytes =
                (encrypted ? book.envelope : csv).getBytes(java.nio.charset.StandardCharsets.UTF_8);
            handler.post(
                () -> {
                  preparingExport = false;
                  if (isDestroyed()) return;
                  exportBytes = bytes;
                  exportCode = encrypted ? book.accessCode : null;
                  Intent intent =
                      new Intent(Intent.ACTION_CREATE_DOCUMENT)
                          .addCategory(Intent.CATEGORY_OPENABLE)
                          .setType(encrypted ? "application/octet-stream" : "text/csv")
                          .putExtra(
                              Intent.EXTRA_TITLE,
                              encrypted ? "KANTA-My-Songbook.kanta-book" : "KANTA-My-Songbook.csv");
                  startActivityForResult(intent, EXPORT);
                });
          } catch (Exception e) {
            handler.post(
                () -> {
                  preparingExport = false;
                  if (!isDestroyed())
                    Toast.makeText(this, "Could not prepare your Songbook", Toast.LENGTH_LONG)
                        .show();
                });
          }
        });
  }

  @Override
  protected void onActivityResult(int request, int result, Intent data) {
    super.onActivityResult(request, result, data);
    if (result != RESULT_OK || data == null) {
      if (request == EXPORT) {
        exportBytes = null;
        exportCode = null;
      }
      return;
    }
    if (request == MUSIC) {
      List<Uri> uris = new ArrayList<>();
      if (data.getClipData() != null) {
        for (int i = 0; i < data.getClipData().getItemCount() && i < 1000; i++)
          uris.add(data.getClipData().getItemAt(i).getUri());
      } else if (data.getData() != null) uris.add(data.getData());
      session.importSongs(uris);
    } else if (request == FOLDER && data.getData() != null) {
      session.importFolder(data.getData());
    } else if (request == VOICE) {
      ArrayList<String> values = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
      if (values != null && !values.isEmpty()) {
        query = values.get(0);
        tab = "Control";
        render();
      }
    } else if (request == EXPORT) {
      Uri uri = data.getData();
      byte[] bytes = exportBytes;
      String code = exportCode;
      exportBytes = null;
      exportCode = null;
      if (uri == null || bytes == null) return;
      session.io.execute(
          () -> {
            try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
              if (out == null) throw new IOException();
              out.write(bytes);
              handler.post(
                  () -> {
                    if (isDestroyed()) return;
                    if (code != null)
                      new AlertDialog.Builder(this)
                          .setTitle("Keep this code separate from your file")
                          .setMessage(
                              code
                                  + "\n\n"
                                  + "Open the Songbook page on the KANTA website and choose your"
                                  + " saved file. Anyone with both the file and this code can read"
                                  + " the list.")
                          .setPositiveButton(
                              "Copy code",
                              (d, w) ->
                                  ((android.content.ClipboardManager)
                                          getSystemService(CLIPBOARD_SERVICE))
                                      .setPrimaryClip(
                                          ClipData.newPlainText("KANTA Songbook code", code)))
                          .setNegativeButton("Done", null)
                          .show();
                    else Toast.makeText(this, "Song list saved", Toast.LENGTH_LONG).show();
                  });
            } catch (Exception e) {
              handler.post(
                  () ->
                      Toast.makeText(this, "Could not save the export", Toast.LENGTH_LONG).show());
            }
          });
    }
  }

  private void policy(String asset, String title) {
    try (InputStream in = getAssets().open(asset)) {
      ByteArrayOutputStream bytes = new ByteArrayOutputStream();
      byte[] buffer = new byte[4096];
      int n;
      while ((n = in.read(buffer)) != -1) bytes.write(buffer, 0, n);
      TextView content = text(bytes.toString("UTF-8"), 15, Color.WHITE);
      ScrollView scroll = new ScrollView(this);
      scroll.addView(content);
      new AlertDialog.Builder(this)
          .setTitle(title)
          .setView(scroll)
          .setPositiveButton("Close", null)
          .show();
    } catch (IOException e) {
      Toast.makeText(this, "Policy could not be opened", Toast.LENGTH_LONG).show();
    }
  }

  private void help() {
    new AlertDialog.Builder(this)
        .setTitle("Your karaoke night")
        .setMessage(
            "1. Try the three original songs, or add your own MIDI, KAR, MP3 or WAV in My Set.\n\n"
                + "2. Find a song in Control and choose Reserve. Add a singer name if you like.\n\n"
                + "3. Choose Play. Next starts the next reservation. Tap the stage for"
                + " fullscreen.\n\n"
                + "4. Save playlists or the songs you finished in My Set.\n\n"
                + "This is a reconstruction preview. Custom SoundFonts, microphone effects, camera"
                + " stages and companion pairing are still being restored. They are not enabled in"
                + " this version. Use music you have permission to use.")
        .setPositiveButton("Done", null)
        .show();
  }
}
