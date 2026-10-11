import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized audio and haptics coordinator for basketball collisions,
/// net swishes, floor bounces, and round-ending buzzers.
class AudioEngine {
  static bool isMuted = false;
  static bool _initialized = false;

  // Rate-limiting timestamps (in milliseconds) to prevent audio jitter on substeps
  static int _lastBounceTimeMs = 0;
  static int _lastRimTimeMs = 0;
  static int _lastBackboardTimeMs = 0;

  static const String sfxRimClank = 'rim_clank.wav';
  static const String sfxBackboard = 'backboard.wav';
  static const String sfxSwish = 'swish.wav';
  static const String sfxBounce = 'bounce.wav';
  static const String sfxBuzzer = 'buzzer.wav';

  /// Preloads audio assets into memory cache for zero-latency in-flight playback.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await FlameAudio.audioCache.loadAll([
        sfxRimClank,
        sfxBackboard,
        sfxSwish,
        sfxBounce,
        sfxBuzzer,
      ]);
      _initialized = true;
    } catch (e) {
      debugPrint('[AudioEngine] Audio preload warning: $e');
    }
  }

  /// Triggers a metallic rim clank with volume and heavy haptics scaled by impact velocity.
  static void playRimClank(double impactSpeed) {
    if (isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRimTimeMs < 80) return;
    _lastRimTimeMs = now;

    final volume = (impactSpeed / 6.0).clamp(0.35, 1.0);
    _safePlay(sfxRimClank, volume);
    _safeHaptic(HapticFeedback.heavyImpact);
  }

  /// Triggers a solid tempered-glass backboard thud with medium haptics.
  static void playBackboardThud(double impactSpeed) {
    if (isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackboardTimeMs < 80) return;
    _lastBackboardTimeMs = now;

    final volume = (impactSpeed / 7.0).clamp(0.35, 1.0);
    _safePlay(sfxBackboard, volume);
    _safeHaptic(HapticFeedback.mediumImpact);
  }

  /// Triggers a crisp nylon net swish whoosh on clean baskets.
  static void playSwish() {
    if (isMuted) return;
    _safePlay(sfxSwish, 1.0);
    _safeHaptic(HapticFeedback.selectionClick);
  }

  /// Triggers a warm hardwood court floor bounce with velocity-scaled volume and light haptics.
  static void playFloorBounce(double impactSpeed) {
    if (isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBounceTimeMs < 60) return;
    _lastBounceTimeMs = now;

    final volume = (impactSpeed / 6.5).clamp(0.20, 1.0);
    _safePlay(sfxBounce, volume);

    if (impactSpeed > 2.0) {
      _safeHaptic(HapticFeedback.lightImpact);
    }
  }

  /// Triggers the arena shot-clock buzzer and long haptic vibration at 00:00.
  static void playBuzzer() {
    if (isMuted) return;
    _safePlay(sfxBuzzer, 1.0);
    _safeHaptic(HapticFeedback.vibrate);
  }

  static void _safePlay(String file, double volume) {
    try {
      FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('[AudioEngine] Playback error ($file): $e');
    }
  }

  static void _safeHaptic(Future<void> Function() hapticCall) {
    try {
      hapticCall();
    } catch (_) {}
  }
}
