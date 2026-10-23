import 'dart:async';
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
import 'state/darts_bot.dart';
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
/// Follows DARTS_PLAN.md Step 12:
/// - Screen framing and projection handled by [BoardProjection].
/// - Component draw priorities:
///   Backdrop 0 → Board 1 → Area Flash 2 → Board Shadows 3 → Stuck Darts 4 →
///   Flying Dart 5 → Resting Dart 6 → Aim Reticle 7 → Score Popups 8
/// - Automated solo turn flow:
///   1. Player throws up to 3 darts (or bust/checkout).
///   2. 0.8s pause, darts pulled out (fade over 200 ms).
///   3. Bot throws 3 darts with 0.7s flight gaps via [DartsBot] + inverse ballistic solver.
///   4. 0.8s pause, bot darts pulled, back to player or match over.
/// - 240 Hz clamped fixed-step simulation loop to match physics integration.
/// - Zero per-frame heap allocations during active gameplay.
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

  // ─── Turn Flow & Bot State ─────────────────────────────────────────────────
  bool _turnTransitioning = false;
  bool _isBotTurnActive = false;

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
    flickController.inputEnabled =
        events.isMyTurn && !flyingDart.isFlying && !_turnTransitioning && !_isBotTurnActive;
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
      // More darts remaining in player's turn
      restingDart.resetPullBack();
      restingDart.visible = true;
      _setupCurrentDart();
    } else {
      // Turn is over (3 darts, bust, or checkout)
      restingDart.visible = false;
      flickController.inputEnabled = false;
      _handlePlayerTurnOver();
    }
  }

  /// Orchestrates the transition when Player 1's turn completes.
  Future<void> _handlePlayerTurnOver() async {
    _turnTransitioning = true;
    flickController.inputEnabled = false;

    // 1. Pause 0.8s after turn ends
    await Future.delayed(
      Duration(milliseconds: (DartsK.turnEndPauseSec * 1000).round()),
    );

    // 2. Darts pulled out (fade over 200 ms)
    pullDarts();
    await Future.delayed(const Duration(milliseconds: 250));

    if (events.isMatchOver) {
      _turnTransitioning = false;
      return;
    }

    // 3. Hand turn to bot in solo play
    if (!events.isMyTurn) {
      await _runBotTurn();
    }

    _turnTransitioning = false;
  }

  /// Executes the bot's turn with physical flights, 0.7s gaps, and inverse solver.
  Future<void> _runBotTurn() async {
    _isBotTurnActive = true;
    restingDart.playerIndex = 1;
    restingDart.visible = false;

    int botTurnPoints = 0;

    for (int dartIdx = 0; dartIdx < DartsK.dartsPerTurn; dartIdx++) {
      if (events.isMatchOver || events.isMyTurn) break;

      // 0.7s flight interval between successive bot darts
      if (dartIdx > 0) {
        await Future.delayed(
          Duration(milliseconds: (DartsK.botDartGapSec * 1000).round()),
        );
      }

      if (events.isMatchOver || events.isMyTurn) break;

      final int curRem = events.theirRemaining - botTurnPoints;
      final DartHit targetHit = DartsBot.dart(
        events.matchSeed,
        events.round,
        dartIdx,
        curRem,
      );

      final Completer<DartTurnResult> landedCompleter = Completer();

      // Launch dart via closed-form inverse ballistic solver
      final launchVel = FlickSolver.launchFor(
        targetHit.x,
        targetHit.y,
        DartsK.idealSpeed,
      );

      flyingDart.launch(
        launchVel: launchVel,
        playerIndex: 1,
        onLanded: (hit) {
          dartboard.flashArea(hit);

          final stuck = StuckDart(
            projection: projection,
            sprites: sprites,
            hit: hit,
            playerIndex: 1,
          );
          stuckDarts.add(stuck);
          add(stuck);

          if (stuckDarts.length > 3) {
            final oldest = stuckDarts.removeAt(0);
            oldest.startPull();
          }

          final DartTurnResult res = events.dartLanded(hit);
          hitPopup.showHit(hit, isBust: res.bust, isCheckout: res.checkout);

          botTurnPoints += hit.points;
          landedCompleter.complete(res);
        },
      );

      final DartTurnResult res = await landedCompleter.future;
      if (res.turnOver || events.isMatchOver) {
        break;
      }
    }

    // Bot turn complete: pause 0.8s and pull darts
    await Future.delayed(
      Duration(milliseconds: (DartsK.turnEndPauseSec * 1000).round()),
    );

    pullDarts();
    await Future.delayed(const Duration(milliseconds: 250));

    _isBotTurnActive = false;

    // Switch back to Player 1 if match is still running
    if (!events.isMatchOver && events.isMyTurn) {
      restingDart.playerIndex = 0;
      restingDart.resetPullBack();
      restingDart.visible = true;
      _setupCurrentDart();
    }
  }

  /// Resets board and restarts a solo match for a rematch.
  void restartGame() {
    pullDarts();
    events.restartMatch();
    restingDart.playerIndex = 0;
    restingDart.resetPullBack();
    restingDart.visible = true;
    _turnTransitioning = false;
    _isBotTurnActive = false;
    _setupCurrentDart();
  }

  // ─── Pointer Input Hooks ───────────────────────────────────────────────────

  void onPointerDown(int pointerId, double x, double y) {
    if (_isBotTurnActive || _turnTransitioning) return;
    flickController.onPointerDown(pointerId, x, y);
  }

  void onPointerMove(int pointerId, double x, double y) {
    if (_isBotTurnActive || _turnTransitioning) return;
    flickController.onPointerMove(pointerId, x, y);
  }

  void onPointerUp(int pointerId) {
    if (_isBotTurnActive || _turnTransitioning) return;
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
    if (flyingDart.isFlying || _turnTransitioning || _isBotTurnActive) return;

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

        if (!result.turnOver && events.isMyTurn) {
          restingDart.visible = true;
          restingDart.resetPullBack();
          _setupCurrentDart();
        } else {
          restingDart.visible = false;
          _handlePlayerTurnOver();
        }
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
  bool get isBusy =>
      flyingDart.isFlying || _isBotTurnActive || _turnTransitioning;
}
