import ph.kanta.reborn.core.CompanionProtocol;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Synthetic Java peer using the unmodified production Android codec, never a user catalog. */
public final class CompanionInteropHost {
  private static final class FragmentingOutput extends FilterOutputStream {
    FragmentingOutput(OutputStream output) { super(output); }
    @Override public void write(byte[] bytes, int offset, int length) throws IOException {
      for (int i = 0; i < length; i++) out.write(bytes[offset + i]);
      out.flush();
    }
  }

  public static void main(String[] args) throws Exception {
    try (ServerSocket server = new ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))) {
      server.setSoTimeout(10000);
      System.out.println(server.getLocalPort()); System.out.flush();
      try (Socket socket = server.accept()) {
        socket.setSoTimeout(5000);
        try (CompanionProtocol.Channel channel = CompanionProtocol.handshake(
            socket.getInputStream(), new FragmentingOutput(socket.getOutputStream()), "000102030405060708090a0b0c0d0e0f", true)) {
          CompanionProtocol.Replay replay = new CompanionProtocol.Replay();
          List<UUID> reservations = new ArrayList<>();
          boolean playing = false;
          for (int count=0; count<16; count++) {
            CompanionProtocol.Request request;
            try { request = CompanionProtocol.Request.decode(channel.receive()); }
            catch (java.io.EOFException e) { return; }
            byte[] reply = replay.get(request.id);
            if (reply == null) {
              switch (request.action) {
                case "reserve":
                  if (!request.argument.equals("synthetic-song")) throw new Exception("Wrong song identity");
                  reservations.add(UUID.randomUUID()); break;
                case "cancel": reservations.remove(UUID.fromString(request.argument)); break;
                case "play": playing = true; break;
                case "pause": playing = false; break;
                case "next": if (!reservations.isEmpty()) reservations.remove(0); break;
                case "snapshot": case "search": break;
                default: throw new Exception("Unexpected action");
              }
              StringBuilder queue = new StringBuilder();
              for (UUID id : reservations) {
                if (queue.length()>0) queue.append(',');
                queue.append("{\"id\":\"").append(id).append("\",\"title\":\"Synthetic song\",\"singer\":\"Test\"}");
              }
              String songs = request.action.equals("search")
                  ? "{\"id\":\"synthetic-song\",\"title\":\"Bituin 🎤\",\"artist\":\"Test\",\"code\":\"001\"}" : "";
              String response = "{\"request\":\""+request.id+"\",\"current\":\"Synthetic song\",\"playing\":"+playing
                  +",\"songs\":["+songs+"],\"queue\":["+queue+"]}";
              reply = response.getBytes(StandardCharsets.UTF_8); replay.remember(request.id, reply);
            }
            channel.send(reply);
          }
        }
      }
    }
  }
}
