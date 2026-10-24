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
///    landing spot comes only from the flick:
///    - left/right: where the swipe points. The stroke (its last
///      [DartsK.flickStrokeWindow]) is extended up the screen to the board's
///      centre row, so swiping at the 20 sends the dart to the 20;
///    - height: swipe speed over the last [DartsK.flickSpeedWindow]
///      ([FlickSolver.targetForFlick]);
///    - then a light aim assist ([FlickSolver.assist]).
/// 3. Letting go without an upward swipe puts the dart back down.
///
/// Zero heap allocations while the finger moves (fixed ring buffer).
class FlickController {
  final BoardProjection projection;

  // ─── Callbacks ─────────────────────────────────────────────────────────────
  /// The dart was thrown at this target (board mm). The game launches it
  /// from wherever the dart in hand is ([FlickSolver.launchFor]).
  void Function(double targetMmX, double targetMmY)? onThrow;

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

  static const int _sampleCapacity = 40; // ~0.3 s at 120 Hz
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
    if (_targetFromSamples()) {
      onThrow?.call(lastTargetMmX, lastTargetMmY);
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

  /// Turns the last ~60 ms of the swipe into a target ([lastTargetMmX],
  /// [lastTargetMmY]); false when the finger didn't flick up fast enough.
  bool _targetFromSamples() {
    final double screenH = projection.screenHeight;
    if (_sampleCount < 2 || screenH <= 0.0) return false;

    final int latestIdx = (_sampleHead - 1 + _sampleCapacity) % _sampleCapacity;
    final _PointerSample latest = _samples[latestIdx];

    final _PointerSample speedFrom = _sampleBefore(latest, DartsK.flickSpeedWindow);
    final _PointerSample strokeFrom = _sampleBefore(latest, DartsK.flickStrokeWindow);

    final double dt = latest.time - speedFrom.time;
    if (dt < 0.012) return false;

    // Height: average upward speed over the speed window.
    final double upwardSpeed = -(latest.y - speedFrom.y) / (screenH * dt); // screen heights / s
    if (upwardSpeed < DartsK.minFlick) return false;

    // Left/right: extend the stroke up to the board's centre row and read
    // where it crosses, in board mm. A short or flat stroke falls back to
    // straight up from the release point.
    final double sdx = latest.x - strokeFrom.x;
    final double sdy = latest.y - strokeFrom.y; // negative = upward
    double crossX = latest.x;
    if (sdy < -8.0) {
      final double toBoard = projection.boardCenterY - latest.y; // negative
      crossX = latest.x + sdx / sdy * toBoard;
    }
    final double pointMmX = (crossX - projection.boardCenterX) * projection.pxToMm;

    final target = FlickSolver.targetForFlick(
      releaseMmX: pointMmX,
      upwardSpeed: upwardSpeed,
      angleDeg: 0.0, // direction is already in pointMmX
    );
    final assisted = FlickSolver.assist(target.x, target.y);
    lastTargetMmX = assisted.x;
    lastTargetMmY = assisted.y;
    return true;
  }

  /// The newest sample at least [window] seconds older than [latest] (or the
  /// oldest one kept).
  _PointerSample _sampleBefore(_PointerSample latest, double window) {
    _PointerSample past = latest;
    for (int i = 1; i < _sampleCount; i++) {
      final int idx = (_sampleHead - 1 - i + _sampleCapacity) % _sampleCapacity;
      past = _samples[idx];
      if (latest.time - past.time >= window) break;
    }
    return past;
  }
}
