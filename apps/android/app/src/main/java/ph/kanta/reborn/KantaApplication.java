package ph.kanta.reborn;

import android.app.Application;

public final class KantaApplication extends Application {
  SessionController session;

  @Override
  public void onCreate() {
    super.onCreate();
    session = new SessionController(this);
  }
}
