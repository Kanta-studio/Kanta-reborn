package ph.kanta.reborn.core;

import java.net.URI;
import java.util.Locale;

/** Link-only video metadata. This type never represents a local playable file. */
public final class YouTubeVideoReference {
  public final String videoId;
  private YouTubeVideoReference(String id) { videoId=id; }
  public static YouTubeVideoReference parse(String text) {
    try {
      URI uri=new URI(text);
      if(!"https".equalsIgnoreCase(uri.getScheme()) || uri.getRawUserInfo()!=null ||
          uri.getPort()!=-1 || uri.getRawFragment()!=null)return null;
      String host=uri.getHost();
      if(host==null)return null;
      host=host.toLowerCase(Locale.ROOT);
      String path=uri.getRawPath();
      if(path==null || path.contains("%"))return null;
      String id=null;
      if(host.equals("youtu.be")) {
        if(uri.getRawQuery()!=null)return null;
        if(path.matches("/[A-Za-z0-9_-]{11}"))id=path.substring(1);
      } else if(host.equals("youtube.com")||host.equals("www.youtube.com")||host.equals("m.youtube.com")) {
        if(path.equals("/watch")) {
          String query=uri.getRawQuery();
          if(query==null)return null;
          for(String part:query.split("&",-1))if(part.startsWith("v=")){
            if(id!=null)return null;
            id=part.substring(2);
          }
        } else if(path.matches("/(embed|shorts)/[A-Za-z0-9_-]{11}"))
          id=path.substring(path.lastIndexOf('/')+1);
      } else return null;
      return id!=null&&id.matches("[A-Za-z0-9_-]{11}")?new YouTubeVideoReference(id):null;
    }catch(Exception ignored){return null;}
  }
}
