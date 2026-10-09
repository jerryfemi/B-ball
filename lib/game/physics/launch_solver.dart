import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Solves and calibrates the physical 3D launch velocity vector $(V_x, V_y, V_z)$
/// for basketball trajectories based on analytic ballistic kinematics.
class LaunchSolver {
  // Gravity constant in m/s²
  static const double gravity = 13.0;

  // 3D Start position in player's hands at free throw line (in meters)
  static final Vector3 defaultLaunchPos = Vector3(0.0, 0.25, 0.0);

  // 3D Target position at the rim center (in meters)
  static final Vector3 defaultRimTarget = Vector3(0.0, 3.05, 4.50);

  // Height above the rim where a perfect shot reaches its peak apex (in meters)
  static const double defaultApexAboveRim = 0.75;

  /// Solves the exact analytic reference velocity $(V_x, V_y, V_z)$ needed to peak
  /// [apexAboveRim] meters above [target] and drop through it cleanly.
  static Vector3 solveReferenceVelocity({
    Vector3? from,
    Vector3? target,
    double apexAboveRim = defaultApexAboveRim,
    double g = gravity,
  }) {
    final start = from ?? defaultLaunchPos;
    final dest = target ?? defaultRimTarget;

    final deltaY = dest.y - start.y;
    final totalRise = deltaY + apexAboveRim;

    // Upward launch velocity required to reach apex
    final vy = math.sqrt(2.0 * g * totalRise);

    // Flight time to apex, plus time to fall from apex to rim
    final tUp = vy / g;
    final tDown = math.sqrt(2.0 * apexAboveRim / g);
    final totalFlightTime = tUp + tDown;

    // Forward and lateral velocities to reach destination in that exact flight time
    final vz = (dest.z - start.z) / totalFlightTime;
    final vx = (dest.x - start.x) / totalFlightTime;

    return Vector3(vx, vy, vz);
  }

  /// Scales the reference trajectory based on the player's swipe speed and angle.
  ///
  /// - [powerRatio]: 1.0 is a perfect shot. < 1.0 is short (front iron/airball), > 1.0 is long (backboard/back rim).
  /// - [aimRatio]: lateral flick angle tangent (dx / dy).
  static Vector3 calculateLaunchVelocity({
    required double powerRatio,
    required double aimRatio,
    Vector3? from,
    Vector3? target,
  }) {
    final ref = solveReferenceVelocity(from: from, target: target);

    // Natural power curve: power affects both vertical and forward velocity
    // Gentle scaling around sweet spot (powerRatio = 1.0)
    final powerScaleY = (1.0 + (powerRatio - 1.0) * 0.50).clamp(0.30, 1.45);
    final powerScaleZ = (1.0 + (powerRatio - 1.0) * 0.55).clamp(0.25, 1.45);

    final vy = ref.y * powerScaleY;
    final vz = ref.z * powerScaleZ;

    // Lateral velocity based on flick angle:
    // Generous sweet-spot assistance for centered flicks
    double lateralAim = aimRatio;
    if (lateralAim.abs() < 0.12) {
      lateralAim *= 0.45; // Soft center assist for clean swishes
    }
    final vx = lateralAim * 3.2;

    return Vector3(vx, vy, vz);
  }
}
