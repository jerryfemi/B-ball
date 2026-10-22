import 'dart:async';

import '../../game/audio/audio_engine.dart';

/// Archery's sounds, played through the app's shared [AudioEngine]: same
/// mixer and the same app-wide mute, volume and SOUND EFFECTS / MUSIC
/// switches as basketball, but archery's own soundtrack ([musicTrack]).
/// This class only adds archery's timing rules.
abstract final class ArcheryAudio {
  /// Archery's own soundtrack (never basketball's). '' = no music yet; set it
  /// to e.g. 'assets/music/short/<track>.mp3' once the track is added.
  static const String musicTrack = '';

  /// Starts the shared engine (if needed) and decodes archery's sounds.
  static void init() {
    unawaited(AudioEngine.useGameSoundtrack(musicTrack));
    unawaited(AudioEngine.init().then((_) => AudioEngine.loadArcherySfx()));
  }

  /// Call when archery closes: hands the music back to basketball's playlist.
  static void leave() => unawaited(AudioEngine.useGameSoundtrack(null));

  /// Call from every pointer down/up: browsers only start audio (and the
  /// music) inside a tap, and iPhones only on the release.
  static void unlock() => AudioEngine.unlockAudio();

  static void playDrawCreak() => AudioEngine.playArrowDraw();

  static void playFullDrawClick() => AudioEngine.playArrowFullDraw();

  static void playReleaseTwang() => AudioEngine.playArrowRelease();

  /// Impact heard after the sound travels back from the target
  /// (~340 m/s: ≈45 ms at 50 ft, ≈135 ms at 150 ft). [distance] 0 = instant.
  static void playImpact({
    required double distance,
    required bool isX,
    required bool hitBoss,
    required bool hitGround,
  }) {
    void fire() => AudioEngine.playArrowImpact(hitTarget: hitBoss, bell: isX);
    final int delayMs = ((distance / 340.0) * 1000).round().clamp(0, 500);
    if (delayMs == 0) {
      fire();
    } else {
      Timer(Duration(milliseconds: delayMs), fire);
    }
  }
}
