import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../archery_constants.dart';
import 'wind_model.dart';

/// Full 3D Arrow Physics simulation with 240 Hz fixed-step Euler integration.
///
/// Features:
/// - Semi-implicit Euler integration with quadratic aerodynamic drag and gravity.
/// - Continuous plane-crossing hit detection (no tunneling at 60+ m/s).
/// - Ground collision (y <= 0) and backstop boundary (z >= D + 3.0).
/// - Dynamic visual orientation: flight pitch/yaw + archer's paradox wobble.
/// - Impact penetration and tail quiver damped oscillation.
/// - Zero per-substep allocations.
class ArrowPhysics3D {
  // --- 3D Position & Velocity ---
  final Vector3 pos = Vector3.zero();
  final Vector3 vel = Vector3.zero();
  final Vector3 prevPos = Vector3.zero();

  // --- Flight Timing & Substep Accumulator ---
  double timeSinceRelease = 0.0;
  double _accumulator = 0.0;
  bool inFlight = false;
  bool stuck = false;
  bool hitGround = false;
  bool hitBackstop = false;

  // --- Target & Collision Parameters ---
  double targetDistance = ArcheryK.distanceM;

  // --- Hit Point Results ---
  final Vector3 hitPoint = Vector3.zero();
  double hitLocalX = 0.0; // Horizontal offset from target center (meters)
  double hitLocalY = 0.0; // Vertical offset from target center (meters)
  bool hitBoss = false;
  double penetrationDepth = 0.0;

  // --- Visual Orientation & Wobble ---
  double pitch = 0.0; // Radians
  double yaw = 0.0;   // Radians
  double wobbleYaw = 0.0; // Archer's paradox oscillation

  // --- Wind Model ---
  WindModel? windModel;

  /// Multiplier on wind acceleration for this flight (see [ArcheryK.windScaleFor]).
  double windScale = 1.0;

  /// Resets and launches the arrow with given orientation and speed.
  void launch({
    Vector3? startPos,
    double startX = 0.0,
    double startY = ArcheryK.launchY,
    double startZ = ArcheryK.launchZ,
    required double launchYaw,
    required double launchPitch,
    required double speed,
    required double targetDist,
    WindModel? windModel,
    double windScale = 1.0,
  }) {
    this.windModel = windModel;
    this.windScale = windScale;
    targetDistance = targetDist;

    if (startPos != null) {
      pos.setFrom(startPos);
      prevPos.setFrom(startPos);
    } else {
      pos.setValues(startX, startY, startZ);
      prevPos.setValues(startX, startY, startZ);
    }

    // Spherical to Cartesian velocity vector
    final double cosP = math.cos(launchPitch);
    final double sinP = math.sin(launchPitch);
    final double cosY = math.cos(launchYaw);
    final double sinY = math.sin(launchYaw);

    vel.x = speed * cosP * sinY;
    vel.y = speed * sinP;
    vel.z = speed * cosP * cosY;

    timeSinceRelease = 0.0;
    _accumulator = 0.0;
    inFlight = true;
    stuck = false;
    hitGround = false;
    hitBackstop = false;
    hitBoss = false;
    penetrationDepth = 0.0;

    _updateOrientation();
  }

  /// Steps physics forward by [frameDt] using fixed 240 Hz sub-steps.
  void update(double frameDt) {
    if (!inFlight) return;

    _accumulator += frameDt.clamp(0.0, 0.05);
    int steps = 0;

    while (_accumulator >= ArcheryK.fixedDt && steps < ArcheryK.maxSubstepsPerFrame) {
      _substep(ArcheryK.fixedDt);
      _accumulator -= ArcheryK.fixedDt;
      steps++;
      if (!inFlight) break;
    }

    if (_accumulator > ArcheryK.fixedDt * 2.0) {
      _accumulator = ArcheryK.fixedDt * 2.0;
    }

    _updateOrientation();
  }

