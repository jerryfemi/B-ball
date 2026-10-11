import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, and round-ending buzzers.
///
/// Performance architecture (replaces naive FlameAudio.play()):
/// - **Phase 1 – Player Pooling:** Pre-allocated [AudioPool] instances reuse
///   a fixed set of [AudioPlayer] objects instead of creating and discarding
///   a new player on every playback call.
/// - **Phase 2 – Stopwatch Rate-Limiting:** A monotonic [Stopwatch] replaces
///   [DateTime.now()] syscalls in the hot path, eliminating kernel transitions
///   during the 240 Hz physics substep loop.
/// - **Phase 3 – Velocity Gating:** Minimum impact speed thresholds prevent
///   trivially soft micro-collisions from ever reaching the audio pipeline.
class AudioEngine {
  static bool isMuted = false;
  static bool _initialized = false;

  // ── Phase 2: Monotonic stopwatch (zero-allocation, no syscall) ──
  static final Stopwatch _clock = Stopwatch();
  static int _lastBounceUs = 0;
  static int _lastRimUs = 0;
  static int _lastBackboardUs = 0;

  // ── Phase 1: Pre-allocated audio player pools ──
  // Each pool maintains a fixed ring of AudioPlayer instances that are
  // reused across playback calls, avoiding the create-per-play overhead
  // of FlameAudio.play() which allocates native platform resources each time.
  static AudioPool? _rimPool;
  static AudioPool? _backboardPool;
  static AudioPool? _swishPool;
  static AudioPool? _bouncePool;
  static AudioPool? _buzzerPool;

  // ── Phase 3: Minimum impact velocity thresholds (m/s) ──
  // Impacts below these speeds produce no audible response, preventing
  // micro-collisions from saturating the platform channel queue.
  static const double _minRimSpeed = 0.5;
  static const double _minBackboardSpeed = 0.5;
  static const double _minBounceSpeed = 0.3;

  /// Preloads audio pools into memory for zero-latency in-flight playback.
  /// All five pools are loaded concurrently via [Future.wait].
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _clock.start();

      // Bounce gets 3 pooled players (highest fire rate: rapid floor bouncing).
      // Rim, backboard, swish get 2 each for potential rapid overlaps.
      // Buzzer only needs 1 (fires once at game end).
      final results = await Future.wait([
        FlameAudio.createPool('rim_clank.wav', maxPlayers: 2),
        FlameAudio.createPool('backboard.wav', maxPlayers: 2),
        FlameAudio.createPool('swish.wav', maxPlayers: 2),
        FlameAudio.createPool('bounce.wav', maxPlayers: 3),
        FlameAudio.createPool('buzzer.wav', maxPlayers: 1),
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

  /// Plays from a pre-allocated pooled player with error handling.
  /// Unlike [FlameAudio.play], this reuses existing [AudioPlayer] instances
  /// instead of creating and discarding new ones on each call.
  static void _safePoolPlay(AudioPool? pool, double volume) {
    if (pool == null) return;
    try {
      pool.start(volume: volume);
    } catch (e) {
      debugPrint('[AudioEngine] Pool playback error: $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    try {
      hapticCall();
    } catch (_) {}
  }

  /// Releases all pooled audio resources. Safe to call multiple times.
  static void dispose() {
    _rimPool = null;
    _backboardPool = null;
    _swishPool = null;
    _bouncePool = null;
    _buzzerPool = null;
    _clock.stop();
    _initialized = false;
  }
}
