import 'dart:ui';
import 'package:flame/game.dart';

import 'darts_constants.dart';
import 'physics/dart_scoring.dart';
import 'scene/board_projection.dart';
import 'state/darts_match_notifier.dart';

/// Online game interface for controlling live match turns and sync from Firestore.
abstract interface class DartsOnlineGame {
  /// Prepares the board for an online turn: sets round, who throws, and already landed darts.
  void beginOnlineTurn({
    required int round,
    required bool mine,
    required List<DartHit> turnDarts,
  });

  /// Remote player is aiming: coordinates in board millimeters.
  void remoteAim(double aimX, double aimY);

  /// Remote player threw a dart: fly and land it on this screen.
  void playRemoteDart(DartHit hit);

  /// Shot clock expired: force a miss.
  void forceMiss();

  /// True while a dart is flying or animations are playing.
  bool get isBusy;
}

/// Flame game engine for Darts 301.
///
/// Follows DARTS_PLAN.md:
/// - Screen framing and projection handled by [BoardProjection].
/// - 240 Hz clamped fixed-step simulation loop to match physics integration.
/// - Dark obsidian background (#0A0E1A) with zero per-frame heap allocations.
/// - Game state, match rules, and scoring are owned by [DartsGameEvents].
class DartsGame extends FlameGame implements DartsOnlineGame {
  final DartsGameEvents events;

  /// Global camera & coordinate projection between board millimeters and screen pixels.
  final BoardProjection projection = BoardProjection();

  // ─── Fixed-step Accumulator State ──────────────────────────────────────────
  double _accumulator = 0.0;

  DartsGame({required this.events});

  @override
  Color backgroundColor() => const Color(DartsK.surfaceDark);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    projection.resize(size);
  }

  @override
  void update(double dt) {
    // Clamp frame dt to avoid spiral of death on lag spikes (50 ms max)
    final double clampedDt =
        dt > DartsK.dtClamp ? DartsK.dtClamp : (dt < 0.0 ? 0.0 : dt);
    _accumulator += clampedDt;

    int substeps = 0;
    while (_accumulator >= DartsK.fixedDt &&
        substeps < DartsK.maxSubstepsPerFrame) {
      _fixedUpdate(DartsK.fixedDt);
      _accumulator -= DartsK.fixedDt;
      substeps++;
    }

    if (substeps >= DartsK.maxSubstepsPerFrame) {
      _accumulator = 0.0;
    }

    super.update(dt);
  }

  /// Fixed 240 Hz simulation step (zero allocations).
  void _fixedUpdate(double dt) {
    // Child physics updates will be integrated here in subsequent steps
  }

  // ─── DartsOnlineGame Implementation ────────────────────────────────────────

  @override
  void beginOnlineTurn({
    required int round,
    required bool mine,
    required List<DartHit> turnDarts,
  }) {
    // Online turn setup will populate stuck darts and reset aim
  }

  @override
  void remoteAim(double aimX, double aimY) {
    // Aim reticle mirror for remote opponent
  }

  @override
  void playRemoteDart(DartHit hit) {
    // Inverse solver flight for remote dart
  }

  @override
  void forceMiss() {
    events.dartLanded(DartScoring.score(DartsK.boardR + 10.0, 0.0));
  }

  @override
  bool get isBusy => false;
}
