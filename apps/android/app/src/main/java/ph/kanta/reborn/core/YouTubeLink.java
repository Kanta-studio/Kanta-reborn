package ph.kanta.reborn.core;

import java.net.URI;
import java.util.Locale;
import java.util.regex.Pattern;

/** Accepts an explicit YouTube video URL, discarding playlists and tracking parameters. */
public final class YouTubeLink {
  private static final Pattern VIDEO_ID = Pattern.compile("[A-Za-z0-9_-]{11}");

  private YouTubeLink() {}

  public static String canonical(String candidate) {
    if (candidate == null || candidate.length() > 2048) return null;
    final URI uri;
    try {
      uri = URI.create(candidate.trim());
    } catch (IllegalArgumentException invalid) {
      return null;
    }
    if (!"https".equalsIgnoreCase(uri.getScheme())
        || uri.isOpaque()
        || uri.getHost() == null
        || uri.getUserInfo() != null
        || uri.getPort() != -1
        || uri.getFragment() != null) return null;

    String host = uri.getHost().toLowerCase(Locale.ROOT);
    String path = uri.getRawPath();
    if (path == null || path.length() > 128) return null;

    String id = null;
    if (host.equals("youtu.be") || host.equals("www.youtu.be")) {
      if (path.startsWith("/")) id = path.substring(1);
    } else if (host.equals("youtube.com") || host.equals("www.youtube.com")
        || host.equals("m.youtube.com") || host.equals("music.youtube.com")
        || host.equals("youtube-nocookie.com") || host.equals("www.youtube-nocookie.com")) {
      if (path.equals("/watch")) {
        String query = uri.getRawQuery();
        if (query == null || query.length() > 2048) return null;
        for (String parameter : query.split("&", -1)) {
          if (!parameter.startsWith("v=")) continue;
          if (id != null) return null;
          id = parameter.substring(2);
        }
      } else {
        for (String prefix : new String[] {"/shorts/", "/live/", "/embed/"}) {
          if (path.startsWith(prefix)) {
            id = path.substring(prefix.length());
            break;
          }
        }
      }
    }
    if (id == null || !VIDEO_ID.matcher(id).matches()) return null;
    return "https://www.youtube.com/watch?v=" + id;
  }
}
