import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rendering quality tiers, from cheapest to richest.
enum QualityTier { low, medium, high }

/// Player-facing graphics setting. [auto] lets [AdaptiveQuality] decide.
enum QualityMode {
  auto,
  high,
  low;

  String get label => switch (this) {
    QualityMode.auto => 'AUTO',
    QualityMode.high => 'HIGH',
    QualityMode.low => 'LOW',
  };

  QualityMode get next => switch (this) {
    QualityMode.auto => QualityMode.high,
    QualityMode.high => QualityMode.low,
    QualityMode.low => QualityMode.auto,
  };
}

/// Watches real frame pacing and steps visual effects down when the phone
/// struggles (thermal throttling while charging, screen recording, low-power
/// mode) and back up once it has been stable for a while.
///
/// Signal: the game loop's `dt`. Unlike CPU-side frame timings, `dt` also
/// captures GPU stalls on mobile web (a late GPU delays the next
/// requestAnimationFrame), which is exactly what heat and screen recording cause.
///
/// Zero allocations per frame: only counters and doubles.
class AdaptiveQuality {
  AdaptiveQuality();

  final ValueNotifier<QualityTier> tierNotifier =
      ValueNotifier<QualityTier>(QualityTier.high);
  final ValueNotifier<QualityMode> modeNotifier =
      ValueNotifier<QualityMode>(QualityMode.auto);

  QualityTier get tier => tierNotifier.value;

  // ── What each tier draws ──────────────────────────────────────────────────
  /// Ball contact shadows on the backboard and back wall (extra sprite draws).
  bool get drawProximityShadows => tier == QualityTier.high;

  /// Share of ember sparks drawn behind a streaking ball. The flame/lightning
  /// plume itself is NEVER cut by quality — it's the streak reward players
  /// chase, and one of the cheapest things on screen (only the player's own
  /// BALL STREAK FX toggle turns it off). Lighter tiers just thin the embers.
  double get emberDensity => tier == QualityTier.high ? 1.0 : 0.5;

  /// Pebble/bump detail in the ball shader, 0..1 (the shader's most expensive
  /// per-pixel work). The shader additionally fades it by on-screen ball size.
  double get shaderDetail => switch (tier) {
    QualityTier.high => 1.0,
    QualityTier.medium => 0.6,
    QualityTier.low => 0.0,
  };

  // ── Tuning ────────────────────────────────────────────────────────────────
  /// A frame slower than this (~47 FPS) counts as "slow".
  static const double _slowFrameSeconds = 0.021;

  /// Gaps longer than this are pauses/tab switches, not rendering cost.
  static const double _ignoreFrameAbove = 0.25;

  /// Shader compilation and asset decode make the first seconds noisy.
  static const double _warmupSeconds = 3.0;

  /// Evaluation window; decisions use the last two windows (~2s of frames).
  static const double _windowSeconds = 1.0;

  /// Step down when more than this share of recent frames were slow.
  static const double _downgradeSlowRatio = 0.20;

  /// Only count as "stable" when fewer than this share were slow.
  static const double _stableSlowRatio = 0.04;

  /// Minimum time between two downgrades (lets the last change take effect).
  static const double _downgradeCooldown = 3.0;

  /// Stable time required before stepping back up. Doubles after every
  /// downgrade (backoff) so a hot phone doesn't flip-flop between tiers.
  static const double _baseUpgradeDelay = 10.0;
  static const double _maxUpgradeDelay = 120.0;

  static const String _prefsKey = 'graphics_quality_mode';

  // ── State (plain fields, no allocations) ─────────────────────────────────
  double _totalTime = 0.0;
  double _windowTime = 0.0;
  int _windowFrames = 0;
  int _windowSlow = 0;
  int _prevFrames = 0;
  int _prevSlow = 0;
  double _sinceLastChange = 0.0;
  double _stableTime = 0.0;
  double _upgradeDelay = _baseUpgradeDelay;

  /// Restores the player's saved Auto/High/Low choice.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      final mode = QualityMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => QualityMode.auto,
      );
      _applyMode(mode);
    } catch (e) {
      debugPrint('[AdaptiveQuality] Could not load preference: $e');
    }
  }

  /// Cycles AUTO → HIGH → LOW and persists the choice.
  Future<void> cycleMode() async {
    final next = modeNotifier.value.next;
    _applyMode(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (e) {
      debugPrint('[AdaptiveQuality] Could not save preference: $e');
    }
  }

  void _applyMode(QualityMode mode) {
    modeNotifier.value = mode;
    switch (mode) {
      case QualityMode.high:
        tierNotifier.value = QualityTier.high;
      case QualityMode.low:
        tierNotifier.value = QualityTier.low;
      case QualityMode.auto:
        // Start optimistic; the monitor steps down within a few seconds if needed.
        tierNotifier.value = QualityTier.high;
        _resetWindows();
        _upgradeDelay = _baseUpgradeDelay;
    }
  }

  void _resetWindows() {
    _windowTime = 0.0;
    _windowFrames = 0;
    _windowSlow = 0;
    _prevFrames = 0;
    _prevSlow = 0;
    _sinceLastChange = 0.0;
    _stableTime = 0.0;
  }

  /// Feed every game-loop frame's raw `dt` (seconds). Cheap: a few additions.
  void recordFrame(double dt) {
    if (modeNotifier.value != QualityMode.auto) return;
    if (dt <= 0.0 || dt > _ignoreFrameAbove) return;

    _totalTime += dt;
    if (_totalTime < _warmupSeconds) return;

    _sinceLastChange += dt;
    _windowTime += dt;
    _windowFrames++;
    if (dt > _slowFrameSeconds) _windowSlow++;

    if (_windowTime >= _windowSeconds) {
      _evaluate();
      _prevFrames = _windowFrames;
      _prevSlow = _windowSlow;
      _windowTime = 0.0;
      _windowFrames = 0;
      _windowSlow = 0;
    }
  }

  void _evaluate() {
    final frames = _prevFrames + _windowFrames;
    if (frames == 0) return;
    final slowRatio = (_prevSlow + _windowSlow) / frames;

    if (slowRatio > _downgradeSlowRatio) {
      _stableTime = 0.0;
      if (tier != QualityTier.low && _sinceLastChange >= _downgradeCooldown) {
        _setTier(QualityTier.values[tier.index - 1]);
        _upgradeDelay = (_upgradeDelay * 2).clamp(
          _baseUpgradeDelay,
          _maxUpgradeDelay,
        );
      }
    } else if (slowRatio < _stableSlowRatio) {
      _stableTime += _windowTime;
      if (tier != QualityTier.high && _stableTime >= _upgradeDelay) {
        _setTier(QualityTier.values[tier.index + 1]);
        _stableTime = 0.0;
      }
    } else {
      // In between: neither clearly struggling nor clearly fine.
      _stableTime = 0.0;
    }
  }

  void _setTier(QualityTier next) {
    if (next == tier) return;
    debugPrint('[AdaptiveQuality] ${tier.name} → ${next.name}');
    tierNotifier.value = next;
    _sinceLastChange = 0.0;
  }

  void dispose() {
    tierNotifier.dispose();
    modeNotifier.dispose();
  }
}
