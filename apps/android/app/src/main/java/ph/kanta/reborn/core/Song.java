package ph.kanta.reborn.core;

import java.util.Locale;
import java.util.Objects;

public final class Song {
  public final String id, title, artist, code, fileName;
  public final boolean starter;
  private final String searchKey;

  public Song(
      String id, String title, String artist, String code, String fileName, boolean starter) {
    this.id = Objects.requireNonNull(id);
    this.title = Objects.requireNonNull(title);
    this.artist = artist == null ? "" : artist;
    this.code = code == null ? "" : code;
    if (!fileName.matches("[A-Za-z0-9_.-]+") || fileName.contains(".."))
      throw new IllegalArgumentException("Unsafe media name");
    this.fileName = fileName;
    this.starter = starter;
    this.searchKey = normalize(this.code + " " + this.title + " " + this.artist);
  }

  private static String normalize(String value) {
    return java.text.Normalizer.normalize(value, java.text.Normalizer.Form.NFD)
        .replaceAll("\\p{M}+", "")
        .toLowerCase(Locale.ROOT);
  }

  public static String[] searchTerms(String query) {
    return normalize(query).trim().split("\\s+");
  }

  public boolean matchesTerms(String[] terms) {
    for (String term : terms) if (!searchKey.contains(term)) return false;
    return true;
  }

  public boolean matches(String query) {
    return matchesTerms(searchTerms(query));
  }
}
