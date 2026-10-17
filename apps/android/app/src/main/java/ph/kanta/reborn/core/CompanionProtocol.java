package ph.kanta.reborn.core;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;

/** KCP1: ephemeral high-entropy PSK authentication and direction-separated AES-GCM records. */
public final class CompanionProtocol {
  public static final int MAX_RECORD = 32768;
  private static final int MAGIC = 0x4b435031;
  private static final SecureRandom RANDOM = new SecureRandom();
  private CompanionProtocol() {}

  public static String newCode() {
    byte[] value = new byte[16];
    RANDOM.nextBytes(value);
    StringBuilder code = new StringBuilder(32);
    for (byte b : value) code.append(String.format(Locale.ROOT, "%02x", b & 255));
    return code.toString();
  }

  private static byte[] secret(String code) throws IOException {
    if (code == null || !code.matches("[a-fA-F0-9]{32}")) throw new IOException("Invalid pairing code");
    byte[] result = new byte[16];
    for (int i = 0; i < 16; i++) result[i] = (byte) Integer.parseInt(code.substring(2*i, 2*i+2), 16);
    return result;
  }

  private static byte[] mac(byte[] key, byte[] data) throws GeneralSecurityException {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(key, "HmacSHA256"));
    return mac.doFinal(data);
  }

  private static byte[] labeled(byte[] transcript, String label) {
    byte[] suffix = label.getBytes(StandardCharsets.US_ASCII);
    return ByteBuffer.allocate(transcript.length + suffix.length).put(transcript).put(suffix).array();
  }

  public static Channel handshake(InputStream input, OutputStream output, String code, boolean host)
      throws IOException {
    byte[] psk = secret(code);
    try {
      DataInputStream in = new DataInputStream(input);
      DataOutputStream out = new DataOutputStream(output);
      byte[] hostNonce = new byte[32], clientNonce = new byte[32];
      if (host) {
        RANDOM.nextBytes(hostNonce);
        out.writeInt(MAGIC); out.write(hostNonce); out.flush();
        in.readFully(clientNonce);
      } else {
        if (in.readInt() != MAGIC) throw new IOException("Unsupported companion protocol");
        in.readFully(hostNonce);
        RANDOM.nextBytes(clientNonce);
        out.write(clientNonce);
      }
      byte[] transcript = ByteBuffer.allocate(68).putInt(MAGIC).put(hostNonce).put(clientNonce).array();
      byte[] peerProof = new byte[32];
      if (host) {
        in.readFully(peerProof);
        if (!MessageDigest.isEqual(peerProof, mac(psk, labeled(transcript, "client-proof"))))
          throw new IOException("Pairing rejected");
        out.write(mac(psk, labeled(transcript, "host-proof"))); out.flush();
      } else {
        out.write(mac(psk, labeled(transcript, "client-proof"))); out.flush();
        in.readFully(peerProof);
        if (!MessageDigest.isEqual(peerProof, mac(psk, labeled(transcript, "host-proof"))))
          throw new IOException("Pairing rejected");
      }
      // HKDF-Extract and one-block HKDF-Expand; each direction has its own key.
      byte[] prk = mac(MessageDigest.getInstance("SHA-256").digest(transcript), psk);
      byte[] toHost = mac(prk, labeled(transcript, "client-to-host\u0001"));
      byte[] toClient = mac(prk, labeled(transcript, "host-to-client\u0001"));
      Arrays.fill(prk, (byte) 0);
      return new Channel(in, out, host ? toClient : toHost, host ? toHost : toClient, host);
    } catch (GeneralSecurityException e) {
      throw new IOException("Companion cryptography unavailable", e);
    } finally { Arrays.fill(psk, (byte) 0); }
  }

  public static final class Channel implements AutoCloseable {
    private final DataInputStream in;
    private final DataOutputStream out;
    private final byte[] sendKey, receiveKey;
    private final int sendDirection, receiveDirection;
    private long sent, received;
    private volatile boolean closed;
    private Channel(DataInputStream in, DataOutputStream out, byte[] send, byte[] receive, boolean host) {
      this.in = in; this.out = out; sendKey = send; receiveKey = receive;
      sendDirection = host ? 2 : 1; receiveDirection = host ? 1 : 2;
    }
    private byte[] crypt(int mode, byte[] key, int direction, long sequence, byte[] bytes)
        throws IOException {
      try {
        byte[] nonce = ByteBuffer.allocate(12).putInt(direction).putLong(sequence).array();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(mode, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, nonce));
        cipher.updateAAD(ByteBuffer.allocate(16).putInt(MAGIC).putInt(direction).putLong(sequence).array());
        return cipher.doFinal(bytes);
      } catch (GeneralSecurityException e) { close(); throw new IOException("Invalid authenticated record", e); }
    }
    public void send(byte[] plain) throws IOException {
      if (closed || plain == null || plain.length > MAX_RECORD - 16 || sent == Long.MAX_VALUE)
        throw new IOException("Companion record limit");
      byte[] encrypted = crypt(Cipher.ENCRYPT_MODE, sendKey, sendDirection, sent, plain);
      out.writeInt(encrypted.length); out.writeLong(sent++); out.write(encrypted); out.flush();
    }
    public byte[] receive() throws IOException {
      if (closed || received == Long.MAX_VALUE) throw new IOException("Companion closed");
      int size = in.readInt(); long sequence = in.readLong();
      if (size < 16 || size > MAX_RECORD || sequence != received) {
        close(); throw new IOException("Invalid companion record order or size");
      }
      byte[] encrypted = new byte[size]; in.readFully(encrypted);
      byte[] plain = crypt(Cipher.DECRYPT_MODE, receiveKey, receiveDirection, sequence, encrypted);
      received++;
      return plain;
    }
    @Override public void close() {
      closed = true;
      Arrays.fill(sendKey, (byte) 0); Arrays.fill(receiveKey, (byte) 0);
    }
  }

  /** No DNS, global addresses, wildcard binds or interface discovery is performed by the transport. */
  public static byte[] privateAddress(String text) throws IOException {
    if (text == null || !text.matches("[0-9]{1,3}(\\.[0-9]{1,3}){3}")) throw new IOException("Enter a local IPv4 address");
    String[] parts = text.split("\\."); byte[] bytes = new byte[4];
    for (int i=0; i<4; i++) {
      int n = Integer.parseInt(parts[i]);
      if (n > 255 || (parts[i].length() > 1 && parts[i].startsWith("0"))) throw new IOException("Invalid IPv4 address");
      bytes[i] = (byte)n;
    }
    int a = bytes[0]&255, b=bytes[1]&255;
    if (!(a==10 || (a==172 && b>=16 && b<=31) || (a==192 && b==168)))
      throw new IOException("Use a private Wi-Fi or Ethernet IPv4 address");
    return bytes;
  }

  /** Reject hostile nesting before handing authenticated peer metadata to a recursive JSON parser. */
  public static String jsonText(byte[] bytes) throws IOException {
    if(bytes.length>MAX_RECORD-16)throw new IOException("Response limit");
    int depth=0; boolean quoted=false, escaped=false;
    for(byte value:bytes){
      int c=value&255;
      if(quoted){
        if(escaped)escaped=false;
        else if(c=='\\')escaped=true;
        else if(c=='"')quoted=false;
      }else if(c=='"')quoted=true;
      else if(c=='{'||c=='['){if(++depth>8)throw new IOException("Response nesting limit");}
      else if(c=='}'||c==']'){if(--depth<0)throw new IOException("Invalid response structure");}
    }
    if(quoted||depth!=0)throw new IOException("Incomplete response structure");
    try{return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();}
    catch(java.nio.charset.CharacterCodingException e){throw new IOException("Invalid response text",e);}
  }

  public static final class Request {
    public final UUID id;
    public final String action, argument, singer;
    public Request(UUID id, String action, String argument, String singer) {
      this.id=Objects.requireNonNull(id); this.action=action; this.argument=argument; this.singer=singer;
    }
    public byte[] encode() throws IOException {
      if (!Arrays.asList("snapshot", "search", "reserve", "cancel", "play", "pause", "next").contains(action))
        throw new IOException("Unsupported command");
      if ("search".equals(action) && (argument == null || argument.trim().isEmpty()))
        throw new IOException("Empty search command");
      ByteArrayOutputStream bytes=new ByteArrayOutputStream(); DataOutputStream out=new DataOutputStream(bytes);
      out.writeLong(id.getMostSignificantBits()); out.writeLong(id.getLeastSignificantBits());
      field(out, action, 16); field(out, argument, 128); field(out, singer, 80);
      return bytes.toByteArray();
    }
    public static Request decode(byte[] bytes) throws IOException {
      if (bytes.length > 1024) throw new IOException("Oversized command");
      DataInputStream in=new DataInputStream(new ByteArrayInputStream(bytes));
      Request r=new Request(new UUID(in.readLong(),in.readLong()),field(in,16),field(in,128),field(in,80));
      if (in.available()!=0) throw new IOException("Trailing command data");
      r.encode(); return r;
    }
  }
  private static void field(DataOutputStream out,String s,int max) throws IOException {
    if(s==null || s.length()>max) throw new IOException("Command field limit");
    byte[] bytes=s.getBytes(StandardCharsets.UTF_8);
    if(bytes.length>max*4) throw new IOException("Command field limit");
    out.writeShort(bytes.length);out.write(bytes);
  }
  private static String field(DataInputStream in,int max) throws IOException {
    int size=in.readUnsignedShort();if(size>max*4)throw new IOException("Command field limit");
    byte[] bytes=new byte[size];in.readFully(bytes);
    try {
      String s=StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();
      if(s.length()>max)throw new IOException("Command field limit");return s;
    }catch(java.nio.charset.CharacterCodingException e){throw new IOException("Invalid command text",e);}
  }

  /** Never evict a command and then execute it again; pair again when the bounded session is full. */
  public static final class Replay {
    private final Map<UUID, byte[]> replies=new HashMap<>();
    public byte[] get(UUID id) { byte[] r=replies.get(id);return r==null?null:r.clone(); }
    public void remember(UUID id, byte[] response) throws IOException {
      if(replies.containsKey(id))throw new IOException("Duplicate completion");
      if(replies.size()>=512)throw new IOException("Pair again to continue");
      if(response.length>MAX_RECORD-16)throw new IOException("Response limit");
      replies.put(id,response.clone());
    }
    public boolean full(){return replies.size()>=512;}
  }
}
