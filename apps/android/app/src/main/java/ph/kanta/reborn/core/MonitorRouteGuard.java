package ph.kanta.reborn.core;

/** A route loss retires this activation; a reconnect requires a new user action. */
public final class MonitorRouteGuard {
  public enum Decision {
    WAIT,
    ALLOW,
    STOP
  }

  private final int deviceId;
  private final long startedAt;
  private boolean verified, closed;

  public MonitorRouteGuard(int deviceId, long startedAt) {
    if (deviceId <= 0 || startedAt < 0) throw new IllegalArgumentException();
    this.deviceId = deviceId;
    this.startedAt = startedAt;
  }

  public synchronized Decision verify(int[] routedIds, long now) {
    if (closed) return Decision.STOP;
    long elapsed = now - startedAt;
    if (elapsed < 0 || (!verified && elapsed >= 1500)) return close();
    if (routedIds == null || routedIds.length == 0) {
      if (verified || elapsed >= 1500) return close();
      return Decision.WAIT;
    }
    if (routedIds.length != 1 || routedIds[0] != deviceId) return close();
    verified = true;
    return Decision.ALLOW;
  }

  public synchronized Decision close() {
    closed = true;
    return Decision.STOP;
  }
}
