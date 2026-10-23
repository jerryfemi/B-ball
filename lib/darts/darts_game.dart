import 'dart:ui';
import 'package:flame/game.dart';

import 'components/aim_reticle.dart';
import 'components/board_backdrop.dart';
import 'components/dartboard.dart';
import 'components/dart_sprites.dart';
import 'components/flying_dart.dart';
import 'components/hit_popup_canvas.dart';
import 'components/resting_dart.dart';
import 'components/stuck_dart.dart';
import 'darts_constants.dart';
import 'input/flick_controller.dart';
import 'physics/dart_scoring.dart';
import 'physics/flick_solver.dart';
import 'scene/board_projection.dart';
import 'state/darts_match_notifier.dart';
import 'state/darts_rules.dart';

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
///   Backdrop 0 → Board 1 → Area Flash 2 → Board Shadows 3 → Stuck Darts 4 →
///   Flying Dart 5 → Resting Dart 6 → Aim Reticle 7 → Score Popups 8
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
  late final AimReticle aimReticle;
  late final HitPopupCanvas hitPopup;
  late final FlickController flickController;

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
    aimReticle = AimReticle(projection: projection);
    hitPopup = HitPopupCanvas(projection: projection);
    flickController = FlickController(projection: projection);

    // Wire up flick controller throw and aim events
    flickController.onAimStart = () {
      aimReticle.visible = true;
      restingDart.visible = true;
    };

    flickController.onAimCancel = () {
      aimReticle.visible = false;
      restingDart.resetPullBack();
      restingDart.visible = true;
    };

    flickController.onThrow = (launchVel) {
      aimReticle.visible = false;
      restingDart.visible = false;
      restingDart.startPullBack();
      flickController.inputEnabled = false;

      flyingDart.launch(
        launchVel: launchVel,
        playerIndex: 0,
        onLanded: _onLocalDartLanded,
      );
    };

    await add(backdrop); // Priority 0
    await add(dartboard); // Priority 1
    await add(flyingDart.shadow); // Priority 3
    await add(flyingDart); // Priority 5
    await add(restingDart); // Priority 6
    await add(aimReticle); // Priority 7
    await add(hitPopup); // Priority 8

    _setupCurrentDart();
  }

  /// Configures seeds and enables input for the current player's dart.
  void _setupCurrentDart() {
    flickController.initWobbleSeed(
      matchSeed: events.matchSeed,
      round: events.round,
      dartIndex: events.dartIndex,
    );
    flickController.inputEnabled = events.isMyTurn && !flyingDart.isFlying;
  }

  void _onLocalDartLanded(DartHit hit) {
    dartboard.flashArea(hit);

    final stuck = StuckDart(
      projection: projection,
      sprites: sprites,
      hit: hit,
      playerIndex: 0,
    );
    stuckDarts.add(stuck);
    add(stuck);

    if (stuckDarts.length > 3) {
      final oldest = stuckDarts.removeAt(0);
      oldest.startPull();
    }

    final DartTurnResult result = events.dartLanded(hit);
    hitPopup.showHit(hit, isBust: result.bust, isCheckout: result.checkout);

    if (!result.turnOver && events.isMyTurn) {
      restingDart.resetPullBack();
      restingDart.visible = true;
      _setupCurrentDart();
    } else {
      restingDart.visible = false;
    }
  }

  // ─── Pointer Input Hooks ───────────────────────────────────────────────────

  void onPointerDown(int pointerId, double x, double y) {
    flickController.onPointerDown(pointerId, x, y);
  }

  void onPointerMove(int pointerId, double x, double y) {
    flickController.onPointerMove(pointerId, x, y);
  }

  void onPointerUp(int pointerId) {
    flickController.onPointerUp(pointerId);
  }

  void onPointerCancel() {
    flickController.onPointerCancel();
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
    flickController.update(dt);

    if (flickController.isAiming) {
      aimReticle.visible = true;
      aimReticle.setAim(
        mmX: flickController.shownMmX,
        mmY: flickController.shownMmY,
        holdSec: flickController.holdTime,
      );
      aimReticle.targetMmX = flickController.shownMmX;
      aimReticle.targetMmY = flickController.shownMmY;
      restingDart.setAimOffset(flickController.shownMmX / DartsK.boardR);
      restingDart.setWobble(flickController.wobbleMmX, flickController.wobbleMmY);
    }

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
  void throwDebugDart({
    int player = 0,
    double targetMmX = 0.0,
    double targetMmY = 0.0,
  }) {
    if (flyingDart.isFlying) return;

    restingDart.visible = false;
    restingDart.startPullBack();
    flickController.inputEnabled = false;

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

        if (stuckDarts.length > 3) {
          final oldest = stuckDarts.removeAt(0);
          oldest.startPull();
        }

        final DartTurnResult result = events.dartLanded(hit);
        hitPopup.showHit(hit, isBust: result.bust, isCheckout: result.checkout);

        restingDart.visible = !result.turnOver;
        restingDart.resetPullBack();
        _setupCurrentDart();
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
    flickController.inputEnabled = mine;

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
    aimReticle.visible = true;
    aimReticle.setAim(mmX: aimX, mmY: aimY, holdSec: 0.6);
    restingDart.setAimOffset(aimX / DartsK.boardR);
  }

  @override
  void playRemoteDart(DartHit hit) {
    aimReticle.visible = false;
    throwDebugDart(player: 1, targetMmX: hit.x, targetMmY: hit.y);
  }

  @override
  void forceMiss() {
    events.dartLanded(DartScoring.score(DartsK.boardR + 10.0, 0.0));
  }

  @override
  bool get isBusy => flyingDart.isFlying;
}
