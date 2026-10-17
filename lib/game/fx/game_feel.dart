import 'dart:math' as math;

/// Whole-court camera reactions: a small shake on hard clanks and a quick
/// zoom-punch toward the hoop on makes.
///
/// Applied in [BasketballGame.render] as a canvas transform around the game
/// only, so Flutter HUD overlays stay rock-steady. Because the ball shader
/// reads raw screen coordinates (it ignores canvas transforms), the ball folds
/// [offsetX]/[offsetY]/[scale] into its own uniforms so it never drifts away
/// from its shadow during a shake.
///
/// Zero allocations: envelopes are plain doubles updated once per frame.
class ScreenFx {
  // Shake (logical pixels)
  double _shakeAmp = 0.0;
  double _shakeT = 1e9;

  // Zoom punch (fractional scale, e.g. 0.02 = +2%)
  double _punchAmp = 0.0;
  double _punchT = 1e9;

  /// Zoom origin in logical pixels (the hoop), set by the game on resize.
  double originX = 0.0;
  double originY = 0.0;

  /// Viewport width, used to over-scale slightly so shakes never expose edges.
  double viewportWidth = 1.0;

  // Resolved per-frame values (read by render code)
  double offsetX = 0.0;
  double offsetY = 0.0;
  double scale = 1.0;
  bool isActive = false;

  static const double _shakeDecay = 16.0;
  static const double _punchRise = 40.0;
  static const double _punchDecay = 7.0;

  /// Adds a shake of roughly [pixels] logical pixels (stronger hit wins).
  void shake(double pixels) {
    final current = _shakeAmp * math.exp(-_shakeT * _shakeDecay);
    if (pixels > current) {
      _shakeAmp = pixels;
      _shakeT = 0.0;
    }
  }

  /// Adds a zoom punch of [amount] (0.015 = 1.5% toward the hoop).
  void punch(double amount) {
    final t = _punchT;
    final current =
        _punchAmp * (1.0 - math.exp(-t * _punchRise)) * math.exp(-t * _punchDecay);
    if (amount > current) {
      _punchAmp = amount;
      _punchT = 0.0;
    }
  }

  void update(double dt) {
    _shakeT += dt;
    _punchT += dt;

    final shakeEnv = _shakeAmp * math.exp(-_shakeT * _shakeDecay);
    final punchEnv = _punchAmp *
        (1.0 - math.exp(-_punchT * _punchRise)) *
        math.exp(-_punchT * _punchDecay);

    if (shakeEnv < 0.05 && punchEnv < 0.0005) {
      offsetX = 0.0;
      offsetY = 0.0;
      scale = 1.0;
      isActive = false;
      return;
    }

    isActive = true;
    // Two incommensurate frequencies give an organic, non-repeating jitter.
    offsetX = shakeEnv * math.sin(_shakeT * 73.0);
    offsetY = shakeEnv * math.cos(_shakeT * 59.0);
    // Over-scale just enough that the shake never reveals the canvas edge.
    final edgeGuard = viewportWidth > 0 ? (2.2 * shakeEnv / viewportWidth) : 0.0;
    scale = 1.0 + punchEnv + edgeGuard;
  }
}

/// Rim and backboard vibration after impacts. Drawn as a translation of the
/// pre-recorded hoop pictures, so it costs nothing extra to render.
/// Units are Forge2D world meters (1 unit ≈ 40 logical px on a phone).
class HoopFx {
  double _rimAmp = 0.0;
  double _rimT = 1e9;
  double _boardAmp = 0.0;
  double _boardT = 1e9;

  double rimOffsetX = 0.0;
  double rimOffsetY = 0.0;
  double boardOffsetX = 0.0;
  double boardOffsetY = 0.0;

  static const double _rimDecay = 10.0;
  static const double _boardDecay = 13.0;

  /// A rim clank at [speed] m/s. Hard hits ring the rim visibly (~2px).
  void rimHit(double speed) {
    final amp = (speed * 0.012).clamp(0.0, 0.055);
    final current = _rimAmp * math.exp(-_rimT * _rimDecay);
    if (amp > current) {
      _rimAmp = amp;
      _rimT = 0.0;
    }
    // The whole hoop assembly shudders a little with the rim.
    boardHit(speed * 0.45);
  }

  /// A backboard impact at [speed] m/s (subtle flex, ~1px).
  void boardHit(double speed) {
    final amp = (speed * 0.005).clamp(0.0, 0.025);
    final current = _boardAmp * math.exp(-_boardT * _boardDecay);
    if (amp > current) {
      _boardAmp = amp;
      _boardT = 0.0;
    }
  }

  void update(double dt) {
    _rimT += dt;
    _boardT += dt;

    final rimEnv = _rimAmp * math.exp(-_rimT * _rimDecay);
    if (rimEnv < 0.0005) {
      rimOffsetX = 0.0;
      rimOffsetY = 0.0;
    } else {
      // Mostly vertical "boing", with a little lateral wobble.
      rimOffsetY = rimEnv * math.sin(_rimT * 62.0);
      rimOffsetX = rimEnv * 0.35 * math.sin(_rimT * 47.0 + 1.3);
    }

    final boardEnv = _boardAmp * math.exp(-_boardT * _boardDecay);
    if (boardEnv < 0.0005) {
      boardOffsetX = 0.0;
      boardOffsetY = 0.0;
    } else {
      boardOffsetX = boardEnv * math.sin(_boardT * 41.0);
      boardOffsetY = boardEnv * 0.5 * math.sin(_boardT * 53.0 + 0.7);
    }
  }
}
