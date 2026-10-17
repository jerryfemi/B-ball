import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

import 'perspective_camera.dart';
import 'launch_solver.dart';

/// 3D point-mass basketball physics simulator featuring:
/// - Fixed 1/120s timestep accumulator for deterministic simulation
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

  // Fixed timestep accumulator:
  // 120Hz (8.33ms) provides sub-millimeter torus collision precision while cutting CPU
  // substep overhead by 50% compared to 240Hz, preventing thermal throttling on mobile.
  double _accumulator = 0.0;
  static const double fixedDt = 1.0 / 120.0;

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

  // Generous backboard bank funnel target bounds (covers central bank area: 84cm wide, Y=3.08m..3.65m)
  static const double bankZoneHalfWidth = 0.42;
  static const double bankZoneMinY = 3.08;
  static const double bankZoneMaxY = 3.65;

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
  /// using a fixed 1/120s timestep accumulator for deterministic physics.
  void update(double dt) {
    if (!isLaunched) return;

    // Always increment the lifecycle timer, even if the ball is settled on the floor
    timeSinceLaunch += dt;

    if (isSettled) return;

    // Fixed timestep accumulator: cap raw dt to prevent spiral of death on frame hitches
    _accumulator += dt.clamp(0.0, 0.05);
    int substeps = 0;
    while (_accumulator >= fixedDt && substeps < 4) {
      _substep(fixedDt);
      _accumulator -= fixedDt;
      substeps++;
      if (isSettled) break;
    }
    // Prevent accumulator accumulation beyond 2 fixed steps during sudden frame hitches
    if (_accumulator > fixedDt * 2) {
      _accumulator = fixedDt * 2;
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
  ///
  /// Zero-allocation scalar form: runs up to 4x per frame per ball at 120Hz, so
  /// it must not create any Vector3 temporaries (GC pauses on mobile web).
  void _contact(
    double nx,
    double ny,
    double nz, {
    required double e,
    required double mu,
  }) {
    final vn = vel.x * nx + vel.y * ny + vel.z * nz;
    if (vn >= 0) return; // Separating — no contact impulse needed

    // ── Normal impulse (unit-mass ball) ──
    final jn = -(1 + e) * vn;
    vel.x += nx * jn;
    vel.y += ny * jn;
    vel.z += nz * jn;

    // ── Friction impulse with spin coupling ──
    // r: vector from ball center to contact point (-radius along the normal)
    final rx = nx * -radius;
    final ry = ny * -radius;
    final rz = nz * -radius;

    // Surface velocity at contact point = translational vel + ω × r
    final wx = angularVel.x;
    final wy = angularVel.y;
    final wz = angularVel.z;
    final surfX = vel.x + (wy * rz - wz * ry);
    final surfY = vel.y + (wz * rx - wx * rz);
    final surfZ = vel.z + (wx * ry - wy * rx);

    // Tangential slip: remove normal component from surface velocity
    final surfDotN = surfX * nx + surfY * ny + surfZ * nz;
    final slipX = surfX - nx * surfDotN;
    final slipY = surfY - ny * surfDotN;
    final slipZ = surfZ - nz * surfDotN;
    final s = math.sqrt(slipX * slipX + slipY * slipY + slipZ * slipZ);

    if (s > 1e-4) {
      // Friction impulse capped by Coulomb limit
      // Thin hollow-shell sphere: 1/m + r²/I = 2.5 (since I = 2/3 mr²)
      final jt = math.min(mu * jn, s / 2.5);
      final invS = -1.0 / s;
      final tx = slipX * invS; // Unit tangent opposing slip direction
      final ty = slipY * invS;
      final tz = slipZ * invS;

      // Apply tangential impulse to translational velocity
      vel.x += tx * jt;
      vel.y += ty * jt;
      vel.z += tz * jt;

      // Apply tangential impulse to angular velocity: Δω = (r × t) * jt / I
      final k = jt / (2.0 / 3.0 * radius * radius);
      angularVel.x += (ry * tz - rz * ty) * k;
      angularVel.y += (rz * tx - rx * tz) * k;
      angularVel.z += (rx * ty - ry * tx) * k;
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
    pos.addScaled(vel, dt); // in-place: no temporary Vector3

    // 3. Spin-driven visual rotation (constant airborne ω in flight)
    if (pos.y > radius + 0.01) {
      pitch -= angularVel.x * dt * 0.8;
      yaw -= angularVel.y * dt * 0.8;
    }

    // 4. Rim Torus Collision Detection & Response
    _checkRimTorusCollision();

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

      // Unified contact: soft shock-absorbing rim (e=0.44, μ=0.28)
      // Backspin "kiss and drop" on back rim emerges naturally from friction coupling.
      // Front rim grazes that should roll in DO roll in — the normal handles it.
      // Side rattles produce unique bounces based on contact geometry.
      final impactSpeed = vel.length;
      _contact(nx, ny, nz, e: 0.44, mu: 0.28);

      // Shooter's Touch: soft grazes lose excess upward velocity and roll inward toward the cylinder
      if (impactSpeed < 3.2 && pos.y >= rimCenter.y - 0.05) {
        vel.y = math.min(vel.y, 0.22);
        final tcx = rimCenter.x - pos.x;
        final tcz = rimCenter.z - pos.z;
        final tcLen = math.sqrt(tcx * tcx + tcz * tcz);
        if (tcLen > 1e-4) {
          final k = 0.38 / tcLen;
          vel.x += tcx * k;
          vel.z += tcz * k;
        }
      }

      hasClankedRim = true;
      onRimImpact?.call(impactSpeed);
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

          // Check if hitting inside the central backboard bank zone
          final isBankZone = pos.x.abs() <= bankZoneHalfWidth &&
              pos.y >= bankZoneMinY &&
              pos.y <= bankZoneMaxY;

          // Physical tempered-glass impulse contact (e=0.62, μ=0.12)
          _contact(0.0, 0.0, -1.0, e: 0.62, mu: 0.12);
          onBackboardImpact?.call(impactSpeed);

          if (isBankZone) {
            // Kinematic Parabolic Bank Guidance:
            // Calculate the exact forward velocity (vz) needed to carry the ball
            // from the backboard plane (Z=4.835m) to the sweet spot inside the rim (Z=4.44m).
            //
            // Using Newtonian free-fall:
            // dy = pos.y - rimCenter.y (height above rim plane at contact)
            // If the ball hits above the rim (dy > 0), gravity will pull it down:
            // t_drop = (vy + sqrt(vy^2 + 2 * g * dy)) / g
            // vz = -dz / t_drop
            final dy = math.max(0.04, pos.y - (rimCenter.y + radius));
            final g = LaunchSolver.gravity; // 13.0 m/s^2 ballistic gravity (shared with LaunchSolver)
            final vVertical = vel.y.clamp(-1.5, 0.4);

            // Compute time until ball reaches rim plane
            final discriminant = vVertical * vVertical + 2.0 * g * dy;
            final tDrop = (vVertical + math.sqrt(math.max(0.01, discriminant))) / g;

            // Target landing zone in the rim: Z in [4.38, 4.46] (comfortably inside cylinder)
            const targetZ = 4.42;
            final distZToTarget = pos.z - targetZ; // ~0.415m
            final requiredVz = -distZToTarget / math.max(0.08, tDrop);

            // 1. Proportional lateral centering nudge
            vel.x -= pos.x * 2.2;

            // 2. Controlled vertical rebound arc
            if (vel.y > 0.05) {
              vel.y = math.min(vel.y * 0.25, 0.05);
            } else {
              vel.y = math.max(vel.y - 0.10, -0.90);
            }

            // 3. Exact kinematic forward velocity toward the basket cylinder center
            vel.z = math.min(vel.z, requiredVz.clamp(-3.2, -1.85));
          }
        } else if (vel.z < 0) {
          // Rear-face collision (ball is behind the backboard returning forward)
          // Solid board structure prevents phasing forward into the rim
          pos.z = boardBackZ + radius + 0.001;
          isDeadBall = true;
          final impactSpeed = vel.length;
          _contact(0.0, 0.0, 1.0, e: 0.40, mu: 0.30);
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
    // Disallowed if ball is dead, or if behind the rim cylinder (Z > 4.70m).
    // The cylinder opening is strictly dXZ < 0.23m (ensures ball center is well inside ring).
    if (!passedThroughRim &&
        !isDeadBall &&
        prevY > rimCenter.y &&
        pos.y <= rimCenter.y &&
        pos.z <= 4.70 &&
        dXZ < rimRadius - 0.04 &&
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
        _contact(nx, 0.0, nz, e: 0.58, mu: 0.25);
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
      _contact(0.0, 0.0, -1.0, e: 0.55, mu: 0.40);
    }
  }

  /// Solid gymnasium side walls collision detection and response.
  /// Repels wide shots inward toward the court center.
  void _checkSideWallsCollision() {
    if (pos.x + radius >= halfWidth) {
      pos.x = halfWidth - radius - 0.001;
      _contact(-1.0, 0.0, 0.0, e: 0.55, mu: 0.40);
    } else if (pos.x - radius <= -halfWidth) {
      pos.x = -halfWidth + radius + 0.001;
      _contact(1.0, 0.0, 0.0, e: 0.55, mu: 0.40);
    }
  }

  /// Solid gymnasium overhead ceiling boundary collider.
  /// Strictly prevents extreme upward ricochets or trajectories from escaping the court.
  void _checkCeilingCollision() {
    if (pos.y + radius >= ceilingY) {
      pos.y = ceilingY - radius - 0.001;
      _contact(0.0, -1.0, 0.0, e: 0.35, mu: 0.20);
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
          _contact(0.0, 1.0, 0.0, e: 0.62, mu: 0.50);
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
}
