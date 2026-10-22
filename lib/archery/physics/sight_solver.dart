import 'dart:math' as math;
import '../archery_constants.dart';

/// Calibrates the launch pitch and yaw angles from the unprojected crosshair position.
///
/// Ensures that with zero wind, an arrow launched at crosshair (Px, Py) on plane Z = D
/// lands within ±1 mm of that exact point.
class SightSolver {
  static final Map<double, double> _cachedCenterPitch = {};

  /// Solves the required launch pitch angle in radians to hit [targetY] on the plane
  /// at [distance] meters with speed [speed].
  static double solvePitch(
    double distance,
    double targetY, {
    double speed = ArcheryK.fullDrawSpeed,
  }) {
    // 1. Center pitch calibration
    double pitchCenter;
    if (_cachedCenterPitch.containsKey(distance)) {
      pitchCenter = _cachedCenterPitch[distance]!;
    } else {
      pitchCenter = _solveSecant(distance, ArcheryK.targetCenterY, speed);
      _cachedCenterPitch[distance] = pitchCenter;
    }

    if ((targetY - ArcheryK.targetCenterY).abs() < 1e-4) {
      return pitchCenter;
    }

    // 2. Small-angle estimate from center pitch
    final double dz = distance - ArcheryK.launchZ;
    final double deltaY = targetY - ArcheryK.targetCenterY;
    final double theta0 = pitchCenter + math.atan(deltaY / dz);

    // 3. Fast secant refinement (1-2 steps to reach < 0.2 mm precision)
    double err0 = simulateHitY(distance, theta0, speed) - targetY;
    if (err0.abs() < 0.0005) return theta0;

    final double theta1 = theta0 + 0.001;
    final double err1 = simulateHitY(distance, theta1, speed) - targetY;

    final double dErr = err1 - err0;
    if (dErr.abs() < 1e-9) return theta0;

    final double thetaFinal = theta1 - err1 * (theta1 - theta0) / dErr;
    return thetaFinal;
  }

  /// Calculates launch yaw to aim directly at horizontal coordinate [targetX] on plane Z = D.
  static double solveYaw(double distance, double targetX) {
    final double dz = distance - ArcheryK.launchZ;
    return math.atan2(targetX, dz);
  }

  static double _solveSecant(double distance, double targetY, double speed) {
    final double dz = distance - ArcheryK.launchZ;
    final double dy = targetY - ArcheryK.launchY;
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

    double err0 = simulateHitY(distance, theta0, speed) - targetY;
    if (err0.abs() < 0.0005) return theta0;

    double theta1 = theta0 + 0.002;
    double err1 = simulateHitY(distance, theta1, speed) - targetY;

    for (int iter = 0; iter < 8; iter++) {
      if (err1.abs() < 0.0005) break;

      final double dErr = err1 - err0;
      if (dErr.abs() < 1e-9) break;

      final double step = err1 * (theta1 - theta0) / dErr;
      theta0 = theta1;
      err0 = err1;

      theta1 -= step;
      err1 = simulateHitY(distance, theta1, speed) - targetY;
    }

    return theta1;
  }

  /// Simulates an arrow trajectory from launch anchor to Z = [distance]
  /// using 240 Hz fixed-step Euler physics with quadratic drag.
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

      if (y < -5.0) break;
    }

    final double dz = z - prevZ;
    final double f = dz != 0.0 ? (distance - prevZ) / dz : 1.0;
    return prevY + (y - prevY) * f;
  }
}
