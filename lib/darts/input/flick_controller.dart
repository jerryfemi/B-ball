import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

import '../darts_constants.dart';
import '../physics/flick_solver.dart';
import '../scene/board_projection.dart';

class _PointerSample {
  double x = 0.0;
  double y = 0.0;
  double time = 0.0;
}

/// Pure flick input, GamePigeon style.
///
/// 1. Touching the lower part of the screen picks the dart up; it follows the
///    finger ([isHolding], [fingerX], [fingerY]).
/// 2. Swiping up and letting go throws it. There is no aim preview: the
///    landing spot comes only from the flick ([FlickSolver.targetForFlick]):
///    release position → left/right, swipe angle → drift, swipe speed → height.
/// 3. Letting go without an upward swipe puts the dart back down.
///
/// Zero heap allocations while the finger moves (fixed ring buffer).
class FlickController {
  final BoardProjection projection;

  // ─── Callbacks ─────────────────────────────────────────────────────────────
  /// The dart was thrown with this launch velocity, from the finger's
  /// release point (screen px).
  void Function(Vector3 launchVel)? onThrow;

  /// The finger picked the dart up.
  void Function()? onPickUp;

  /// The finger let go without a flick: the dart goes back to rest.
  void Function()? onDrop;

  // ─── State ─────────────────────────────────────────────────────────────────
  bool inputEnabled = true;

  /// True while a finger holds the dart.
  bool isHolding = false;

  /// Current finger position (screen px) while [isHolding].
  double fingerX = 0.0;
  double fingerY = 0.0;

  /// The last throw's target (board mm), for tests and debugging.
  double lastTargetMmX = 0.0;
  double lastTargetMmY = 0.0;

  /// Real time in seconds, for swipe speed. Pointer events arrive between
  /// frames, so frame time would be too coarse. Tests inject their own.
  final double Function() _now;
  static final Stopwatch _watch = Stopwatch()..start();
  static double _wallClock() => _watch.elapsedMicroseconds / 1e6;

  // ─── Pointer Tracking & Ring Buffer ────────────────────────────────────────
  int? _activePointerId;

  static const int _sampleCapacity = 12;
  final List<_PointerSample> _samples = List.generate(
    _sampleCapacity,
    (_) => _PointerSample(),
    growable: false,
  );
  int _sampleHead = 0;
  int _sampleCount = 0;

  FlickController({required this.projection, double Function()? now})
      : _now = now ?? _wallClock;

  void _pushSample(double x, double y, double t) {
    final s = _samples[_sampleHead];
    s.x = x;
    s.y = y;
    s.time = t;
    _sampleHead = (_sampleHead + 1) % _sampleCapacity;
    if (_sampleCount < _sampleCapacity) _sampleCount++;
  }

  void onPointerDown(int pointerId, double x, double y) {
    if (!inputEnabled || _activePointerId != null) return;
    if (y < projection.screenHeight * DartsK.flickTouchTopFrac) return;

    _activePointerId = pointerId;
    isHolding = true;
    fingerX = x;
    fingerY = y;
    _sampleHead = 0;
    _sampleCount = 0;
    _pushSample(x, y, _now());
    onPickUp?.call();
  }

  void onPointerMove(int pointerId, double x, double y) {
    if (_activePointerId != pointerId || !isHolding) return;
    fingerX = x;
    fingerY = y;
    _pushSample(x, y, _now());
  }

  void onPointerUp(int pointerId) {
    if (_activePointerId != pointerId) return;
    _activePointerId = null;
    if (!isHolding) return;
    isHolding = false;

    // Stamp the release: stopping before lifting the finger means no flick.
    _pushSample(fingerX, fingerY, _now());
    final Vector3? launch = _launchFromSamples();
    if (launch != null) {
      onThrow?.call(launch);
    } else {
      onDrop?.call();
    }
  }

  void onPointerCancel() {
    _activePointerId = null;
    if (isHolding) {
      isHolding = false;
      onDrop?.call();
    }
  }

  /// Kept for the game loop; swipe timing uses real time, not frames.
  void update(double dt) {}

  /// Turns the last ~60 ms of the swipe into a launch velocity, or null when
  /// the finger didn't flick up fast enough.
  Vector3? _launchFromSamples() {
    final double screenH = projection.screenHeight;
    if (_sampleCount < 2 || screenH <= 0.0) return null;

    final int latestIdx = (_sampleHead - 1 + _sampleCapacity) % _sampleCapacity;
    final _PointerSample latest = _samples[latestIdx];

    // A sample ~60 ms before release, for a steady velocity estimate.
    _PointerSample past = latest;
    for (int i = 1; i < _sampleCount; i++) {
      final int idx = (_sampleHead - 1 - i + _sampleCapacity) % _sampleCapacity;
      past = _samples[idx];
      if (latest.time - past.time >= 0.060) break;
    }

    final double dt = latest.time - past.time;
    if (dt < 0.012) return null;

    final double dx = latest.x - past.x;
    final double dy = latest.y - past.y; // negative = upward on screen
    final double upwardSpeed = -dy / (screenH * dt); // screen heights / s
    if (upwardSpeed < DartsK.minFlick) return null;

    final double angleDeg = math.atan2(dx, -dy) * 180.0 / math.pi;
    final double releaseMmX =
        (latest.x - projection.boardCenterX) * projection.pxToMm;

    final target = FlickSolver.targetForFlick(
      releaseMmX: releaseMmX,
      upwardSpeed: upwardSpeed,
      angleDeg: angleDeg,
    );
    lastTargetMmX = target.x;
    lastTargetMmY = target.y;
    return FlickSolver.launchFor(target.x, target.y, DartsK.idealSpeed);
  }
}
