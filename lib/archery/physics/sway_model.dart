import 'dart:math' as math;
import '../archery_constants.dart';

/// GamePigeon-style deterministic visible sway model (Build Plan v2 §4.3).
///
/// Features three distinct temporal windows:
/// 1. Initial settling wobble immediately after touch-down.
/// 2. Optimal steady aim window (~1.8s - 3.5s).
/// 3. Fatigue shake ramping up toward shot timer expiration (5.0s).
class SwayModel {
  final int seed;

  late final double _p1;
  late final double _p2;
  late final double _p3;
  late final double _p4;

  double swayYaw = 0.0;   // Radians
  double swayPitch = 0.0; // Radians

  SwayModel({required this.seed}) {
    final math.Random rng = math.Random(seed);
    _p1 = rng.nextDouble() * 2.0 * math.pi;
    _p2 = rng.nextDouble() * 2.0 * math.pi;
    _p3 = rng.nextDouble() * 2.0 * math.pi;
    _p4 = rng.nextDouble() * 2.0 * math.pi;
  }

  /// Calculates total sway amplitude A(t) in radians at elapsed hold time [t] seconds.
  double getAmplitude(double t) {
    if (t < 0.0) return 0.0;
    final double fatigueRatio = t <= ArcheryK.fatigueStart
        ? 0.0
        : ((t - ArcheryK.fatigueStart) / (ArcheryK.shotTimerSeconds - ArcheryK.fatigueStart))
            .clamp(0.0, 1.0);

    // Smoothstep interpolation for fatigue
    final double smoothFatigue = fatigueRatio * fatigueRatio * (3.0 - 2.0 * fatigueRatio);

    return ArcheryK.swaySettle * math.exp(-t / ArcheryK.swaySettleTau) +
        ArcheryK.swayBase +
        ArcheryK.swayFatigue * smoothFatigue;
  }

  /// Updates sway angles given how many seconds the player has held the touch ([holdTime]).
  void update(double holdTime, bool isHolding) {
    if (!isHolding || holdTime <= 0.0) {
      swayYaw = 0.0;
      swayPitch = 0.0;
      return;
    }

    final double t = holdTime;
    final double amp = getAmplitude(t);

    swayYaw = amp * (math.sin(1.3 * t + _p1) + 0.5 * math.sin(2.9 * t + _p2)) / 1.5;
    swayPitch = amp * (math.sin(1.1 * t + _p3) + 0.5 * math.sin(3.7 * t + _p4)) / 1.5;
  }
}
