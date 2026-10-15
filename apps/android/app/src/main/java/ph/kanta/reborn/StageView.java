package ph.kanta.reborn;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.text.*;
import android.text.style.ForegroundColorSpan;
import android.view.*;
import java.util.*;
import ph.kanta.reborn.core.*;

/** Renders controller state without owning transport or timing. */
final class StageView extends View {
  private final SessionController session;
  private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
  private String lastDescription = "";
  private final Rect source = new Rect();
  private final RectF target = new RectF();
  private final TextPaint lyricPaint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
  private StaticLayout currentLayout, nextLayout;
  private String cachedCurrent = "", cachedNext = "";
  private int cachedHighlight = -1, cachedWidth = -1;
  private float cachedSize;
  private final float[] stars = new float[192];

  StageView(Context context, SessionController session) {
    super(context);
    this.session = session;
    setMinimumHeight(dp(220));
    Random random = new Random(0x4b414e54);
    for (int i = 0; i < stars.length; i++) stars[i] = random.nextFloat();
    lyricPaint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
    lyricPaint.setShadowLayer(dp(2), 0, dp(2), Color.BLACK);
    setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);
  }

  private int dp(int v) {
    return (int) (v * getResources().getDisplayMetrics().density);
  }

  void refresh() {
    int i = MidiLyrics.activeIndex(session.lyrics, session.position());
    String description =
        ((session.current == null ? "KANTA stage" : session.current.title)
            + ". "
            + (i >= 0 ? session.lyrics.get(i).line : ""));
    if (!description.equals(lastDescription)) {
      setContentDescription(description);
      lastDescription = description;
    }
    invalidate();
  }

  @Override
  protected void onDraw(Canvas canvas) {
    super.onDraw(canvas);
    float w = getWidth(), h = getHeight();
    canvas.drawColor(Color.rgb(13, 18, 42));
    Bitmap scene = session.scenic;
    if (scene != null && !scene.isRecycled()) {
      float scale = Math.max(w / scene.getWidth(), h / scene.getHeight());
      float sw = w / scale, sh = h / scale;
      source.set(
          (int) ((scene.getWidth() - sw) / 2),
          (int) ((scene.getHeight() - sh) / 2),
          (int) ((scene.getWidth() + sw) / 2),
          (int) ((scene.getHeight() + sh) / 2));
      target.set(0, 0, w, h);
      paint.setAlpha(255);
      canvas.drawBitmap(scene, source, target, paint);
      paint.setColor(0x88000000);
      canvas.drawRect(0, 0, w, h, paint);
    }
    if (session.realm) realm(canvas, w, h);
    paint.setTextAlign(Paint.Align.CENTER);
    paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
    int index = MidiLyrics.activeIndex(session.lyrics, session.position());
    float font = Math.min(dp(48), Math.max(dp(20), w / 18)) * session.lyricScale;
    String current =
        session.current == null
            ? "Your music. Your stage."
            : index < 0
                ? (session.lyrics.isEmpty() ? session.current.title : "Get ready to sing…")
                : session.lyrics.get(index).line;
    int highlighted =
        index < 0 ? 0 : session.lyrics.get(index).highlightedCharacters(session.position());
    String next = index + 1 < session.lyrics.size() ? session.lyrics.get(index + 1).line : "";
    int width = Math.max(1, (int) w - dp(32));
    if (!current.equals(cachedCurrent)
        || !next.equals(cachedNext)
        || highlighted != cachedHighlight
        || width != cachedWidth
        || font != cachedSize) {
      cachedCurrent = current;
      cachedNext = next;
      cachedHighlight = highlighted;
      cachedWidth = width;
      cachedSize = font;
      SpannableString colored = new SpannableString(current);
      if (highlighted > 0)
        colored.setSpan(
            new ForegroundColorSpan(0xFFF6CE77),
            0,
            Math.min(highlighted, current.length()),
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
      currentLayout = layout(colored, width, font, Color.WHITE);
      nextLayout = layout(next, width, font * .7f, 0xFFB9D8E8);
    }
    drawLayout(canvas, currentLayout, w / 2, h * .46f);
    if (!next.isEmpty()) drawLayout(canvas, nextLayout, w / 2, h * .70f);
    if (session.current == null)
      line(
          canvas,
          "Reserve your next song in CONTROL",
          w / 2,
          h * 0.68f,
          w - dp(40),
          font * 0.6f,
          0xFFB9D8E8);
    paint.setTextSize(dp(11));
    paint.setTextAlign(Paint.Align.RIGHT);
    paint.setColor(0xBFF6CE77);
    canvas.drawText("KANTA", w - dp(14), h - dp(14), paint);
  }

  private StaticLayout layout(CharSequence text, int width, float size, int color) {
    TextPaint style = new TextPaint(lyricPaint);
    style.setTextSize(size);
    style.setColor(color);
    return StaticLayout.Builder.obtain(text, 0, text.length(), style, width)
        .setAlignment(Layout.Alignment.ALIGN_CENTER)
        .setIncludePad(false)
        .setMaxLines(2)
        .setEllipsize(TextUtils.TruncateAt.END)
        .build();
  }

  private void drawLayout(Canvas canvas, StaticLayout layout, float x, float y) {
    if (layout == null) return;
    canvas.save();
    canvas.translate(x - layout.getWidth() / 2f, y - layout.getHeight() / 2f);
    layout.draw(canvas);
    canvas.restore();
  }

  private void realm(Canvas canvas, float width, float height) {
    double travel = (SystemClock.elapsedRealtime() % 60000) / 60000.0;
    paint.setColor(0x806FE5E8);
    for (int i = 0; i < stars.length; i += 3) {
      double z = .15 + ((stars[i + 2] + travel) % 1.0) * 2;
      float x = (float) (width / 2 + (stars[i] - .5) * width / z);
      float y = (float) (height / 2 + (stars[i + 1] - .5) * height / z);
      float radius = (float) Math.min(dp(4), dp(2) / z);
      if (x >= 0 && y >= 0 && x <= width && y <= height) canvas.drawCircle(x, y, radius, paint);
    }
  }

  private void line(
      Canvas canvas, String text, float x, float y, float maxWidth, float size, int color) {
    paint.setTextSize(size);
    paint.setColor(color);
    paint.setTextAlign(Paint.Align.CENTER);
    String[] words = text.split("\\s+");
    List<String> lines = new ArrayList<>();
    String line = "";
    for (String word : words) {
      String candidate = line.isEmpty() ? word : line + " " + word;
      if (paint.measureText(candidate) > maxWidth && !line.isEmpty()) {
        lines.add(line);
        line = word;
      } else line = candidate;
    }
    if (!line.isEmpty()) lines.add(line);
    int count = Math.min(2, lines.size());
    for (int i = 0; i < count; i++) {
      String value = lines.get(i);
      if (i == 1 && lines.size() > 2) value += "…";
      while (paint.measureText(value) > maxWidth && value.length() > 1)
        value = value.substring(0, value.length() - 1);
      canvas.drawText(value, x, y + (i - (count - 1) / 2f) * size * 1.2f, paint);
    }
  }
}
