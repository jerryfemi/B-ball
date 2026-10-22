import 'dart:math' as math;
import '../archery_constants.dart';

/// GamePigeon-style 2D wind model (0.0 to 2.0 intensity and 360° direction angle).
class WindModel {
  /// Displayed wind intensity with 1 decimal place (e.g. 0.8, 1.2, 2.0).
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

  /// Creates a deterministic wind instance from a unique hash seed.
  factory WindModel.fromSeed(int seed) {
    final math.Random rng = math.Random(seed);
    final double raw = rng.nextDouble() * ArcheryK.windMaxDisplay;
    final double display = (raw * 10.0).round() / 10.0;
    final double angle = rng.nextDouble() * 2.0 * math.pi;
    final double phi1 = rng.nextDouble() * 2.0 * math.pi;
    final double phi2 = rng.nextDouble() * 2.0 * math.pi;

    return WindModel(
      display: display,
      angle: angle,
      phi1: phi1,
      phi2: phi2,
    );
  }

  /// Calculates dynamic gust oscillation factor at flight elapsed time [t].
  double getGust(double t) {
    return 1.0 + 0.10 * math.sin(2.1 * t + phi1) + 0.05 * math.sin(5.3 * t + phi2);
  }

  /// Lateral acceleration contribution on arrow (m/s²).
  double getLateralAccel(double t) {
    return display * math.sin(angle) * ArcheryK.windLateralAccelPerUnit * getGust(t);
  }

  /// Along-track (tailwind/headwind) acceleration contribution on arrow (m/s²).
  double getAlongTrackAccel(double t) {
    return display * math.cos(angle) * ArcheryK.windAlongAccelPerUnit * getGust(t);
  }

  bool get blowsRight => math.sin(angle) >= 0;
}
