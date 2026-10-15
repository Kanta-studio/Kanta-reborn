package ph.kanta.reborn;

interface PlaybackBackend {
  interface Callback {
    void ready(PlaybackBackend player);

    void started(PlaybackBackend player);

    void completed(PlaybackBackend player);

    void failed(PlaybackBackend player);
  }

  void start();

  void pause();

  void release();

  long position();

  void controls(float volume, float tempo, int pitch);
}
