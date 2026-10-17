import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Lightweight Verlet cloth for the basketball net.
///
/// The net is a tapered cylinder of [cords] vertical cords × [rows] rings,
/// simulated in hoop-local space (origin = rim center, units = Forge2D meters):
///   x = lateral, h = downward hang, z = depth (+z toward the camera).
/// It is drawn by projecting to the screen as (x, h + z * depthSquash), which
/// matches the flattened rim ellipse of the 2.5D art.
///
/// The ball pushes the net outward as it falls through (sphere cross-section
/// vs. ring), and drags it down a little, so a swish visibly flares and whips
/// back. Top ring is pinned to the rim.
///
/// Cost: 80 points, ~270 constraints × 3 iterations ≈ a few µs per frame, and
/// zero allocations (all state in preallocated typed arrays). The simulation
/// sleeps when nothing moves, so at rest it costs nothing at all.
class NetSimulation {
  NetSimulation({
    required this.rimHalfWidth,
    required this.rimHalfDepth,
    this.restDepth = 0.9,
    this.bottomTaper = 0.55,
  }) : depthSquash = rimHalfDepth / rimHalfWidth {
    _buildRestShape();
  }

  static const int cords = 16;
  static const int rows = 5; // ring 0 = pinned at the rim
  static const int pointCount = cords * rows;

  final double rimHalfWidth;
  final double rimHalfDepth;
  final double restDepth;
  final double bottomTaper;

  /// Screen-space flattening of depth (rim ellipse height / width).
  final double depthSquash;

  // Positions and previous positions (Verlet)
  final Float64List _x = Float64List(pointCount);
  final Float64List _h = Float64List(pointCount);
  final Float64List _z = Float64List(pointCount);
  final Float64List _px = Float64List(pointCount);
  final Float64List _ph = Float64List(pointCount);
  final Float64List _pz = Float64List(pointCount);

  // Constraints: index pairs + rest lengths
  static const int _maxConstraints = cords * (rows - 1) * 4;
  final Int32List _ca = Int32List(_maxConstraints);
  final Int32List _cb = Int32List(_maxConstraints);
  final Float64List _cl = Float64List(_maxConstraints);
  int _constraintCount = 0;

  /// Incremented whenever the net shape changes enough to be worth redrawing.
  int version = 0;

  bool _asleep = true;
  double _quietTime = 0.0;
  double _accumulator = 0.0;

  /// Largest per-point movement accumulated since [version] last changed.
  double _driftSinceVersion = 0.0;
  double _lastMaxMove = 0.0;

  /// Only re-record the hoop pictures once the net has visibly moved
  /// (~0.15px). Sub-pixel settling is simulated but never redrawn.
  static const double _visibleDrift = 0.004;

  /// Sleep once total net motion per step is below this (invisible) level.
  static const double _sleepMotion = 0.01;
  static const double _sleepAfterQuiet = 0.3;

  static const double _stepDt = 1.0 / 60.0;
  static const double _gravity = 9.0; // local units / s²
  static const double _damping = 0.955;
  static const int _iterations = 3;

  static int index(int row, int cord) => row * cords + (cord % cords);

  double screenX(int i) => _x[i];
  double screenY(int i) => _h[i] + _z[i] * depthSquash;

  /// True if the point faces the camera (front half of the net).
  bool isFront(int i) => _z[i] >= 0.0;

