import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../darts_constants.dart';

/// Ballistic trajectory solver and the flick-to-target mapping.
///
/// Pure flick (GamePigeon style): there is no aim preview. Where the dart
/// lands comes only from how it was thrown:
///  * where the finger let go sets left/right,
///  * the swipe's sideways angle adds drift,
///  * the swipe's speed sets the height.
abstract final class FlickSolver {
  /// Solves the closed-form low-arc launch velocity `Vector3(vx, vy, vz)` that lands
  /// on target `(aimX, aimY)` in board millimeters at the given launch [speed] (m/s).
  ///
  /// - Launch origin is `(startXm, startYm, D)` in metres, `D = 2.37` m
  ///   (defaults to straight in front of the bull).
  /// - Board plane is at $z = 0$.
  /// - Returns velocity with $v_z < 0$.
  static Vector3 launchFor(
    double aimX,
    double aimY, [
    double speed = DartsK.idealSpeed,
    double startXm = 0.0,
    double startYm = 0.0,
  ]) {
    final double targetX = aimX / 1000.0 - startXm; // metres, relative to the hand
    final double targetY = aimY / 1000.0 - startYm;
    const double d = DartsK.throwDistanceM; // 2.37 m
    const double g = DartsK.gravity; // 9.81 m/s²
    final double v2 = speed * speed;

    // Solve for flight time T from: v² = (x/T)² + (y/T + 0.5*g*T)² + (d/T)²
    // Let u = T²:  (1/4 g²) u² + (y*g - v²) u + (x² + y² + d²) = 0
    const double a = 0.25 * g * g;
    final double b = targetY * g - v2;
    final double c = targetX * targetX + targetY * targetY + d * d;

    final double discriminant = b * b - 4.0 * a * c;
    final double u = discriminant >= 0.0
        // Low arc: the smaller flight time (flatter trajectory)
        ? (-b - math.sqrt(discriminant)) / (2.0 * a)
        // Barely reachable at this speed: closest approach
        : -b / (2.0 * a);

    final double t = math.sqrt(math.max(u, 1e-4));

    return Vector3(targetX / t, (targetY / t) + 0.5 * g * t, -d / t);
  }

  /// Gentle aim assist (see [DartsK.assistPull]). Only the distance from the
  /// centre is nudged, so the dart stays in the segment it was heading for.
  static ({double x, double y}) assist(double x, double y) {
    final double r = math.sqrt(x * x + y * y);
    if (r < 1e-6) return (x: x, y: y);
    double target = r;
    const double pull = DartsK.assistPull;
    const double reach = DartsK.assistReachMm;
    const double tMid = (DartsK.trebleInR + DartsK.trebleOutR) * 0.5;
    const double dMid = (DartsK.doubleInR + DartsK.doubleOutR) * 0.5;
    if (r < DartsK.assistBullReachMm) {
      target = r * (1.0 - pull); // toward the bull
    } else if (r > DartsK.trebleInR - reach && r < DartsK.trebleOutR + reach) {
      target = r + (tMid - r) * pull;
    } else if (r > DartsK.doubleInR - reach && r < DartsK.doubleOutR + reach) {
      target = r + (dMid - r) * pull;
    }
    final double k = target / r;
    return (x: x * k, y: y * k);
  }

  /// Where a flick sends the dart, in board millimetres (+x right, +y up).
  ///
  /// - [releaseMmX]: the dart's horizontal position when the finger let go,
  ///   already converted to board mm (0 = straight below the bull).
  /// - [upwardSpeed]: the swipe's upward speed in screen heights per second.
  /// - [angleDeg]: the swipe's angle from straight up (−left, +right).
  static ({double x, double y}) targetForFlick({
    required double releaseMmX,
    required double upwardSpeed,
    required double angleDeg,
  }) {
    // Sideways drift past a small dead zone (a thumb never swipes perfectly
    // straight, so tiny curves are forgiven).
    double drift = 0.0;
    final double over = angleDeg.abs() - DartsK.flickDeadZoneDeg;
    if (over > 0.0) {
      final double rad = math.min(over, 60.0) * math.pi / 180.0;
      drift = math.tan(rad) * DartsK.flickDriftMmPerTan * angleDeg.sign;
    }

    // Height from speed: the reference flick lands at bull height.
    final double height =
        (upwardSpeed / DartsK.flickRefSpeed - 1.0) * DartsK.flickHeightMmPerUnit;

    const double m = DartsK.flickMaxAimMm;
    return (
      x: (releaseMmX + drift).clamp(-m, m).toDouble(),
      y: height.clamp(-m, m).toDouble(),
    );
  }
}
