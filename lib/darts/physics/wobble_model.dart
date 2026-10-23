import 'dart:math' as math;
import '../darts_constants.dart';

/// GamePigeon-style deterministic reticle sway and wobble model in board millimeters.
///
/// Simulates physical hand tremor across three temporal phases:
/// 1. **Initial settling** (0.0s – ~0.6s): Wobble immediately after touch-down (~18 mm).
/// 2. **Steady aim window** (~0.6s – 3.0s): Optimal calm holding window (~4 mm).
/// 3. **Fatigue shake** (3.0s – 5.0s+): Muscular fatigue shakes ramp up to ~20 mm
///    and remain steady without auto-firing.
///
/// Features:
/// - Pure Dart (zero Flutter/Flame imports).
/// - Seeded per `(matchSeed, round, dartIndex)` for deterministic replay and testability.
/// - Zero allocations in hot `update()` path: writes directly to primitive [dx] and [dy].
class WobbleModel {
  final int seed;

  late final double _p1;
  late final double _p2;
  late final double _p3;
  late final double _p4;

  /// Horizontal wobble offset in board millimeters.
  double dx = 0.0;

  /// Vertical wobble offset in board millimeters.
  double dy = 0.0;

  WobbleModel({required this.seed}) {
    final math.Random rng = math.Random(seed);
    _p1 = rng.nextDouble() * 2.0 * math.pi;
    _p2 = rng.nextDouble() * 2.0 * math.pi;
    _p3 = rng.nextDouble() * 2.0 * math.pi;
    _p4 = rng.nextDouble() * 2.0 * math.pi;
  }

  /// Convenience constructor to deterministically seed from match context.
  WobbleModel.fromMatch({
    required int matchSeed,
    required int round,
    required int dartIndex,
  }) : this(seed: seedFor(matchSeed, round, dartIndex));

  /// Generates a deterministic integer seed from match parameters.
  static int seedFor(int matchSeed, int round, int dartIndex) {
    int h = matchSeed;
    h = (h * 31 + round) & 0x7FFFFFFF;
    h = (h * 31 + dartIndex) & 0x7FFFFFFF;
    return h == 0 ? 1 : h;
  }

  /// Calculates total wobble envelope amplitude in millimeters at elapsed hold time [t] seconds.
  double getAmplitude(double t) {
    if (t <= 0.0) return 0.0;

    final double fatigueRatio = t <= DartsK.fatigueStart
        ? 0.0
        : ((t - DartsK.fatigueStart) / (DartsK.fatigueFull - DartsK.fatigueStart))
            .clamp(0.0, 1.0);

    // Smoothstep interpolation for fatigue onset: 3x^2 - 2x^3
    final double smoothFatigue = fatigueRatio * fatigueRatio * (3.0 - 2.0 * fatigueRatio);

    return DartsK.wobbleSettle * math.exp(-t / DartsK.wobbleSettleTau) +
        DartsK.wobbleBase +
        DartsK.wobbleFatigue * smoothFatigue;
  }

  /// Updates [dx] and [dy] offsets (in board mm) given the current [holdTime] in seconds.
  ///
  /// Guarantees zero heap allocations per call.
  void update(double holdTime, bool isHolding) {
    if (!isHolding || holdTime <= 0.0) {
      dx = 0.0;
      dy = 0.0;
      return;
    }

    final double amp = getAmplitude(holdTime);

    // Two non-harmonic sines per axis, normalized by maximum amplitude (1.0 + 0.5 = 1.5)
    dx = amp * (math.sin(1.3 * holdTime + _p1) + 0.5 * math.sin(2.9 * holdTime + _p2)) / 1.5;
    dy = amp * (math.sin(1.1 * holdTime + _p3) + 0.5 * math.sin(3.7 * holdTime + _p4)) / 1.5;
  }

  /// Resets offsets back to zero.
  void reset() {
    dx = 0.0;
    dy = 0.0;
  }
}
