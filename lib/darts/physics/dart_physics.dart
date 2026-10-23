import 'package:vector_math/vector_math_64.dart';
import '../darts_constants.dart';

/// 3D ballistic dart physics simulation with fixed 240 Hz accumulator.
///
/// Features:
/// - Coordinate system:
///   - `+z` is distance to board in meters (launch at z = 2.37 m, board at z = 0).
///   - `+x` is horizontal offset in meters (positive right).
///   - `+y` is vertical offset in meters (positive up).
/// - Gravity acceleration only ($g = 9.81$ m/s² downwards along $-y$).
/// - Fixed-step integration (240 Hz, clamped dt) for frame-rate independence.
/// - Continuous plane-crossing detection at $z \le 0$ to prevent tunneling.
/// - Reports impact $(x, y)$ in board millimeters.
/// - Zero heap allocations during `update()` and `step()`.
class DartPhysics {
  // ─── 3D Position & Velocity (meters, m/s) ──────────────────────────────────
  final Vector3 pos = Vector3.zero();
  final Vector3 vel = Vector3.zero();
  final Vector3 prevPos = Vector3.zero();

  // ─── Simulation State ──────────────────────────────────────────────────────
  double flightTime = 0.0;
  double _accumulator = 0.0;
  bool inFlight = false;
  bool hasHit = false;

  /// Landed impact horizontal offset from board center in millimeters (+right).
  double hitX = 0.0;

  /// Landed impact vertical offset from board center in millimeters (+up).
  double hitY = 0.0;

  /// Launches a dart from oche distance with specified initial velocity.
  ///
  /// - [launchVel]: 3D velocity vector in m/s.
  /// - [startZ]: initial distance to board in meters (defaults to [DartsK.throwDistanceM]).
  /// - [startX], [startY]: initial offsets in meters (defaults to 0, 0).
  void launch({
    required Vector3 launchVel,
    double startZ = DartsK.throwDistanceM,
    double startX = 0.0,
    double startY = 0.0,
  }) {
    pos.setValues(startX, startY, startZ);
    prevPos.setValues(startX, startY, startZ);
    vel.setFrom(launchVel);

    flightTime = 0.0;
    _accumulator = 0.0;
    inFlight = true;
    hasHit = false;
    hitX = 0.0;
    hitY = 0.0;
  }

  /// Advances the simulation by [dt] seconds using a fixed 240 Hz accumulator.
  ///
  /// Guarantees zero heap allocations.
  void update(double dt) {
    if (!inFlight || hasHit) return;

    // Clamp dt to avoid spiral of death on lag spikes (1/20s max)
    final double clampedDt = dt > DartsK.dtClamp ? DartsK.dtClamp : (dt < 0.0 ? 0.0 : dt);
    _accumulator += clampedDt;

    int substeps = 0;
    while (_accumulator >= DartsK.fixedDt &&
        substeps < DartsK.maxSubstepsPerFrame &&
        inFlight &&
        !hasHit) {
      _step(DartsK.fixedDt);
      _accumulator -= DartsK.fixedDt;
      substeps++;
    }

    // Drop leftover accumulator if clamped to avoid build-up
    if (substeps >= DartsK.maxSubstepsPerFrame) {
      _accumulator = 0.0;
    }
  }

  /// Integrates a single fixed timestep [dt].
  void _step(double dt) {
    prevPos.setFrom(pos);

    // Position update using average velocity over dt (exact second-order ballistic integration)
    pos.x += vel.x * dt;
    pos.y += (vel.y - 0.5 * DartsK.gravity * dt) * dt;
    pos.z += vel.z * dt;

    // Velocity update under gravity
    vel.y -= DartsK.gravity * dt;

    flightTime += dt;

    // Board plane crossing: dart reaches or passes z = 0
    if (pos.z <= 0.0) {
      _resolveImpact();
    }
  }

  /// Calculates exact sub-step impact point at plane z = 0 using linear interpolation.
  void _resolveImpact() {
    final double dz = prevPos.z - pos.z;
    final double alpha = dz.abs() > 1e-9 ? (prevPos.z / dz).clamp(0.0, 1.0) : 1.0;

    final double impactX = prevPos.x + alpha * (pos.x - prevPos.x);
    final double impactY = prevPos.y + alpha * (pos.y - prevPos.y);

    // Convert meters to board millimeters
    hitX = impactX * 1000.0;
    hitY = impactY * 1000.0;

    pos.setValues(impactX, impactY, 0.0);
    hasHit = true;
    inFlight = false;
  }

  /// Simulates an entire flight synchronously until board impact.
  ///
  /// Useful for tests and inverse validation.
  void simulateToEnd() {
    const double stepDt = DartsK.fixedDt;
    int maxSteps = 2400; // 10 seconds max safety guard
    while (inFlight && !hasHit && maxSteps-- > 0) {
      _step(stepDt);
    }
  }
}
