import 'audio_backend_native.dart'
    if (dart.library.js_interop) 'audio_backend_web.dart'
    as impl;

/// Pre-decoded sound effects. The first five are basketball's; the arrow*
/// ones are archery's and are only decoded when archery loads
/// ([AudioEngine.loadArcherySfx]).
enum Sfx {
  rim,
  backboard,
  swish,
  bounce,
  buzzer,
  arrowDraw,
  arrowFullDraw,
  arrowRelease,
  arrowThunk,
  arrowBell,
  arrowThud,
}

/// Low-level sound output used by [AudioEngine].
///
/// Two implementations, picked at compile time:
///  • Web: the browser's own audio. Sound effects are pre-decoded Web Audio
///    buffers; music is a decoded, looping Web Audio buffer. Both are mixed by
///    the browser on its dedicated audio thread, so game-frame hitches can't
///    make the music skip and audio work can't steal game-frame time.
///    (The old SoLoud WASM build mixed on the page's main thread.)
///  • Native (Android/iOS/desktop builds): SoLoud.
abstract class AudioBackend {
  /// Starts the engine (no asset loading). Fast; safe before a user gesture.
  Future<void> init();

  /// Decodes the sound effects into memory for instant playback.
  Future<void> loadSfx(Map<Sfx, String> assetKeys);

  /// Plays a decoded effect at [volume] (0..1, already fully scaled).
  /// Must be cheap and synchronous: it runs from physics callbacks.
  void playSfx(Sfx sfx, double volume);

  /// Points the music player at [assetKey]. On web this only sets the
  /// source (the browser streams it), so it must be called synchronously
  /// inside the unlocking tap together with [setMusicPlaying].
  Future<void> setMusicTrack(String assetKey);

  /// Plays or pauses the music. Remembered if the track is still loading.
  void setMusicPlaying(bool playing);

  /// Music volume, 0..1 (already fully scaled).
  void setMusicVolume(double volume);

  /// Stops the music and releases the track (nothing keeps downloading).
  void unloadMusic();

  /// Ambience loop (e.g. archery's birdsong), independent of the music.
  /// null stops it and frees the buffer.
  Future<void> setAmbienceTrack(String? assetKey);

  /// Plays or pauses the ambience. Remembered if it is still loading.
  void setAmbiencePlaying(bool playing);

  /// Ambience volume, 0..1 (already fully scaled).
  void setAmbienceVolume(double volume);

  /// Call from inside a user tap: lets mobile browsers start audio.
  void unlock();

  /// True once audio output is actually running (and the music, if wanted,
  /// is playing). Until then [unlock] keeps being retried on each tap —
  /// iPhones only accept the tap's *release*, not the first touch.
  bool get isUnlocked;

  void dispose();
}

AudioBackend createAudioBackend() => impl.createAudioBackend();
