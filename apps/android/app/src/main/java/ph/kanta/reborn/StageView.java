package ph.kanta.reborn;

import android.content.Context;
import android.graphics.*;
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

  StageView(Context context, SessionController session) {
    super(context);
    this.session = session;
    setMinimumHeight(dp(220));
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
    paint.setTextAlign(Paint.Align.CENTER);
    paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
    int index = MidiLyrics.activeIndex(session.lyrics, session.position());
    float font = Math.min(dp(34), Math.max(dp(19), w / 23));
    String current =
        session.current == null
            ? "Your music. Your stage."
            : index < 0
                ? (session.lyrics.isEmpty() ? session.current.title : "Get ready to sing…")
                : session.lyrics.get(index).line;
    line(canvas, current, w / 2, h * 0.48f, w - dp(40), font, Color.WHITE);
    if (index + 1 < session.lyrics.size())
      line(
          canvas,
          session.lyrics.get(index + 1).line,
          w / 2,
          h * 0.69f,
          w - dp(40),
          font * 0.7f,
          0xFFB9D8E8);
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
