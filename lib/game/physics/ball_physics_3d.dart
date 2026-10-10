import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

import 'perspective_camera.dart';
import 'launch_solver.dart';

/// 3D point-mass basketball physics simulator featuring:
/// - Analytic ballistic motion with realistic gravity and drag
/// - Exact 3D Torus Rim collision detection and physical rebound resolution
/// - 3D Backboard vertical plane collision
/// - Nylon net soft swish damping and score detection
/// - Hardwood court floor bouncing and rolling
/// - Continuous floor drop shadow projected on the hardwood court
class BallPhysics3D {
  // Physical state in 3D world meters (Floor Y = 0, Upwards = +Y, Forward = +Z)
  Vector3 pos;
  Vector3 vel;
  Vector3 angularVel;

  // Ball radius in meters (regulation basketball ~ 0.125m)
  final double radius;

  // 3D rotation angles for FragmentShader (pitch & yaw)
  double pitch;
  double yaw;

  // Simulation state flags
  bool isLaunched = false;
  bool passedThroughRim = false;
  bool hasClankedRim = false;
  bool hasBankedBackboard = false;
  int bounceCount = 0;
  bool isSettled = false;
  double timeSinceLaunch = 0.0;

  // Hoop geometric dimensions in meters
  static final Vector3 rimCenter = Vector3(0.0, 3.05, 4.50);
  static const double rimRadius = 0.23; // Inner diameter 0.46m
  static const double rimTubeRadius = 0.02; // 20mm steel tube

  // Backboard vertical plane in meters
  static const double backboardZ = 4.85;
  static const double backboardMinX = -0.90;
  static const double backboardMaxX = 0.90;
  static const double backboardMinY = 2.70;
  static const double backboardMaxY = 3.85;

  // Nylon net bounds
  static const double netBottomY = 2.60;

  BallPhysics3D({
    Vector3? initialPos,
    this.radius = 0.125,
    this.pitch = 0.36,
    this.yaw = -0.42,
  })  : pos = initialPos ?? Vector3(0.0, 0.25, 0.0),
        vel = Vector3.zero(),
        angularVel = Vector3.zero();

  /// Launches the basketball with 3D velocity [v] and backspin.
  void launch(Vector3 v, {double backspin = 12.0}) {
    vel = v.clone();
    angularVel = Vector3(backspin, (v.x * 2.0).clamp(-8.0, 8.0), 0.0);
    isLaunched = true;
    passedThroughRim = false;
    hasClankedRim = false;
    hasBankedBackboard = false;
    bounceCount = 0;
    isSettled = false;
    timeSinceLaunch = 0.0;
  }

  /// Steps the 3D physics simulation forward by [dt] seconds using substep integration.
  void update(double dt) {
    if (!isLaunched) return;

    // Always increment the lifecycle timer, even if the ball is settled on the floor
    timeSinceLaunch += dt;

    if (isSettled) return;

    // Substep integration (4 substeps per frame) for robust collision handling
    const int substeps = 4;
    final subDt = dt / substeps;

    for (int i = 0; i < substeps; i++) {
      _substep(subDt);
      if (isSettled) break;
    }
  }

  void _substep(double dt) {
    // 1. Gravity and aerodynamic drag
    vel.y -= LaunchSolver.gravity * dt;
    vel.scale(1.0 - 0.05 * dt);

    final prevY = pos.y;

    // 2. Position step
    pos.add(vel * dt);

    // 3. Realistic spin orientation updates
    pitch -= vel.y * dt * 0.14 + angularVel.x * dt * 0.8;
    yaw -= vel.x * dt * 0.18 + angularVel.y * dt * 0.8;

    // 4. Rim Torus Collision Detection & Response
    _checkRimTorusCollision();

    // 5. Backboard Plane Collision Detection & Response
    _checkBackboardCollision();

    // 6. Score Detection & Net Damping
    _checkScoreAndNet(prevY);

    // 7. Hardwood Court Floor Collision
    _checkFloorCollision();
  }

