import 'dart:async';
import 'dart:math' as math;

import '../../game/audio/audio_engine.dart';

/// Darts sound controller, played through the app's shared [AudioEngine].
///
/// Follows identical volume, mute, and soundtrack claiming patterns as
/// Archery and Basketball. Zero heap allocations during hot loops.
abstract final class DartsAudio {
  /// Darts background soundtrack loop (first 90 s of the track, faded out
  /// at the end so the loop restarts cleanly).
  static const String musicTrack = 'assets/music/short/darts_theme.mp3';

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
  static void leave(Object owner) {
    cancelTicks();
    AudioEngine.releaseSoundtrack(owner);
  }

  /// Unlocks audio on mobile browsers on user interaction.
  static void unlock() => AudioEngine.unlockAudio();

  /// Dart flick release whoosh.
  static void playThrow() => AudioEngine.playDartThrow();

  /// Dart landed on the board (sisal thunk). Triggers celebratory bell on bullseye.
  static void playHit({required bool isBull}) =>
      AudioEngine.playDartHit(isBull: isBull);

  /// Dart landed off the board / miss (glass tap).
  static void playMiss() => AudioEngine.playDartMiss();

  // ─── Score count-up ("ting ting ting") ─────────────────────────────────────

  /// How many tings a score gets: 1–6 points tick that many times; anything
  /// bigger is a fixed quick burst of 8. Misses and bulls get none (the bull
  /// has its own chime).
  static int tickCountFor(int points) {
    if (points <= 0) return 0;
    if (points <= 6) return points;
    return 8;
  }

  /// Delay after the board hit before the first ting (seconds).
  static const double tickStartDelay = 0.16;

  /// Gap before ting [i + 1] (seconds); the tings speed up slightly.
  static double tickGap(int i) => 0.055 * math.pow(0.95, i) + 0.018;

  /// Playback speed of ting [i]: climbs up to half an octave.
  static double tickRate(int i) => math.pow(2.0, math.min(i, 12) / 24.0).toDouble();

  static final List<Timer> _tickTimers = <Timer>[];

  /// Plays the count-up tings for a dart worth [points].
  static void playScoreTicks(int points) {
    cancelTicks();
    final int n = tickCountFor(points);
    double at = tickStartDelay;
    for (int i = 0; i < n; i++) {
      final double rate = tickRate(i);
      _tickTimers.add(Timer(
        Duration(microseconds: (at * 1e6).round()),
        () => AudioEngine.playDartTick(rate: rate),
      ));
      at += tickGap(i);
    }
  }

  /// Stops any count-up still in progress.
  static void cancelTicks() {
    for (final t in _tickTimers) {
      t.cancel();
    }
    _tickTimers.clear();
  }

  /// Bust condition penalty buzzer.
  static void playBust() => AudioEngine.playDartBust();

  /// Dart removal click when clearing darts from the board.
  static void playPull() => AudioEngine.playDartPull();
}
