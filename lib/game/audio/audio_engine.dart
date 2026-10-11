import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, and round-ending buzzers.
///
/// Performance architecture:
/// - **Pre-Warmed Player Pooling:** Fixed pools with [minPlayers] matching [maxPlayers]
///   are fully allocated upfront during [init], completely eliminating mid-gameplay
///   player creation and platform channel allocation churn.
/// - **Stopwatch Rate-Limiting:** A monotonic [Stopwatch] eliminates timing drift
///   and wall-clock shifts during the 240 Hz physics substep loop.
/// - **Velocity Gating:** Minimum impact speed thresholds prevent
///   trivially soft micro-collisions from ever reaching the audio pipeline.
class AudioEngine {
  static final ValueNotifier<bool> isMutedNotifier =
      ValueNotifier<bool>(false);
  static bool get isMuted => isMutedNotifier.value;
  static set isMuted(bool value) => isMutedNotifier.value = value;

  /// Toggles mute state and notifies all reactive UI listeners.
  static void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
  }

  static bool _initialized = false;

  // ── Monotonic stopwatch (zero-allocation rate-limiting) ──
  static final Stopwatch _clock = Stopwatch();
  static int _lastBounceUs = 0;
  static int _lastRimUs = 0;
  static int _lastBackboardUs = 0;

  // ── Pre-allocated audio player pools ──
  // Each pool maintains a fixed ring of AudioPlayer instances that are
  // reused across playback calls, avoiding the create-per-play overhead
  // of FlameAudio.play() which allocates native platform resources each time.
  static AudioPool? _rimPool;
  static AudioPool? _backboardPool;
  static AudioPool? _swishPool;
  static AudioPool? _bouncePool;
  static AudioPool? _buzzerPool;

  // ── Minimum impact velocity thresholds (m/s) ──
  // Impacts below these speeds produce no audible response, preventing
  // micro-collisions from saturating the platform channel queue.
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Preloads audio pools into memory for zero-latency in-flight playback.
  /// All five pools are loaded concurrently via [Future.wait].
  ///
  /// Specifying [minPlayers] equal to [maxPlayers] guarantees all instances
  /// are pre-created during loading, preventing cold mid-game allocations.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _clock.reset();
      _clock.start();

      // Bounce gets 3 pooled players (highest fire rate: rapid floor bouncing).
      // Rim, backboard, swish get 2 each for potential rapid overlaps.
      // Buzzer only needs 1 (fires once at game end).
      final results = await Future.wait([
        FlameAudio.createPool('rim_clank.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('backboard.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('swish.wav', minPlayers: 2, maxPlayers: 2),
        FlameAudio.createPool('bounce.wav', minPlayers: 3, maxPlayers: 3),
        FlameAudio.createPool('buzzer.wav', minPlayers: 1, maxPlayers: 1),
      ]);

      _rimPool = results[0];
      _backboardPool = results[1];
      _swishPool = results[2];
      _bouncePool = results[3];
      _buzzerPool = results[4];

      _initialized = true;
    } catch (e) {
      debugPrint('[AudioEngine] Audio preload warning: $e');
    }
  }

  /// Triggers a metallic rim clank with volume and heavy haptics scaled by impact velocity.
  static void playRimClank(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minRimSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastRimUs < 80000) return; // 80ms debounce
    _lastRimUs = now;

    final volume = (impactSpeed / 6.0).clamp(0.35, 1.0);
    _safePoolPlay(_rimPool, volume);
    _safeHaptic(HapticFeedback.heavyImpact);
  }

  /// Triggers a solid tempered-glass backboard thud with medium haptics.
  static void playBackboardThud(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minBackboardSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBackboardUs < 80000) return; // 80ms debounce
    _lastBackboardUs = now;

    final volume = (impactSpeed / 7.0).clamp(0.35, 1.0);
    _safePoolPlay(_backboardPool, volume);
    _safeHaptic(HapticFeedback.mediumImpact);
  }

  /// Triggers a crisp nylon net swish whoosh on clean baskets.
  static void playSwish() {
    if (isMuted || !_initialized) return;
    _safePoolPlay(_swishPool, 1.0);
    _safeHaptic(HapticFeedback.selectionClick);
  }

  /// Triggers a warm hardwood court floor bounce with velocity-scaled volume and light haptics.
  static void playFloorBounce(double impactSpeed) {
    if (isMuted || !_initialized) return;
    if (impactSpeed < _minBounceSpeed) return;
    final now = _clock.elapsedMicroseconds;
    if (now - _lastBounceUs < 60000) return; // 60ms debounce
    _lastBounceUs = now;

    final volume = (impactSpeed / 6.5).clamp(0.20, 1.0);
    _safePoolPlay(_bouncePool, volume);

    if (impactSpeed > 2.0) {
      _safeHaptic(HapticFeedback.lightImpact);
    }
  }

  /// Triggers the arena shot-clock buzzer and long haptic vibration at 00:00.
  static void playBuzzer() {
    if (isMuted || !_initialized) return;
    _safePoolPlay(_buzzerPool, 1.0);
    _safeHaptic(HapticFeedback.vibrate);
  }

  /// Master volume scale for all sound effects (reduced by 25% from 1.0 -> 0.75).
  static const double masterVolume = 0.75;

  /// Plays from a pre-allocated pooled player with error handling.
  /// Reuses existing [AudioPlayer] instances and catches both sync and async failures.
  static void _safePoolPlay(AudioPool? pool, double volume) {
    if (pool == null) return;
    try {
      final effectiveVolume = (volume * masterVolume).clamp(0.0, 1.0);
      unawaited(
        pool.start(volume: effectiveVolume).then((_) => null, onError: (e) {
          debugPrint('[AudioEngine] Pool playback error: $e');
        }),
      );
    } catch (e) {
      debugPrint('[AudioEngine] Pool synchronous error: $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all pooled audio resources and frees native player handles.
  /// Safe to call multiple times.
  static void dispose() {
    final pools = [_rimPool, _backboardPool, _swishPool, _bouncePool, _buzzerPool];
    _rimPool = null;
    _backboardPool = null;
    _swishPool = null;
    _bouncePool = null;
    _buzzerPool = null;

    for (final pool in pools) {
      if (pool != null) {
        unawaited(
          pool.dispose().catchError((e) {
            debugPrint('[AudioEngine] Pool dispose warning: $e');
          }),
        );
      }
    }

    _clock.stop();
    _clock.reset();
    _lastBounceUs = 0;
    _lastRimUs = 0;
    _lastBackboardUs = 0;
    _initialized = false;
  }
}