  /// Exact 3D Torus collision detection against the horizontal circular metal rim.
  void _checkRimTorusCollision() {
    final dx = pos.x - rimCenter.x;
    final dz = pos.z - rimCenter.z;
    final dXZ = math.sqrt(dx * dx + dz * dz);

    if (dXZ < 1e-5) return;

    // Nearest point on the rim circle centerline
    final qx = rimCenter.x + rimRadius * (dx / dXZ);
    final qy = rimCenter.y;
    final qz = rimCenter.z + rimRadius * (dz / dXZ);

    // Distance vector from rim centerline to ball center
    final rx = pos.x - qx;
    final ry = pos.y - qy;
    final rz = pos.z - qz;
    final dist = math.sqrt(rx * rx + ry * ry + rz * rz);

    final contactRadius = radius + rimTubeRadius;

    if (dist < contactRadius) {
      // Normal pointing away from rim metal toward ball
      final nx = dist > 1e-5 ? rx / dist : 0.0;
      final ny = dist > 1e-5 ? ry / dist : 1.0;
      final nz = dist > 1e-5 ? rz / dist : 0.0;

      // Positional resolution to prevent clipping
      pos.x = qx + nx * (contactRadius + 0.001);
      pos.y = qy + ny * (contactRadius + 0.001);
      pos.z = qz + nz * (contactRadius + 0.001);

      // Normal velocity component
      final vn = vel.x * nx + vel.y * ny + vel.z * nz;

      // Only resolve if ball is moving into the rim surface
      if (vn < 0) {
        final normalVx = vn * nx;
        final normalVy = vn * ny;
        final normalVz = vn * nz;

        final tangentVx = vel.x - normalVx;
        final tangentVy = vel.y - normalVy;
        final tangentVz = vel.z - normalVz;

        // Determine which part of the rim was contacted
        final isBackRim = qz > rimCenter.z + 0.03;
        final isFrontRim = qz < rimCenter.z - 0.03;
        final isDescending = vel.y < 0;

        if (isBackRim && isDescending) {
          // Authentic "Shooter's Touch": backspin absorbs forward momentum on the back iron
          // and pulls the ball downward through the net cylinder
          vel.x = -normalVx * 0.28 + tangentVx * 0.60;
          vel.y = -normalVy * 0.32 + tangentVy * 0.55;
          vel.z = -normalVz * 0.28 + tangentVz * 0.60;
          if (vel.y > -1.2) vel.y = -1.2; // Soft downward guide into rim
          angularVel.x *= 0.4;
        } else if (isFrontRim && isDescending) {
          // Front iron clank: firm upward/backward deflection
          vel.x = -0.65 * normalVx + 0.75 * tangentVx;
          vel.y = (vel.y.abs() * 0.65).clamp(1.5, 4.5); // Audible upward clank!
          vel.z = -vel.z.abs() * 0.55; // Pushes back towards court
          hasClankedRim = true;
          angularVel.x *= 0.6;
        } else {
          // Side rims (rattle) or ascending collision:
          vel.x = -0.68 * normalVx + 0.80 * tangentVx;
          vel.y = -0.68 * normalVy + 0.80 * tangentVy;
          vel.z = -0.68 * normalVz + 0.80 * tangentVz;
          hasClankedRim = true;
          angularVel.x *= 0.6;
          angularVel.y += (tangentVx * 4.0).clamp(-10.0, 10.0);
        }
      }
    }
  }

  /// 3D Vertical Backboard collision detection & rebound.
  void _checkBackboardCollision() {
    if (pos.z + radius >= backboardZ && pos.z - radius <= backboardZ + 0.12) {
      if (pos.x >= backboardMinX &&
          pos.x <= backboardMaxX &&
          pos.y >= backboardMinY &&
          pos.y <= backboardMaxY) {
        if (vel.z > 0) {
          pos.z = backboardZ - radius - 0.001;
          hasBankedBackboard = true;

          // Shooter's square area on backboard: X in [-0.40, 0.40], Y in [3.10, 3.65]
          final isShootersSquare = pos.x.abs() <= 0.40 &&
              pos.y >= 3.10 &&
              pos.y <= 3.65;

          if (isShootersSquare) {
            // Authentic bank shot: glass absorbs forward energy and guides gently down into the hoop opening
            vel.z = -1.15; // Soft forward travel back towards rim center (Z_rim = 4.50m)
            vel.y = -2.2;  // Downward descent towards rim opening (Y_rim = 3.05m)
            vel.x = -pos.x * 1.5; // Natural center pull towards rim center
            angularVel.x *= 0.5;
          } else {
            // Outside target square: firm miss rebound
            vel.z = -vel.z * 0.55;
            vel.x *= 0.80;
            vel.y *= 0.80;
            angularVel.x *= 0.7;
          }
        }
      }
    }
  }

