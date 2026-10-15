package ph.kanta.reborn.core;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;

public final class PrivateSongbook {
  public static final class Export {
    public final String accessCode, envelope;

    Export(String code, String envelope) {
      accessCode = code;
      this.envelope = envelope;
    }
  }

  private static String csvCell(String value) {
    String trimmed = value.trim();
    if (!trimmed.isEmpty() && "=+-@".indexOf(trimmed.charAt(0)) >= 0) value = "'" + value;
    return "\"" + value.replace("\"", "\"\"") + "\"";
  }

  public static String csv(List<Song> songs) {
    StringBuilder csv = new StringBuilder("KANTA Code,Song Title,Artist,Availability\r\n");
    for (Song s : songs)
      csv.append(csvCell(s.code))
          .append(',')
          .append(csvCell(s.title))
          .append(',')
          .append(csvCell(s.artist))
          .append(",\"Playable\"\r\n");
    return csv.toString();
  }

  public static Export seal(String csv) throws GeneralSecurityException {
    byte[] plain = csv.getBytes(StandardCharsets.UTF_8);
    if (plain.length == 0 || plain.length > 16 * 1024 * 1024)
      throw new IllegalArgumentException("Songbook too large");
    SecureRandom random = new SecureRandom();
    byte[] secret = new byte[16], nonce = new byte[12];
    random.nextBytes(secret);
    random.nextBytes(nonce);
    StringBuilder code = new StringBuilder();
    for (byte b : secret) code.append(String.format(Locale.ROOT, "%02X", b & 255));
    byte[] key =
        MessageDigest.getInstance("SHA-256")
            .digest(("KANTA-SONGBOOK-V1:" + code).getBytes(StandardCharsets.UTF_8));
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(
        Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, nonce));
    byte[] encrypted = cipher.doFinal(plain);
    byte[] combined = new byte[nonce.length + encrypted.length];
    System.arraycopy(nonce, 0, combined, 0, nonce.length);
    System.arraycopy(encrypted, 0, combined, nonce.length, encrypted.length);
    String payload = Base64.getEncoder().encodeToString(combined);
    return new Export(
        code.toString(),
        "{\"format\":\"kanta-private-songbook\",\"version\":1,\"payload\":\"" + payload + "\"}");
  }
}
