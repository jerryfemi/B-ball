import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

import '../darts_constants.dart';
import '../physics/flick_solver.dart';
import '../physics/wobble_model.dart';
import '../scene/board_projection.dart';

class _PointerSample {
  double x = 0.0;
  double y = 0.0;
  double time = 0.0;
}

/// Gesture and aim controller implementing hold-aim and upward flick throw.
///
/// Follows DARTS_PLAN.md §1.2 & Step 11:
/// 1. Touch in lower 60% of screen initiates aiming.
/// 2. Drag moves reticle relative to finger via thumb-roll (`DartsK.aimGain`).
/// 3. Wobble model applies deterministic hand tremor to reticle and resting dart.
/// 4. Upward flick with speed $\ge \text{minFlick}$ throws the dart via ballistic solver.
/// 5. Release without flick cancels throw with no penalty.
/// 6. Zero heap allocations in pointer sampling and update loops.
class FlickController {
  final BoardProjection projection;

  // ─── Callbacks ─────────────────────────────────────────────────────────────
  void Function(Vector3 launchVel)? onThrow;
  void Function()? onAimStart;
  void Function()? onAimCancel;

  // ─── Aim State ─────────────────────────────────────────────────────────────
  bool isAiming = false;
  bool inputEnabled = true;

  double rawAimMmX = 0.0;
  double rawAimMmY = 0.0;
  double lastAimMmX = 0.0;
  double lastAimMmY = 0.0;

  double shownMmX = 0.0;
  double shownMmY = 0.0;

  double holdTime = 0.0;
  double totalTime = 0.0;

  WobbleModel? wobbleModel;

  // ─── Pointer Tracking & Ring Buffer ────────────────────────────────────────
  int? _activePointerId;
  double _anchorX = 0.0;
  double _anchorY = 0.0;

  static const int _sampleCapacity = 10;
  final List<_PointerSample> _samples = List.generate(
    _sampleCapacity,
    (_) => _PointerSample(),
    growable: false,
  );
  int _sampleHead = 0;
  int _sampleCount = 0;

  FlickController({required this.projection});

  /// Initializes the deterministic wobble seed for the upcoming throw.
  void initWobbleSeed({
    required int matchSeed,
    required int round,
    required int dartIndex,
  }) {
    wobbleModel = WobbleModel.fromMatch(
      matchSeed: matchSeed,
      round: round,
      dartIndex: dartIndex,
    );
  }

  void _pushSample(double x, double y, double t) {
    final s = _samples[_sampleHead];
    s.x = x;
    s.y = y;
    s.time = t;
    _sampleHead = (_sampleHead + 1) % _sampleCapacity;
    if (_sampleCount < _sampleCapacity) {
      _sampleCount++;
    }
  }

  void onPointerDown(int pointerId, double x, double y) {
    if (!inputEnabled || _activePointerId != null) return;

    // Only allow initiating aim from lower 60% of the screen
    final double lowerThreshold = projection.screenHeight * 0.40;
    if (y < lowerThreshold) return;

    _activePointerId = pointerId;
    isAiming = true;
    holdTime = 0.0;
    _anchorX = x;
    _anchorY = y;

    // Start from last aimed location, clamped inside board face
    rawAimMmX = lastAimMmX;
    rawAimMmY = lastAimMmY;
    shownMmX = rawAimMmX;
    shownMmY = rawAimMmY;

    _sampleHead = 0;
    _sampleCount = 0;
    _pushSample(x, y, totalTime);

    onAimStart?.call();
  }

  void onPointerMove(int pointerId, double x, double y) {
    if (_activePointerId != pointerId || !isAiming) return;

    _pushSample(x, y, totalTime);

    // Thumb-roll sensitivity: DartsK.aimGain board-mm per screen pixel
    const double gain = DartsK.aimGain;
    final double deltaPxX = x - _anchorX;
    final double deltaPxY = y - _anchorY;

    // Invert Y since screen +y is down, but board +y is up
    const double maxR = DartsK.doubleOutR;
    rawAimMmX = (lastAimMmX + deltaPxX * gain).clamp(-maxR, maxR);
    rawAimMmY = (lastAimMmY - deltaPxY * gain).clamp(-maxR, maxR);
  }

  void onPointerUp(int pointerId) {
    if (_activePointerId != pointerId) return;
    _activePointerId = null;

    if (!isAiming) return;
    isAiming = false;

    // Save aim coordinates for next dart
    lastAimMmX = rawAimMmX;
    lastAimMmY = rawAimMmY;

    // Evaluate upward flick velocity from recent samples (last 60–120 ms)
    if (_sampleCount >= 2 && projection.screenHeight > 0.0) {
      final int latestIdx = (_sampleHead - 1 + _sampleCapacity) % _sampleCapacity;
      final _PointerSample latest = _samples[latestIdx];

      // Find sample ~70ms in the past for robust velocity estimation
      _PointerSample past = latest;
      for (int i = 1; i < _sampleCount; i++) {
        final int idx = (_sampleHead - 1 - i + _sampleCapacity) % _sampleCapacity;
        final _PointerSample s = _samples[idx];
        final double dt = latest.time - s.time;
        if (dt >= 0.050) {
          past = s;
          break;
        }
        past = s;
      }

      final double dt = latest.time - past.time;
      if (dt > 0.015) {
        final double deltaY = latest.y - past.y;
        final double deltaX = latest.x - past.x;

        // Upward flick speed in screen-heights / sec
        final double upwardSpeed = -deltaY / (projection.screenHeight * dt);

        if (upwardSpeed >= DartsK.minFlick) {
          // Flick throw confirmed!
          final double flickPower = upwardSpeed / DartsK.idealFlick;
          // Flick release angle vs straight-up in degrees (-left, +right)
          final double flickAngleRad = math.atan2(deltaX, -deltaY);
          final double flickAngleDeg = flickAngleRad * 180.0 / math.pi;

          // Build ballistic launch trajectory
          final Vector3 idealLaunch = FlickSolver.launchFor(
            shownMmX,
            shownMmY,
            DartsK.idealSpeed,
          );
          final Vector3 actualLaunch = FlickSolver.applyFlick(
            idealLaunch,
            flickPower,
            flickAngleDeg,
          );

          onThrow?.call(actualLaunch);
          return;
        }
      }
    }

    // Release without valid flick -> cancel with no penalty
    onAimCancel?.call();
  }

  void onPointerCancel() {
    _activePointerId = null;
    if (isAiming) {
      isAiming = false;
      onAimCancel?.call();
    }
  }

  void update(double dt) {
    totalTime += dt;

    if (isAiming) {
      holdTime += dt;
      wobbleModel?.update(holdTime, isAiming);

      final double wobbleX = wobbleModel?.dx ?? 0.0;
      final double wobbleY = wobbleModel?.dy ?? 0.0;

      shownMmX = rawAimMmX + wobbleX;
      shownMmY = rawAimMmY + wobbleY;
    } else {
      holdTime = 0.0;
      wobbleModel?.reset();
      shownMmX = rawAimMmX;
      shownMmY = rawAimMmY;
    }
  }

  double get wobbleMmX => wobbleModel?.dx ?? 0.0;
  double get wobbleMmY => wobbleModel?.dy ?? 0.0;
}
