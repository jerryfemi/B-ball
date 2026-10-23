import 'dart:ui';
import 'package:flame/game.dart';

import 'components/board_backdrop.dart';
import 'components/dartboard.dart';
import 'components/dart_sprites.dart';
import 'components/flying_dart.dart';
import 'components/resting_dart.dart';
import 'components/stuck_dart.dart';
import 'darts_constants.dart';
import 'physics/dart_scoring.dart';
import 'physics/flick_solver.dart';
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
/// - Component draw priorities:
///   Backdrop 0 → Board 1 → Area Flash 2 → Board Shadows 3 → Stuck Darts 4 → Flying Dart 5 → Resting Dart 6
/// - 240 Hz clamped fixed-step simulation loop to match physics integration.
/// - Dark obsidian background (#0A0E1A) with zero per-frame heap allocations.
/// - Game state, match rules, and scoring are owned by [DartsGameEvents].
class DartsGame extends FlameGame implements DartsOnlineGame {
  final DartsGameEvents events;

  /// Global camera & coordinate projection between board millimeters and screen pixels.
  final BoardProjection projection = BoardProjection();

  late final DartSprites sprites;
  late final BoardBackdrop backdrop;
  late final Dartboard dartboard;
  late final FlyingDart flyingDart;
  late final RestingDart restingDart;

  final List<StuckDart> stuckDarts = [];

  // ─── Fixed-step Accumulator State ──────────────────────────────────────────
  double _accumulator = 0.0;

  DartsGame({required this.events});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    sprites = await DartSprites.load();

    backdrop = BoardBackdrop(projection: projection);
    dartboard = Dartboard(projection: projection);
    flyingDart = FlyingDart(projection: projection, sprites: sprites);
    restingDart = RestingDart(projection: projection, sprites: sprites);

    await add(backdrop); // Priority 0
    await add(dartboard); // Priority 1
    await add(flyingDart.shadow); // Priority 3
    await add(flyingDart); // Priority 5
    await add(restingDart); // Priority 6
  }

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
    // Ballistic physics integrated in FlyingDart
  }

  /// Launches a test/debug dart toward target `(targetMmX, targetMmY)` on the dartboard.
  ///
  /// Used in Step 10 verification to test flight, shadow, spin, and board impact wobble.
  void throwDebugDart({
    int player = 0,
    double targetMmX = 0.0,
    double targetMmY = 0.0,
  }) {
    if (flyingDart.isFlying) return;

    restingDart.visible = false;
    restingDart.startPullBack();

    final launchVel =
        FlickSolver.launchFor(targetMmX, targetMmY, DartsK.idealSpeed);

    flyingDart.launch(
      launchVel: launchVel,
      playerIndex: player,
      onLanded: (hit) {
        dartboard.flashArea(hit);

        final stuck = StuckDart(
          projection: projection,
          sprites: sprites,
          hit: hit,
          playerIndex: player,
        );
        stuckDarts.add(stuck);
        add(stuck);

        // Keep maximum 3 stuck darts per turn
        if (stuckDarts.length > 3) {
          final oldest = stuckDarts.removeAt(0);
          oldest.startPull();
        }

        restingDart.visible = true;
        restingDart.resetPullBack();
      },
    );
  }

  /// Pulls all currently stuck darts out of the board with a 200 ms fade-out.
  void pullDarts() {
    for (final dart in stuckDarts) {
      dart.startPull();
    }
    stuckDarts.clear();
  }

  // ─── DartsOnlineGame Implementation ────────────────────────────────────────

  @override
  void beginOnlineTurn({
    required int round,
    required bool mine,
    required List<DartHit> turnDarts,
  }) {
    pullDarts();
    final pIdx = mine ? 0 : 1;
    restingDart.playerIndex = pIdx;
    restingDart.visible = mine;

    for (final hit in turnDarts) {
      final stuck = StuckDart(
        projection: projection,
        sprites: sprites,
        hit: hit,
        playerIndex: pIdx,
      );
      stuckDarts.add(stuck);
      add(stuck);
    }
  }

  @override
  void remoteAim(double aimX, double aimY) {
    restingDart.setAimOffset(aimX / DartsK.boardR);
  }

  @override
  void playRemoteDart(DartHit hit) {
    throwDebugDart(player: 1, targetMmX: hit.x, targetMmY: hit.y);
  }

  @override
  void forceMiss() {
    events.dartLanded(DartScoring.score(DartsK.boardR + 10.0, 0.0));
  }

  @override
  bool get isBusy => flyingDart.isFlying;
}
