import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'shot_difficulty.dart';

/// Solves and calibrates the physical 3D launch velocity vector $(V_x, V_y, V_z)$
/// for basketball trajectories based on analytic ballistic kinematics.
class LaunchSolver {
  // Gravity constant in m/s²
  static const double gravity = 13.0;

  // 3D Start position in player's hands at free throw line (in meters)
  static final Vector3 defaultLaunchPos = Vector3(0.0, 0.25, 0.0);

  // 3D Target position at the rim center (in meters)
  static final Vector3 defaultRimTarget = Vector3(0.0, 3.05, 4.50);

  // Height above the rim where a perfect shot reaches its peak apex (in meters).
  // Calibrated to 0.85m for an optimal ~49.3° entry angle that comfortably clears
  // clean swishes while guaranteeing the entire ball arc stays framed safely below
  // mobile notches, status bars, and Dynamic Islands.
  static const double defaultApexAboveRim = 0.85;

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

  /// GamePigeon calibrated reference flick curve with power plateau.
  ///
  /// Across the natural flick range [ref * (1 - plateau)] to [ref * (1 + plateau)],
  /// power stays locked at exactly 1.0 (clean swish trajectory).
  /// Flicks outside the plateau scale smoothly into short (front iron/airball)
  /// or deep (back iron/bank) trajectories.
  static double flickToPower(
    double speedPxPerSec, {
    ShotDifficulty difficulty = ShotDifficulty.medium,
  }) {
    const double ref = 720.0;
    final double plateau = difficulty.plateau;

    final double d = (speedPxPerSec / ref) - 1.0;
    final double rawPower =
        1.0 + (d.abs() < plateau ? 0.0 : d - plateau * d.sign);

    return rawPower.clamp(difficulty.minPower, difficulty.maxPower);
  }

  /// Continuous C0 aim assist curve with dead zone for center flicks.
  ///
  /// Sub-threshold lateral flicks are locked directly to the hoop center axis (0.0).
  /// Transitions smoothly from soft assist up to 1.0x unassisted raw aim at |aimRatio| >= 0.25.
  static double calculateAimAssist(
    double aimRatio, {
    ShotDifficulty difficulty = ShotDifficulty.medium,
  }) {
    if (aimRatio.abs() < difficulty.aimDeadzone) return 0.0;
    final double r = aimRatio.clamp(-0.80, 0.80);
    final double ramp = (r.abs() / 0.25).clamp(0.0, 1.0);
    final double softening = difficulty.aimSoftening;
    return r * (softening + (1.0 - softening) * ramp);
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
    ShotDifficulty difficulty = ShotDifficulty.medium,
  }) {
    final ref = solveReferenceVelocity(from: from, target: target);

    // Natural power curve: power affects both vertical and forward velocity.
    // Restrain vertical rise when over-powered (0.25x up to 1.12 max) so the ball
    // never rockets into or beyond the screen ceiling. Forward velocity retains
    // full dynamic range (up to 1.40x) so hard shots aggressively clank back rim / backboard.
    final powerScaleY = powerRatio >= 1.0
        ? (1.0 + (powerRatio - 1.0) * 0.25).clamp(1.0, 1.12)
        : (1.0 + (powerRatio - 1.0) * 0.50).clamp(0.35, 1.0);
    final powerScaleZ = (1.0 + (powerRatio - 1.0) * 0.55).clamp(0.25, 1.40);

    final vy = ref.y * powerScaleY;
    final vz = ref.z * powerScaleZ;

    // Lateral velocity based on flick angle:
    // ref.x perfectly aims for the center of the rim from any spawn offset.
    // calculateAimAssist smoothly scales lateral deviation with zero discontinuity.
    final lateralAim = calculateAimAssist(aimRatio, difficulty: difficulty);

    // Add the user's targeted lateral velocity to the baseline center-aimed reference
    final vx = ref.x + (lateralAim * 3.2);

    return Vector3(vx, vy, vz);
  }
}