  /// Scoring detection and soft cotton net descent damping.
  void _checkScoreAndNet(double prevY) {
    final dx = pos.x - rimCenter.x;
    final dz = pos.z - rimCenter.z;
    final dXZ = math.sqrt(dx * dx + dz * dz);

    // Score recorded when ball descends through rim plane within inner opening
    if (!passedThroughRim &&
        prevY > rimCenter.y &&
        pos.y <= rimCenter.y &&
        dXZ < rimRadius + 0.02 &&
        vel.y < 0) {
      passedThroughRim = true;
    }

    // Inside the net cylinder: gentle centering and deceleration
    if (passedThroughRim &&
        pos.y >= netBottomY &&
        pos.y <= rimCenter.y &&
        dXZ < rimRadius * 1.3) {
      vel.x *= 0.88;
      vel.z = (rimCenter.z - pos.z) * 1.8; // Guides cleanly down through center of net!
      if (vel.y < -2.6) {
        vel.y = -2.6; // Soft cushion through nylon mesh
      }
    }
  }

  /// Hardwood court floor bouncing and rolling settling.
  void _checkFloorCollision() {
    if (pos.y <= radius) {
      pos.y = radius;

      if (vel.y < 0) {
        if (vel.y.abs() > 0.35) {
          bounceCount++;
          // Hardwood floor restitution e = 0.62
          vel.y = -vel.y * 0.62;
          vel.x *= 0.80;
          vel.z *= 0.80;
          angularVel.scale(0.70);
        } else {
          vel.y = 0.0;
          vel.x *= 0.88;
          vel.z *= 0.88;
          if (vel.x.abs() < 0.04 && vel.z.abs() < 0.04) {
            vel.setZero();
            angularVel.setZero();
            isSettled = true;
          }
        }
      }
    }
  }

  /// Computes the projected 2D screen position in pixels.
  Offset getScreenPosition(PerspectiveCamera3D camera) {
    return camera.project(pos);
  }

  /// Computes the projected 2D screen radius in pixels.
  double getScreenRadius(PerspectiveCamera3D camera) {
    return radius * camera.pixelsPerMeter * camera.scaleAtDepth(pos.z);
  }

  /// Renders the continuous hardwood floor drop shadow at (pos.x, 0, pos.z).
  void renderFloorShadow(
    Canvas canvas,
    PerspectiveCamera3D camera, {
    double opacity = 1.0,
  }) {
    final heightAboveFloor = (pos.y - radius).clamp(0.0, 8.0);
    final floorScale = camera.scaleAtDepth(pos.z);
    final shadowScreenPos = camera.projectCoords(pos.x, 0.0, pos.z);

    final baseRadius = radius * camera.pixelsPerMeter * floorScale;
    final shadowAlpha =
        ((0.55 / (1.0 + heightAboveFloor * 0.45)) * opacity).clamp(0.0, 0.55);

    if (shadowAlpha <= 0.01) return;

    final shadowScale = 1.0 + heightAboveFloor * 0.15;
    final blurRadius =
        (baseRadius * 0.15 + heightAboveFloor * 1.6).clamp(1.5, 22.0);

    final shadowWidth = baseRadius * 2.2 * shadowScale;
    final shadowHeight = shadowWidth * 0.38; // Perspective flattening on floor

    final shadowPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    final shadowRect = Rect.fromCenter(
      center: shadowScreenPos,
      width: shadowWidth,
      height: shadowHeight,
    );

    canvas.drawOval(shadowRect, shadowPaint);
  }
}