  void _substep(double dt) {
    prevPos.setFrom(pos);
    timeSinceRelease += dt;

    // 1. Wind lateral and along-track acceleration
    final double windLateral = (windModel?.getLateralAccel(timeSinceRelease) ?? 0.0) * windScale;
    final double windAlong = (windModel?.getAlongTrackAccel(timeSinceRelease) ?? 0.0) * windScale;

    // 2. Relative velocity to air for quadratic drag
    final double vRelX = vel.x;
    final double vRelY = vel.y;
    final double vRelZ = vel.z;
    final double vRel = math.sqrt(vRelX * vRelX + vRelY * vRelY + vRelZ * vRelZ);

    // 3. Acceleration: Gravity + Quadratic Drag + Wind
    final double dragFactor = ArcheryK.dragK * vRel;
    final double ax = -dragFactor * vRelX + windLateral;
    final double ay = -dragFactor * vRelY - ArcheryK.gravity;
    final double az = -dragFactor * vRelZ + windAlong;

    // 4. Semi-implicit Euler integration (Velocity first, then Position)
    vel.x += ax * dt;
    vel.y += ay * dt;
    vel.z += az * dt;

    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
    pos.z += vel.z * dt;

    // 5. Hit Detection: Target Plane Crossing at Z = targetDistance
    if (prevPos.z < targetDistance && pos.z >= targetDistance) {
      final double dz = pos.z - prevPos.z;
      final double f = dz != 0.0 ? (targetDistance - prevPos.z) / dz : 1.0;

      final double hx = prevPos.x + (pos.x - prevPos.x) * f;
      final double hy = prevPos.y + (pos.y - prevPos.y) * f;

      hitPoint.setValues(hx, hy, targetDistance);
      hitLocalX = hx - 0.0;
      hitLocalY = hy - ArcheryK.targetCenterY;

      // Check if point hits within the straw boss rectangle
      final double halfW = ArcheryK.bossWidth * 0.5;
      final double halfH = ArcheryK.bossHeight * 0.5;

      if (hitLocalX.abs() <= halfW && hitLocalY.abs() <= halfH) {
        _onBossHit();
        return;
      }
    }

    // 6. Ground Collision at y <= 0
    if (prevPos.y > 0.0 && pos.y <= 0.0) {
      final double dy = pos.y - prevPos.y;
      final double f = dy != 0.0 ? (0.0 - prevPos.y) / dy : 1.0;

      hitPoint.x = prevPos.x + (pos.x - prevPos.x) * f;
      hitPoint.y = 0.0;
      hitPoint.z = prevPos.z + (pos.z - prevPos.z) * f;

      inFlight = false;
      stuck = true;
      hitGround = true;
      return;
    }

    // 7. Backstop boundary at Z >= targetDistance + 3.0m
    if (pos.z >= targetDistance + 3.0) {
      hitPoint.setFrom(pos);
      inFlight = false;
      stuck = true;
      hitBackstop = true;
      return;
    }
  }

  void _onBossHit() {
    inFlight = false;
    stuck = true;
    hitBoss = true;

    // Penetrate arrow slightly into boss (0.06m to 0.12m based on impact speed)
    final double currentSpeed = vel.length;
    penetrationDepth = (0.06 + (currentSpeed / ArcheryK.fullDrawSpeed) * 0.06)
        .clamp(0.04, ArcheryK.bossDepth * 0.8);

    // Freeze arrow position at hit point with penetration
    pos.x = hitPoint.x;
    pos.y = hitPoint.y;
    pos.z = hitPoint.z + penetrationDepth;
  }

  void _updateOrientation() {
    // Flight direction angles
    final double horizSpeed = math.sqrt(vel.x * vel.x + vel.z * vel.z);
    pitch = math.atan2(vel.y, horizSpeed);
    yaw = math.atan2(vel.x, vel.z);

    // Archer's Paradox Wobble (Visual only during flight)
    // wobbleYaw = A * exp(-t / τ) * sin(2π * f * t), A = 2°, f = 12 Hz, τ = 0.15s
    if (inFlight) {
      const double a = 2.0 * math.pi / 180.0;
      wobbleYaw = a *
          math.exp(-timeSinceRelease / 0.15) *
          math.sin(2.0 * math.pi * 12.0 * timeSinceRelease);
    } else {
      wobbleYaw = 0.0;
    }
  }
}
