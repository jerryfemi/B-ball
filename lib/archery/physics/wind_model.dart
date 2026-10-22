import 'dart:math' as math;
import '../archery_constants.dart';

/// Per-arrow wind, shown to the player in mph (the range is measured in
/// feet, so the wind is too: imperial throughout).
///
/// Every direction matters: a crosswind pushes the arrow sideways, a
/// tailwind carries it a little higher and a headwind drops it.
class WindModel {
  /// Wind speed in whole mph, 0 to [ArcheryK.windMaxMph].
  final double display;

  /// Wind angle in radians:
  /// - 0 = blowing downrange / tailwind (+Z)
  /// - π/2 = blowing right (+X)
  /// - π = blowing toward archer / headwind (-Z)
  /// - 3π/2 = blowing left (-X)
  final double angle;

  final double phi1;
  final double phi2;

  const WindModel({
    required this.display,
    required this.angle,
    this.phi1 = 0.0,
    this.phi2 = 0.0,
  });

  /// The same seed gives the same wind on every phone (online fairness).
  ///
  /// Calm air is rare (about 1 arrow in 12 gets 0–2 mph); the rest get
  /// 3–12 mph, so reading the wind is part of every shot.
  factory WindModel.fromSeed(int seed) {
    final math.Random rng = math.Random(seed);
    final double u = rng.nextDouble();
    const double calmShare = 0.08;
    final double mph = u < calmShare
        ? (u / calmShare * 2.0).roundToDouble()
        : (3.0 + (u - calmShare) / (1.0 - calmShare) * (ArcheryK.windMaxMph - 3.0))
            .roundToDouble();
    final double angle = rng.nextDouble() * 2.0 * math.pi;
    final double phi1 = rng.nextDouble() * 2.0 * math.pi;
    final double phi2 = rng.nextDouble() * 2.0 * math.pi;

    return WindModel(
      display: mph.clamp(0.0, ArcheryK.windMaxMph),
      angle: angle,
      phi1: phi1,
      phi2: phi2,
    );
  }

  /// Whole mph, for display.
  int get mph => display.round();

  /// Small gusts (about ±5%): enough to feel alive, small enough that a
  /// careful aim correction still lands.
  double getGust(double t) {
    return 1.0 + 0.035 * math.sin(2.1 * t + phi1) + 0.015 * math.sin(5.3 * t + phi2);
  }

  /// Sideways push on the arrow (m/s²).
  double getLateralAccel(double t) {
    return display * math.sin(angle) * ArcheryK.windLateralAccelPerMph * getGust(t);
  }

  /// Up/down push (m/s²): tailwind lifts, headwind drops.
  double getVerticalAccel(double t) {
    return display * math.cos(angle) * ArcheryK.windVerticalAccelPerMph * getGust(t);
  }

  /// Along-track push (m/s²): a small change in arrow speed.
  double getAlongTrackAccel(double t) {
    return display * math.cos(angle) * ArcheryK.windAlongAccelPerMph * getGust(t);
  }

  bool get blowsRight => math.sin(angle) >= 0;
}
