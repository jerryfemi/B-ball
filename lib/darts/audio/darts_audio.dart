import 'dart:async';

import '../../game/audio/audio_engine.dart';

/// Darts sound controller, played through the app's shared [AudioEngine].
///
/// Follows identical volume, mute, and soundtrack claiming patterns as
/// Archery and Basketball. Zero heap allocations during hot loops.
abstract final class DartsAudio {
  /// Darts background soundtrack loop. Uses archery plum blossom until a
  /// dedicated darts pub soundtrack is provided.
  static const String musicTrack = 'assets/music/short/archery_plum_blossom.mp3';

  /// Background ambient loop (e.g. pub chatter). Empty string for silence until
  /// dedicated pub ambience is supplied.
  static const String ambienceTrack = '';

  /// Claims soundtrack and pre-decodes darts SFX assets.
  static void init(Object owner) {
    AudioEngine.claimSoundtrack(
      owner,
      track: musicTrack,
      ambience: ambienceTrack.isEmpty ? null : ambienceTrack,
    );
    unawaited(AudioEngine.init().then((_) => AudioEngine.loadDartsSfx()));
  }

  /// Releases soundtrack ownership when leaving darts.
  static void leave(Object owner) => AudioEngine.releaseSoundtrack(owner);

  /// Unlocks audio on mobile browsers on user interaction.
  static void unlock() => AudioEngine.unlockAudio();

  /// Dart flick release whoosh.
  static void playThrow() => AudioEngine.playDartThrow();

  /// Dart landed on the board (sisal thunk). Triggers celebratory bell on bullseye.
  static void playHit({required bool isBull}) =>
      AudioEngine.playDartHit(isBull: isBull);

  /// Dart landed off the board / miss (wall thud).
  static void playMiss() => AudioEngine.playDartMiss();

  /// Bust condition penalty buzzer.
  static void playBust() => AudioEngine.playDartBust();

  /// Dart removal click when clearing darts from the board.
  static void playPull() => AudioEngine.playDartPull();
}
