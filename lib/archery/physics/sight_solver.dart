import 'dart:math' as math;
import '../archery_constants.dart';

/// Calibrates the bow's sight pitch mark for any given round distance.
///
/// Ensures that at 100% full draw with zero wind, an arrow aimed directly
/// at the reticle hits the target center within ±1 mm.
class SightSolver {
  // Cached solutions for standard distances
  static final Map<double, double> _cachedOffsets = {};

  /// Returns the sight pitch offset in radians for the target at [distance] meters.
  ///
  /// Launch pitch calculation at release:
  /// `launchPitch = cameraPitch + sightPitchOffset + swayPitch`
  static double getSightPitchOffset(double distance, {double speed = ArcheryK.fullDrawSpeed}) {
    if (_cachedOffsets.containsKey(distance)) {
      return _cachedOffsets[distance]!;
    }
    final double offset = solve(distance, speed: speed);
    _cachedOffsets[distance] = offset;
    return offset;
  }

  /// Solves numerically using the full physics simulation and the Secant method.
  static double solve(double distance, {double speed = ArcheryK.fullDrawSpeed}) {
    // Eye and target geometry
    final double cameraPitchCenter = math.atan2(
      ArcheryK.targetCenterY - ArcheryK.eyeY,
      distance,
    );

    // Initial Guess: closed-form low-arc ballistic formula (no drag)
    final double dz = distance - ArcheryK.launchZ;
    final double dy = ArcheryK.targetCenterY - ArcheryK.launchY;
    final double v2 = speed * speed;
    final double g = ArcheryK.gravity;

    final double discriminant = v2 * v2 - g * (g * dz * dz + 2.0 * dy * v2);
    double theta0;
    if (discriminant >= 0.0) {
      final double tanTheta = (v2 - math.sqrt(discriminant)) / (g * dz);
      theta0 = math.atan(tanTheta);
    } else {
      theta0 = math.atan2(dy, dz);
    }

    // Measure vertical error with full drag simulation at theta0
    double err0 = simulateHitY(distance, theta0, speed) - ArcheryK.targetCenterY;
    if (err0.abs() < 0.0005) {
      return theta0 - cameraPitchCenter;
    }

    // Perturbation for Secant iteration
    double theta1 = theta0 + 0.002;
    double err1 = simulateHitY(distance, theta1, speed) - ArcheryK.targetCenterY;

    // Secant iterations (converges to < 0.1 mm in 3-5 steps)
    for (int iter = 0; iter < 10; iter++) {
      if (err1.abs() < 0.0005) break;

      final double dErr = err1 - err0;
      if (dErr.abs() < 1e-9) break;

      final double step = err1 * (theta1 - theta0) / dErr;
      theta0 = theta1;
      err0 = err1;

      theta1 -= step;
      err1 = simulateHitY(distance, theta1, speed) - ArcheryK.targetCenterY;
    }

    final double solvedLaunchPitch = theta1;
    return solvedLaunchPitch - cameraPitchCenter;
  }

  /// Simulates an arrow trajectory from the launch anchor to Z = [distance]
  /// using the exact 240 Hz fixed-step Euler physics with quadratic drag.
  static double simulateHitY(double distance, double launchPitch, double speed) {
    double y = ArcheryK.launchY;
    double z = ArcheryK.launchZ;

    double vy = speed * math.sin(launchPitch);
    double vz = speed * math.cos(launchPitch);

    const double dt = ArcheryK.fixedDt;
    const double dragK = ArcheryK.dragK;
    const double g = ArcheryK.gravity;

    double prevY = y;
    double prevZ = z;

    while (z < distance) {
      prevY = y;
      prevZ = z;

      final double vRel = math.sqrt(vy * vy + vz * vz);
      final double dragFactor = dragK * vRel;

      final double ay = -dragFactor * vy - g;
      final double az = -dragFactor * vz;

      vy += ay * dt;
      vz += az * dt;

      y += vy * dt;
      z += vz * dt;

      // Ground safety limit
      if (y < -5.0) break;
    }

    // Interpolate plane crossing at z = distance
    final double dz = z - prevZ;
    final double f = dz != 0.0 ? (distance - prevZ) / dz : 1.0;
    return prevY + (y - prevY) * f;
  }
}
