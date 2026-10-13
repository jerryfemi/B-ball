import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

import 'perspective_camera.dart';
import 'launch_solver.dart';

/// 3D point-mass basketball physics simulator featuring:
/// - Fixed 1/240s timestep accumulator for deterministic simulation
/// - Impulse-based contact model with restitution + Coulomb friction + spin coupling
/// - Exact 3D Torus Rim collision detection
/// - 3D Backboard vertical plane collision
/// - Frame-rate-independent exponential net drag
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
  bool isDeadBall = false;
  int bounceCount = 0;
  bool isSettled = false;
  double timeSinceLaunch = 0.0;

  // Fixed timestep accumulator
  double _accumulator = 0.0;
  static const double fixedDt = 1.0 / 240.0;

  // Hoop geometric dimensions in meters
  static final Vector3 rimCenter = Vector3(0.0, 3.05, 4.50);
  static const double rimRadius = 0.27; // Calibrated to match drawn front rim art (~0.32m in Forge units)
  static const double rimTubeRadius = 0.02; // 20mm steel tube

  // Backboard vertical plane in meters (matched 1:1 to visual art, 4.96m gives 19cm clearance behind rim)
  static const double backboardZ = 4.96;
  static const double backboardMinX = -0.72;
  static const double backboardMaxX = 0.72;
  static const double backboardMinY = 2.95;
  static const double backboardMaxY = 4.00;

  // Regulation shooter's square target bounds (centered at Y=3.30m, matching drawn 0.35m x 0.24m red box)
  static const double shootersSquareHalfWidth = 0.175;
  static const double shootersSquareMinY = 3.18;
  static const double shootersSquareMaxY = 3.42;

  // Nylon net bounds
  static const double netBottomY = 2.60;

  // Gymnasium room boundary constants (in meters, matching RoomGeometry)
  static const double wallZ = 5.25;
  static const double halfWidth = 3.75;
  static const double ceilingY = 6.50;

  // Cylindrical free-standing pole bounds
  static const double poleX = 0.0;
  static const double poleZ = 4.96;
  static const double poleRadius = 0.04;
  static const double poleMaxY = 3.05;

  final void Function(Vector3 impactPoint)? onWallImpact;
  final void Function({required bool isSwish, required bool isBankShot})? onScored;
  final void Function(double speed)? onRimImpact;
  final void Function(double speed)? onBackboardImpact;
  final void Function(double speed)? onFloorImpact;

  BallPhysics3D({
    Vector3? initialPos,
    this.radius = 0.125,
    this.pitch = 0.36,
    this.yaw = -0.42,
    this.onWallImpact,
    this.onScored,
    this.onRimImpact,
    this.onBackboardImpact,
    this.onFloorImpact,
  }) : pos = initialPos ?? Vector3(0.0, 0.25, 0.0),
       vel = Vector3.zero(),
       angularVel = Vector3.zero();

  /// Launches the basketball with 3D velocity [v] and physical backspin.
  void launch(Vector3 v, {double backspin = 12.0}) {
    vel = v.clone();
    angularVel = Vector3(-backspin.abs(), (v.x * 2.0).clamp(-8.0, 8.0), 0.0);
    isLaunched = true;
    passedThroughRim = false;
    hasClankedRim = false;
    hasBankedBackboard = false;
    isDeadBall = false;
    bounceCount = 0;
    isSettled = false;
    timeSinceLaunch = 0.0;
    _accumulator = 0.0;
  }

  /// Steps the 3D physics simulation forward by [dt] seconds
  /// using a fixed 1/240s timestep accumulator for deterministic physics.
  void update(double dt) {
    if (!isLaunched) return;

    // Always increment the lifecycle timer, even if the ball is settled on the floor
    timeSinceLaunch += dt;

    if (isSettled) return;

    // Fixed timestep accumulator: cap raw dt to prevent spiral of death on frame hitches
    _accumulator += dt.clamp(0.0, 0.05);
    while (_accumulator >= fixedDt) {
      _substep(fixedDt);
      _accumulator -= fixedDt;
      if (isSettled) break;
    }
  }

  // ---------------------------------------------------------------------------
  // Unified impulse-based contact resolution
  // ---------------------------------------------------------------------------

  /// Applies an impulse-based contact with restitution and Coulomb friction.
  ///
  /// [n] is the surface normal pointing away from the surface toward the ball.
  /// [e] is restitution (0 = perfectly inelastic, 1 = perfectly elastic).
  /// [mu] is Coulomb friction coefficient (tangential grip).
  ///
  /// Spin coupling: backspin naturally produces "kiss and drop" off back rim,
  /// front rim grazes roll in correctly, bank shots bounce at the physical
  /// angle of incidence — all without any scripted velocity overrides.
  void _contact(Vector3 n, {required double e, required double mu}) {
    final vn = vel.dot(n);
    if (vn >= 0) return; // Separating — no contact impulse needed

    // ── Normal impulse (unit-mass ball) ──
    final jn = -(1 + e) * vn;
    vel.addScaled(n, jn);

    // ── Friction impulse with spin coupling ──
    // rVec: vector from ball center to contact point (-radius along the normal)
    final rVec = n.scaled(-radius);

    // Surface velocity at contact point = translational vel + ω × r
    final omegaCrossR = Vector3.zero();
    angularVel.crossInto(rVec, omegaCrossR);
    final surf = vel + omegaCrossR;

    // Tangential slip: remove normal component from surface velocity
    final surfDotN = surf.dot(n);
    final slip = surf - n.scaled(surfDotN);
    final s = slip.length;

    if (s > 1e-4) {
      // Friction impulse capped by Coulomb limit
      // Thin hollow-shell sphere: 1/m + r²/I = 2.5 (since I = 2/3 mr²)
      final jt = math.min(mu * jn, s / 2.5);
      final t = slip.scaled(-1.0 / s); // Unit tangent opposing slip direction

      // Apply tangential impulse to translational velocity
      vel.addScaled(t, jt);

      // Apply tangential impulse to angular velocity: Δω = (r × t) * jt / I
      final rCrossT = Vector3.zero();
      rVec.crossInto(t, rCrossT);
      angularVel.addScaled(rCrossT, jt / (2.0 / 3.0 * radius * radius));
    }
  }

  // ---------------------------------------------------------------------------
  // Substep integration
  // ---------------------------------------------------------------------------

  void _substep(double dt) {
    // 1. Pure ballistic Newtonian gravity (zero in-flight drag to match LaunchSolver)
    vel.y -= LaunchSolver.gravity * dt;

    final prevY = pos.y;

    // 2. Position step
    pos.add(vel * dt);

    // 3. Spin-driven visual rotation (constant airborne ω in flight)
    if (pos.y > radius + 0.01) {
      pitch -= angularVel.x * dt * 0.8;
      yaw -= angularVel.y * dt * 0.8;
    }

    // 4. Rim Torus Collision Detection & Response
    _checkRimTorusCollision();
    _checkMountingBracketCollision();

    // 5. Backboard Plane Collision Detection & Response
    _checkBackboardCollision();

    // 6. Score Detection & Net Damping
    _checkScoreAndNet(prevY, dt);

    // 7. Cylindrical Pole Collision Detection & Response
    _checkPoleCollision();

    // 8. Solid Gymnasium Back Wall, Side Walls & Ceiling Colliders
    _checkBackWallCollision();
    _checkSideWallsCollision();
    _checkCeilingCollision();

    // 9. Hardwood Court Floor Collision (strictly on the court floor)
    _checkFloorCollision(dt);
  }

  // ---------------------------------------------------------------------------
  // Collision handlers (all using the unified _contact model)
  // ---------------------------------------------------------------------------

  /// Exact 3D Torus collision detection against the horizontal circular metal rim.
  /// One _contact() call replaces three separate scripted branches (front/back/side rim).
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
      final invDist = dist > 1e-5 ? 1.0 / dist : 0.0;
      final nx = dist > 1e-5 ? rx * invDist : 0.0;
      final ny = dist > 1e-5 ? ry * invDist : 1.0;
      final nz = dist > 1e-5 ? rz * invDist : 0.0;

      // Positional resolution to prevent clipping
      pos.x = qx + nx * (contactRadius + 0.001);
      pos.y = qy + ny * (contactRadius + 0.001);
      pos.z = qz + nz * (contactRadius + 0.001);

      // Unified contact: steel rim (e=0.60, μ=0.25)
      // Backspin "kiss and drop" on back rim emerges naturally from friction coupling.
      // Front rim grazes that should roll in DO roll in — the normal handles it.
      // Side rattles produce unique bounces based on contact geometry.
      final impactSpeed = vel.length;
      final n = Vector3(nx, ny, nz);
      _contact(n, e: 0.60, mu: 0.25);

      hasClankedRim = true;
      onRimImpact?.call(impactSpeed);
    }
  }

  /// Solid mounting flange connecting the back rim to the backboard faceplate.
  /// Forward-slanted deflector wedge strictly prevents balls from wedging or resting
  /// between the back rim and backboard.
  void _checkMountingBracketCollision() {
    const double bracketMinZ = 4.77;
    final double bracketMaxZ = backboardZ;
    if (pos.z + radius >= bracketMinZ && pos.z - radius <= bracketMaxZ) {
      if (pos.x.abs() <= 0.16 &&
          pos.y >= rimCenter.y - 0.05 &&
          pos.y <= rimCenter.y + 0.25) {
        if (vel.y < 0) {
          pos.y = rimCenter.y + 0.25 + 0.001;
          vel.y = math.max(-vel.y * 0.45, 0.35);
          vel.z = math.min(vel.z, -1.2);
        }
      }
    }
  }

  /// 3D Vertical Backboard collision detection and response.
  /// Features two-sided collision (front glass bank + rear structure deflection)
  /// to strictly prevent balls from phasing through the backboard into the hoop.
  void _checkBackboardCollision() {
    const double boardFrontZ = backboardZ;
    const double boardBackZ = backboardZ + 0.10;

    if (pos.z + radius >= boardFrontZ && pos.z - radius <= boardBackZ) {
      if (pos.x >= backboardMinX &&
          pos.x <= backboardMaxX &&
          pos.y >= backboardMinY &&
          pos.y <= backboardMaxY) {
        if (vel.z > 0) {
          // Front-face collision (incoming from player toward the backboard)
          pos.z = boardFrontZ - radius - 0.001;
          hasBankedBackboard = true;
          final impactSpeed = vel.length;

          // Check if hitting inside the regulation shooter's square
          final isShootersSquare = pos.x.abs() <= shootersSquareHalfWidth &&
              pos.y >= shootersSquareMinY &&
              pos.y <= shootersSquareMaxY;

          // Physical tempered-glass impulse contact (e=0.62, μ=0.12)
          final n = Vector3(0.0, 0.0, -1.0);
          _contact(n, e: 0.62, mu: 0.12);
          onBackboardImpact?.call(impactSpeed);

          if (isShootersSquare) {
            // Dynamic Bank Shot Guidance:
            // 1. Proportional lateral centering nudge
            vel.x -= pos.x * 1.5;
            // 2. Controlled vertical descent arc (prevents aggressive downward plummet)
            if (vel.y > 0.1) {
              vel.y = math.min(vel.y * 0.35, 0.05);
            } else {
              vel.y = math.max(vel.y - 0.15, -1.1);
            }
            // 3. Forward propulsion toward the hoop center (Z = 4.50m)
            vel.z = math.min(vel.z, -1.65);
          }
        } else if (vel.z < 0) {
          // Rear-face collision (ball is behind the backboard returning forward)
          // Solid board structure prevents phasing forward into the rim
          pos.z = boardBackZ + radius + 0.001;
          isDeadBall = true;
          final impactSpeed = vel.length;
          final n = Vector3(0.0, 0.0, 1.0);
          _contact(n, e: 0.40, mu: 0.30);
          onBackboardImpact?.call(impactSpeed);
        }
      }
    }
  }

  /// Scoring detection and frame-rate-independent nylon net descent damping.
  /// Exponential decay replaces per-substep multiplication for identical
  /// behavior at any framerate (60Hz, 120Hz, variable).
  void _checkScoreAndNet(double prevY, double dt) {
    final dx = pos.x - rimCenter.x;
    final dz = pos.z - rimCenter.z;
    final dXZ = math.sqrt(dx * dx + dz * dz);

    // Score recorded when ball descends through rim plane within inner opening.
    // Disallowed if ball is dead (e.g. rebounded off gym back wall or rear of backboard).
    if (!passedThroughRim &&
        !isDeadBall &&
        prevY > rimCenter.y &&
        pos.y <= rimCenter.y &&
        dXZ < rimRadius + 0.02 &&
        vel.y < 0) {
      passedThroughRim = true;
      final bool isSwish = !hasClankedRim && !hasBankedBackboard;
      final bool isBank = hasBankedBackboard;
      onScored?.call(isSwish: isSwish, isBankShot: isBank);
    }

    // Inside the net cylinder: frame-rate-independent exponential drag
    if (passedThroughRim &&
        pos.y >= netBottomY &&
        pos.y <= rimCenter.y &&
        dXZ < rimRadius * 1.3) {
      // Exponential decay ensures identical results at any framerate
      final dLateral = math.exp(-6.0 * dt);
      final dVertical = math.exp(-3.0 * dt);

      // Lateral: decay + gentle spring centering towards net axis
      vel.x = vel.x * dLateral + (rimCenter.x - pos.x) * 25.0 * dt;
      vel.z = vel.z * dLateral + (rimCenter.z - pos.z) * 25.0 * dt;

      // Vertical: smooth deceleration through nylon mesh
      vel.y *= dVertical;
    }
  }

  /// Cylindrical pole collision detection and response.
  void _checkPoleCollision() {
    if (pos.y <= poleMaxY && pos.y >= radius) {
      final dx = pos.x - poleX;
      final dz = pos.z - poleZ;
      final distXZ = math.sqrt(dx * dx + dz * dz);
      final contactDist = radius + poleRadius;
      if (distXZ < contactDist && distXZ > 1e-5) {
        final nx = dx / distXZ;
        final nz = dz / distXZ;
        pos.x = poleX + nx * (contactDist + 0.001);
        pos.z = poleZ + nz * (contactDist + 0.001);

        // Steel pole contact: normal pointing radially outward
        final n = Vector3(nx, 0.0, nz);
        _contact(n, e: 0.58, mu: 0.25);
      }
    }
  }

  /// Solid gymnasium brick back wall collision detection and response.
  /// Strictly prevents balls from penetrating into the brick wall (Z >= wallZ)
  /// and repels them back forward onto the court floor.
  void _checkBackWallCollision() {
    if (pos.z + radius >= wallZ) {
      pos.z = wallZ - radius - 0.001;
      isDeadBall = true; // Ball hit back wall: out of bounds / dead ball

      if (vel.z > 0) {
        onWallImpact?.call(Vector3(pos.x, pos.y, wallZ));
      }

      // Solid brick wall contact: normal pointing toward the player (-Z)
      // High masonry restitution (e=0.55) repels the ball back forward into the court
      final n = Vector3(0.0, 0.0, -1.0);
      _contact(n, e: 0.55, mu: 0.40);
    }
  }

  /// Solid gymnasium side walls collision detection and response.
  /// Repels wide shots inward toward the court center.
  void _checkSideWallsCollision() {
    if (pos.x + radius >= halfWidth) {
      pos.x = halfWidth - radius - 0.001;
      final n = Vector3(-1.0, 0.0, 0.0);
      _contact(n, e: 0.55, mu: 0.40);
    } else if (pos.x - radius <= -halfWidth) {
      pos.x = -halfWidth + radius + 0.001;
      final n = Vector3(1.0, 0.0, 0.0);
      _contact(n, e: 0.55, mu: 0.40);
    }
  }

  /// Solid gymnasium overhead ceiling boundary collider.
  /// Strictly prevents extreme upward ricochets or trajectories from escaping the court.
  void _checkCeilingCollision() {
    if (pos.y + radius >= ceilingY) {
      pos.y = ceilingY - radius - 0.001;
      final n = Vector3(0.0, -1.0, 0.0);
      _contact(n, e: 0.35, mu: 0.20);
    }
  }

  /// Hardwood court floor bouncing (impulse-based) and rolling friction settling.
  /// Restricted strictly to the court floor area (Z <= wallZ and |X| <= halfWidth).
  void _checkFloorCollision(double dt) {
    // Court floor only exists inside the gym boundaries in front of the back wall
    if (pos.z > wallZ || pos.x.abs() > halfWidth) return;

    if (pos.y <= radius) {
      pos.y = radius;

      if (vel.y < 0) {
        final impactSpeed = vel.y.abs();
        if (impactSpeed > 0.35) {
          bounceCount++;
          // Floor contact: normal pointing up, hardwood restitution + high friction
          final n = Vector3(0, 1, 0);
          _contact(n, e: 0.62, mu: 0.50);
          onFloorImpact?.call(impactSpeed);
        } else {
          // Very low bounce energy — transition to rolling and settling
          vel.y = 0.0;
          // Frame-rate-independent rolling friction (exponential decay)
          final d = math.exp(-3.0 * dt);
          vel.x *= d;
          vel.z *= d;

          // Physical rolling without slipping: angular rotation coupled to ground translation
          pitch += (vel.z / radius) * dt * 0.85;
          yaw += (vel.x / radius) * dt * 0.85;

          if (vel.x.abs() < 0.04 && vel.z.abs() < 0.04) {
            vel.setZero();
            angularVel.setZero();
            isSettled = true;
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Projection & rendering helpers (unchanged)
  // ---------------------------------------------------------------------------

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
    // Do not draw floor shadow if the ball is outside the court floor
    if (pos.z > wallZ || pos.x.abs() > halfWidth) return;

    final heightAboveFloor = (pos.y - radius).clamp(0.0, 8.0);
    final floorScale = camera.scaleAtDepth(pos.z);
    final shadowScreenPos = camera.projectCoords(pos.x, 0.0, pos.z);

    final baseRadius = radius * camera.pixelsPerMeter * floorScale;
    final shadowAlpha = ((0.55 / (1.0 + heightAboveFloor * 0.45)) * opacity)
        .clamp(0.0, 0.55);

    if (shadowAlpha <= 0.01) return;

    final shadowScale = 1.0 + heightAboveFloor * 0.15;
    final blurRadius = (baseRadius * 0.15 + heightAboveFloor * 1.6).clamp(
      1.5,
      22.0,
    );

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

  /// Renders the brick back wall contact shadow at (pos.x, shadowY, wallZ)
  /// as the ball approaches within ~0.70m of the back wall plane.
  void renderWallShadow(
    Canvas canvas,
    PerspectiveCamera3D camera, {
    double opacity = 1.0,
  }) {
    if (pos.x.abs() > halfWidth) return;
    final distToWall = (wallZ - (pos.z + radius)).clamp(0.0, 0.70);
    if (distToWall >= 0.70) return;

    final wallProximity = 1.0 - (distToWall / 0.70);
    final shadowAlpha = (wallProximity * 0.60 * opacity).clamp(0.0, 0.60);
    if (shadowAlpha <= 0.01) return;

    // Overhead floodlight casts shadow slightly downward on the vertical wall
    final shadowY = pos.y - (0.04 + distToWall * 0.08);
    final shadowScreenPos = camera.projectCoords(pos.x, shadowY, wallZ);

    final wallScale = camera.scaleAtDepth(wallZ);
    final baseRadius = radius * camera.pixelsPerMeter * wallScale;

    final shadowSpread = 1.0 + (1.0 - wallProximity) * 0.35;
    final blurRadius = (baseRadius * 0.12 + (1.0 - wallProximity) * 12.0).clamp(
      1.5,
      16.0,
    );

    final shadowWidth = baseRadius * 2.0 * shadowSpread;
    final shadowHeight = baseRadius * 2.0 * shadowSpread;

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