  void _buildRestShape() {
    for (int r = 0; r < rows; r++) {
      final t = r / (rows - 1);
      final ringScale = 1.0 - (1.0 - bottomTaper) * t;
      final hang = restDepth * t;
      for (int c = 0; c < cords; c++) {
        final a = 2.0 * math.pi * c / cords;
        final i = index(r, c);
        _x[i] = rimHalfWidth * ringScale * math.cos(a);
        _z[i] = rimHalfWidth * ringScale * math.sin(a);
        _h[i] = hang;
        _px[i] = _x[i];
        _ph[i] = _h[i];
        _pz[i] = _z[i];
      }
    }

    void link(int a, int b) {
      _ca[_constraintCount] = a;
      _cb[_constraintCount] = b;
      final dx = _x[a] - _x[b];
      final dh = _h[a] - _h[b];
      final dz = _z[a] - _z[b];
      _cl[_constraintCount] = math.sqrt(dx * dx + dh * dh + dz * dz);
      _constraintCount++;
    }

    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cords; c++) {
        link(index(r, c), index(r + 1, c)); // vertical cord
        link(index(r + 1, c), index(r + 1, c + 1)); // ring
        link(index(r, c), index(r + 1, c + 1)); // diamond mesh
        link(index(r, c + 1), index(r + 1, c));
      }
    }
  }

  /// Pushes the net away from a ball (hoop-local coords; [radius] in the same
  /// units) and drags touched points by the ball's downward speed [fallSpeed].
  /// Wakes the simulation if anything is touched.
  void pushBall({
    required double bx,
    required double bh,
    required double bz,
    required double radius,
    required double fallSpeed,
    required double dt,
  }) {
    // Real nets grip the ball: use a slightly fatter contact radius.
    final r0 = radius * 1.2;
    if (bh < -r0 || bh > restDepth + r0 * 1.5) return;
    // Drag only applies to a ball actually passing through the hoop opening,
    // not a miss falling past the outside of the net.
    final insideHoop = math.sqrt(bx * bx + bz * bz) < rimHalfWidth;
    final falling = fallSpeed > 0.0 && insideHoop;
    bool touched = false;
    for (int r = 1; r < rows; r++) {
      for (int c = 0; c < cords; c++) {
        final i = index(r, c);
        final dh = _h[i] - bh;
        if (dh.abs() >= r0) continue;
        final dx = _x[i] - bx;
        final dz = _z[i] - bz;
        final d = math.sqrt(dx * dx + dz * dz);
        if (d < 1e-5) continue;
        final dirX = dx / d;
        final dirZ = dz / d;

        // 1. Hard contact: keep cords outside the ball's cross-section.
        final minD = math.sqrt(r0 * r0 - dh * dh);
        if (d < minD) {
          _x[i] = bx + dirX * minD;
          _z[i] = bz + dirZ * minD;
          if (fallSpeed > 0.0) _h[i] += fallSpeed * dt * 0.35;
          touched = true;
        }

        // 2. Swish "drag": rings at the ball's height flare outward and get
        //    pulled down as it falls past (Verlet impulse via prev position),
        //    so even a perfectly centered swish visibly whips the net.
        if (falling) {
          final band = 1.0 - dh.abs() / r0;
          final impulse = fallSpeed * dt * 0.06 * band;
          _px[i] -= dirX * impulse;
          _pz[i] -= dirZ * impulse;
          _ph[i] -= impulse * 0.8;
          touched = true;
        }
      }
    }
    if (touched) _wake();
  }

  /// Gives the net a sideways jolt (e.g. from a hard rim clank).
  void kick(double strength) {
    for (int r = 1; r < rows; r++) {
      final falloff = r / (rows - 1);
      for (int c = 0; c < cords; c++) {
        final i = index(r, c);
        _px[i] -= strength * falloff * (c.isEven ? 1.0 : 0.6);
      }
    }
    _wake();
  }

  void _wake() {
    _asleep = false;
    _quietTime = 0.0;
  }

  void update(double dt) {
    if (_asleep) return;
    _accumulator += dt.clamp(0.0, 0.05);
    int steps = 0;
    double motion = 0.0;
    while (_accumulator >= _stepDt && steps < 2) {
      motion += _step();
      _driftSinceVersion += _lastMaxMove;
      _accumulator -= _stepDt;
      steps++;
    }
    if (steps == 0) return;

    // Redraw only on visible change (was: every step → ~120 picture
    // re-records/sec for ~4s after every touch, starving the audio thread).
    if (_driftSinceVersion > _visibleDrift) {
      version++;
      _driftSinceVersion = 0.0;
    }

    if (motion < _sleepMotion * steps) {
      _quietTime += dt;
      if (_quietTime > _sleepAfterQuiet) {
        _asleep = true;
        _accumulator = 0.0;
        // Final redraw so the resting shape is exactly what's displayed.
        if (_driftSinceVersion > 0.0) {
          version++;
          _driftSinceVersion = 0.0;
        }
      }
    } else {
      _quietTime = 0.0;
    }
  }

  /// One fixed Verlet step; returns total movement (for sleep detection).
  double _step() {
    const g = _gravity * _stepDt * _stepDt;
    double motion = 0.0;
    double maxMove = 0.0;
    for (int i = cords; i < pointCount; i++) {
      // Skip ring 0 (pinned)
      final vx = (_x[i] - _px[i]) * _damping;
      final vh = (_h[i] - _ph[i]) * _damping;
      final vz = (_z[i] - _pz[i]) * _damping;
      _px[i] = _x[i];
      _ph[i] = _h[i];
      _pz[i] = _z[i];
      _x[i] += vx;
      _h[i] += vh + g;
      _z[i] += vz;
      final move = vx.abs() + vh.abs() + vz.abs();
      motion += move;
      if (move > maxMove) maxMove = move;
    }
    _lastMaxMove = maxMove;

    for (int it = 0; it < _iterations; it++) {
      for (int k = 0; k < _constraintCount; k++) {
        final a = _ca[k];
        final b = _cb[k];
        final dx = _x[b] - _x[a];
        final dh = _h[b] - _h[a];
        final dz = _z[b] - _z[a];
        final d = math.sqrt(dx * dx + dh * dh + dz * dz);
        if (d < 1e-6) continue;
        // Cords only resist stretching (nets go slack, they don't push).
        if (d <= _cl[k]) continue;
        final diff = (d - _cl[k]) / d;
        final aPinned = a < cords;
        final bPinned = b < cords;
        if (aPinned && bPinned) continue;
        final wa = aPinned ? 0.0 : (bPinned ? 1.0 : 0.5);
        final wb = bPinned ? 0.0 : (aPinned ? 1.0 : 0.5);
        _x[a] += dx * diff * wa;
        _h[a] += dh * diff * wa;
        _z[a] += dz * diff * wa;
        _x[b] -= dx * diff * wb;
        _h[b] -= dh * diff * wb;
        _z[b] -= dz * diff * wb;
      }
    }
    return motion;
  }

  // ── Drawing (only runs while a picture is being re-recorded) ──────────────

  /// Draws the diamond mesh for one half of the net. The front half is drawn
  /// by FrontRimVisual (in front of the ball), the rear half by RearRimVisual.
  void drawMesh(Canvas canvas, Paint paint, {required bool front}) {
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cords; c++) {
        _segment(canvas, paint, index(r, c), index(r + 1, c + 1), front);
        _segment(canvas, paint, index(r, c + 1), index(r + 1, c), front);
      }
    }
  }

  /// Draws knots where the cords cross (front half only).
  void drawKnots(Canvas canvas, Paint paint, double radius) {
    for (int r = 1; r < rows; r++) {
      for (int c = 0; c < cords; c++) {
        final i = index(r, c);
        if (_z[i] < 0.0) continue;
        canvas.drawCircle(Offset(screenX(i), screenY(i)), radius, paint);
      }
    }
  }

  void _segment(Canvas canvas, Paint paint, int a, int b, bool front) {
    final isFrontSeg = (_z[a] + _z[b]) >= 0.0;
    if (isFrontSeg != front) return;
    canvas.drawLine(
      Offset(screenX(a), screenY(a)),
      Offset(screenX(b), screenY(b)),
      paint,
    );
  }
}
