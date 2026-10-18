package ph.kanta.reborn;

import android.content.Context;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import ph.kanta.reborn.core.YouTubeVideoReference;

/** Visible official embed; the session controller remains the only queue owner. */
final class YouTubeEmbeddedPlayer extends WebView {
  private String loadedId;

  YouTubeEmbeddedPlayer(Context context) {
    super(context);
    getSettings().setJavaScriptEnabled(true);
    getSettings().setMediaPlaybackRequiresUserGesture(true);
    getSettings().setDomStorageEnabled(false);
    getSettings().setAllowFileAccess(false);
    getSettings().setAllowContentAccess(false);
    setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view, String url) {
        return !isAllowed(url);
      }
      @Override public boolean shouldOverrideUrlLoading(WebView view, android.webkit.WebResourceRequest request) {
        return !isAllowed(request.getUrl().toString());
      }
    });
    setBackgroundColor(android.graphics.Color.BLACK);
  }

  private static boolean isAllowed(String raw) {
    try {
      android.net.Uri url=android.net.Uri.parse(raw);
      String host=url.getHost();
      return "https".equalsIgnoreCase(url.getScheme()) && host!=null &&
          (host.equalsIgnoreCase("www.youtube-nocookie.com") ||
           host.equalsIgnoreCase("youtube-nocookie.com") ||
           host.equalsIgnoreCase("www.youtube.com") ||
           host.equalsIgnoreCase("youtube.com"));
    } catch(Exception ignored) { return false; }
  }

  void show(YouTubeVideoReference reference) {
    if(reference.videoId.equals(loadedId))return;
    loadedId=reference.videoId;
    loadUrl("https://www.youtube-nocookie.com/embed/"+reference.videoId+"?playsinline=1");
  }

  void release() {
    stopLoading();
    loadUrl("about:blank");
    onPause();
    destroy();
    loadedId=null;
  }
}
