import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../darts_constants.dart';

/// Ballistic trajectory solver and gesture error model for dart throws.
///
/// Converts a reticle aim coordinate `(aimX, aimY)` in board millimeters into
/// a 3D launch velocity vector, and applies realistic physical flick perturbations
/// based on flick power (speed) and direction angle.
abstract final class FlickSolver {
  /// Solves the closed-form low-arc launch velocity `Vector3(vx, vy, vz)` that lands
  /// on target `(aimX, aimY)` in board millimeters at the given launch [speed] (m/s).
  ///
  /// - Launch origin is $(0, 0, D)$ where $D = 2.37$ m.
  /// - Board plane is at $z = 0$.
  /// - Returns velocity with $v_z < 0$.
  static Vector3 launchFor(
    double aimX,
    double aimY, [
    double speed = DartsK.idealSpeed,
  ]) {
    final double targetX = aimX / 1000.0; // meters
    final double targetY = aimY / 1000.0; // meters
    final double d = DartsK.throwDistanceM; // 2.37 m
    final double g = DartsK.gravity; // 9.81 m/s²
    final double v = speed;
    final double v2 = v * v;

    // Closed-form flat-ground ballistic trajectory equation:
    // Solve for flight time T from: v² = (x/T)² + (y/T + 0.5*g*T)² + (d/T)²
    // Let u = T²:
    // (1/4 g²) u² + (y*g - v²) u + (x² + y² + d²) = 0
    final double a = 0.25 * g * g;
    final double b = targetY * g - v2;
    final double c = targetX * targetX + targetY * targetY + d * d;

    final double discriminant = b * b - 4.0 * a * c;
    final double u;
    if (discriminant >= 0.0) {
      // Low arc corresponds to the smaller flight time (flatter trajectory)
      u = (-b - math.sqrt(discriminant)) / (2.0 * a);
    } else {
      // Fallback if target is barely reachable at this speed
      u = -b / (2.0 * a);
    }

    final double t = math.sqrt(math.max(u, 1e-4));

    final double vz = -d / t;
    final double vx = targetX / t;
    final double vy = (targetY / t) + 0.5 * g * t;

    return Vector3(vx, vy, vz);
  }

  /// Modifies an [idealLaunch] velocity vector according to the player's flick gesture.
  ///
  /// - [flickPower]: Flick speed normalized relative to [DartsK.idealFlick] (1.0 = ideal).
  ///   Inside sweet band `[0.8, 1.3]` no power error is applied.
  ///   Outside sweet band: speed scales linearly (25% outside ≈ 30 mm vertical error).
  ///
  /// - [flickAngleDeg]: Flick release angle relative to straight-up in degrees.
  ///   Inside sweet band `[-6.0°, 6.0°]` no lateral error is applied.
  ///   Outside sweet band: yaw rotates to yield ~2.5 mm lateral shift per extra degree.
  static Vector3 applyFlick(
    Vector3 idealLaunch,
    double flickPower,
    double flickAngleDeg,
  ) {
    // 1. Calculate power error and speed scale
    double deltaPower = 0.0;
    if (flickPower < DartsK.sweetLow) {
      deltaPower = flickPower - DartsK.sweetLow; // negative
    } else if (flickPower > DartsK.sweetHigh) {
      deltaPower = flickPower - DartsK.sweetHigh; // positive
    }

    // Calibrated speed scale: 25% outside the band (0.25) ≈ 30 mm vertical shift on board
    // In physics, deltaY ≈ g * T² * deltaSpeedScale ≈ 1.20 * deltaSpeedScale meters
    // deltaSpeedScale = 0.030 / 1.20 = 0.025 = deltaPower * 0.10
    const double speedScaleFactor = 0.10;
    final double speedScale = 1.0 + deltaPower * speedScaleFactor;

    // 2. Calculate yaw error rotation angle
    double excessDeg = 0.0;
    if (flickAngleDeg > DartsK.angleSweetDeg) {
      excessDeg = flickAngleDeg - DartsK.angleSweetDeg; // positive (right)
    } else if (flickAngleDeg < -DartsK.angleSweetDeg) {
      excessDeg = flickAngleDeg - (-DartsK.angleSweetDeg); // negative (left)
    }

    // At throw distance D = 2.37 m (2370 mm), a lateral shift of deltaX requires:
    // yaw = deltaX / D_mm radians.
    // deltaX = excessDeg * angleErrorMmPerDeg (2.5 mm/deg)
    final double lateralShiftMm = excessDeg * DartsK.angleErrorMmPerDeg;
    final double yawRad = lateralShiftMm / (DartsK.throwDistanceM * 1000.0);

    // 3. Rotate velocity around Y axis (in X-Z plane)
    final double cosY = math.cos(yawRad);
    final double sinY = math.sin(yawRad);

    final double vx = idealLaunch.x;
    final double vy = idealLaunch.y;
    final double vz = idealLaunch.z;

    // Since vz < 0 (toward board), rotating clockwise (yawRad > 0) increases vx
    final double rotatedVx = vx * cosY - vz * sinY;
    final double rotatedVz = vx * sinY + vz * cosY;
    final double rotatedVy = vy;

    // 4. Apply speed scale
    return Vector3(
      rotatedVx * speedScale,
      rotatedVy * speedScale,
      rotatedVz * speedScale,
    );
  }
}
