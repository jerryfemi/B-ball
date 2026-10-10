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
  int bounceCount = 0;
  bool isSettled = false;
  double timeSinceLaunch = 0.0;

  // Fixed timestep accumulator
  double _accumulator = 0.0;
  static const double fixedDt = 1.0 / 240.0;

  // Hoop geometric dimensions in meters
  static final Vector3 rimCenter = Vector3(0.0, 3.05, 4.50);
  static const double rimRadius = 0.23; // Inner diameter 0.46m
  static const double rimTubeRadius = 0.02; // 20mm steel tube

  // Backboard vertical plane in meters (tightened to match visual art)
  static const double backboardZ = 4.85;
  static const double backboardMinX = -0.475;
  static const double backboardMaxX = 0.475;
  static const double backboardMinY = 3.00;
  static const double backboardMaxY = 3.63;

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
    // 1. Gravity and aerodynamic drag
    vel.y -= LaunchSolver.gravity * dt;
    vel.scale(1.0 - 0.05 * dt);

    final prevY = pos.y;

    // 2. Position step
    pos.add(vel * dt);

    // 3. Spin-driven visual rotation (constant ω in flight — no velocity coupling)
    pitch -= angularVel.x * dt * 0.8;
    yaw -= angularVel.y * dt * 0.8;

    // 4. Rim Torus Collision Detection & Response
    _checkRimTorusCollision();

    // 5. Backboard Plane Collision Detection & Response
    _checkBackboardCollision();

    // 6. Score Detection & Net Damping
    _checkScoreAndNet(prevY, dt);

    // 7. Hardwood Court Floor Collision
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
      final n = Vector3(nx, ny, nz);
      _contact(n, e: 0.60, mu: 0.25);

      hasClankedRim = true;
    }
  }

  /// 3D Vertical Backboard glass collision using impulse-based contact.
  /// One _contact() call replaces the scripted velocity overrides and
  /// the separate shooter's-square / outside-square branches.
  void _checkBackboardCollision() {
    if (pos.z + radius >= backboardZ && pos.z - radius <= backboardZ + 0.12) {
      if (pos.x >= backboardMinX &&
          pos.x <= backboardMaxX &&
          pos.y >= backboardMinY &&
          pos.y <= backboardMaxY) {
        if (vel.z > 0) {
          pos.z = backboardZ - radius - 0.001;
          hasBankedBackboard = true;

          // Glass contact: normal pointing back towards court (-Z)
          // Restitution e=0.62 and low friction μ=0.12 (smooth tempered glass)
          final n = Vector3(0, 0, -1);
          _contact(n, e: 0.62, mu: 0.12);

          // Small bank-assist nudge for shots hitting the target square area.
          // This is a tiny centering velocity addition, never an absolute override.
          final isShootersSquare = pos.x.abs() <= 0.16 &&
              pos.y >= 3.12 &&
              pos.y <= 3.32;
          if (isShootersSquare) {
            final nudgeX = (rimCenter.x - pos.x) * 0.12;
            vel.x += nudgeX.clamp(-0.25, 0.25);
          }
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

    // Score recorded when ball descends through rim plane within inner opening
    if (!passedThroughRim &&
        prevY > rimCenter.y &&
        pos.y <= rimCenter.y &&
        dXZ < rimRadius + 0.02 &&
        vel.y < 0) {
      passedThroughRim = true;
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

  /// Hardwood court floor bouncing (impulse-based) and rolling friction settling.
  void _checkFloorCollision(double dt) {
    if (pos.y <= radius) {
      pos.y = radius;

      if (vel.y < 0) {
        if (vel.y.abs() > 0.35) {
          bounceCount++;
          // Floor contact: normal pointing up, hardwood restitution + high friction
          final n = Vector3(0, 1, 0);
          _contact(n, e: 0.62, mu: 0.50);
        } else {
          // Very low bounce energy — transition to rolling and settling
          vel.y = 0.0;
          // Frame-rate-independent rolling friction (exponential decay)
          final d = math.exp(-3.0 * dt);
          vel.x *= d;
          vel.z *= d;
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
