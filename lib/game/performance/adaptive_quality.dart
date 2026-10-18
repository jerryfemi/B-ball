import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rendering quality tiers.
enum QualityTier { low, high }

/// Player-facing GRAPHICS setting (pause menu). Defaults to [low].
enum QualityMode {
  low,
  high;

  String get label => switch (this) {
    QualityMode.high => 'HIGH',
    QualityMode.low => 'LOW',
  };

  QualityMode get next => switch (this) {
    QualityMode.low => QualityMode.high,
    QualityMode.high => QualityMode.low,
  };
}

/// The player's GRAPHICS choice: HIGH or LOW (default LOW).
///
/// LOW changes exactly one thing: the ball is drawn as smooth leather instead
/// of pebbled leather. The pebble/bump pass is the most expensive per-pixel
/// work in the ball shader; every other effect (floor reflection, contact
/// shadows, sparks, glow, embers, fire trail, lighting, net) looks the same
/// on both settings because they cost very little.
///
/// (Replaces the old frame-time AUTO monitor, which was removed: with LOW as
/// the default there was nothing left for it to step down.)
class AdaptiveQuality {
  AdaptiveQuality();

  final ValueNotifier<QualityTier> tierNotifier =
      ValueNotifier<QualityTier>(QualityTier.low);
  final ValueNotifier<QualityMode> modeNotifier =
      ValueNotifier<QualityMode>(QualityMode.low);

  QualityTier get tier => tierNotifier.value;

  // ── What each setting draws ───────────────────────────────────────────────
  /// Pebble/bump detail in the ball shader, 0..1 — the only thing LOW reduces.
  /// The shader additionally fades it by on-screen ball size.
  double get shaderDetail => tier == QualityTier.high ? 1.0 : 0.0;

  /// Ball contact shadows on the backboard and back wall (both settings).
  bool get drawProximityShadows => true;

  /// Share of ember sparks drawn behind a streaking ball (both settings).
  double get emberDensity => 1.0;

  /// Mirror reflection of the ball on the varnished floor (both settings).
  bool get drawFloorReflection => true;

  /// Fake-bloom halos around streak sparks (both settings).
  bool get drawSparkBloom => true;

  static const String _prefsKey = 'graphics_quality_mode';

  /// Restores the player's saved HIGH/LOW choice. Anything else (including
  /// the old 'auto' value) falls back to LOW.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _applyMode(saved == QualityMode.high.name ? QualityMode.high : QualityMode.low);
    } catch (e) {
      debugPrint('[GraphicsQuality] Could not load preference: $e');
    }
  }

  /// Toggles HIGH ↔ LOW and persists the choice.
  Future<void> cycleMode() async {
    final next = modeNotifier.value.next;
    _applyMode(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (e) {
      debugPrint('[GraphicsQuality] Could not save preference: $e');
    }
  }

  void _applyMode(QualityMode mode) {
    modeNotifier.value = mode;
    tierNotifier.value =
        mode == QualityMode.high ? QualityTier.high : QualityTier.low;
  }

  void dispose() {
    tierNotifier.dispose();
    modeNotifier.dispose();
  }
}
