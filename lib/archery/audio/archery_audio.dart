import 'archery_audio_native.dart'
    if (dart.library.js_interop) 'archery_audio_web.dart' as impl;

/// Dedicated Audio Engine for the Archery prototype.
///
/// Fully decoupled from basketball `Sfx` enums and audio classes.
/// Features zero-allocation audio triggers and physical sound travel distance delay (D / 340s).
abstract final class ArcheryAudio {
  static final impl.ArcheryAudioImpl _backend = impl.createAudioImpl();

  static void init() {
    _backend.init();
  }

  static void unlock() {
    _backend.unlock();
  }

  static void playDrawCreak() {
    _backend.playDrawCreak();
  }

  static void playFullDrawClick() {
    _backend.playFullDrawClick();
  }

  static void playReleaseTwang() {
    _backend.playReleaseTwang();
  }

  static void playImpact({
    required double distance,
    required bool isX,
    required bool hitBoss,
    required bool hitGround,
  }) {
    _backend.playImpact(
      distance: distance,
      isX: isX,
      hitBoss: hitBoss,
      hitGround: hitGround,
    );
  }

  static void dispose() {
    _backend.dispose();
  }
}
