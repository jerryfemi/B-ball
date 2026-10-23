import 'dart:async';
import 'dart:ui';
import 'package:flame/game.dart';

import 'audio/darts_audio.dart';
import 'components/board_backdrop.dart';
import 'components/dartboard.dart';
import 'components/dart_sprites.dart';
import 'components/flying_dart.dart';
import 'components/hit_popup_canvas.dart';
import 'components/resting_dart.dart';
import 'components/stuck_dart.dart';
import 'darts_constants.dart';
import 'input/flick_controller.dart';
import 'online/darts_live_event.dart';
import 'online/darts_online_controller.dart';
import 'physics/dart_scoring.dart';
import 'physics/flick_solver.dart';
import 'scene/board_projection.dart';
import 'state/darts_bot.dart';
import 'state/darts_match_notifier.dart';
import 'state/darts_rules.dart';

/// Flame game engine for Darts 301.
///
/// Follows DARTS_PLAN.md Step 12:
/// - Screen framing and projection handled by [BoardProjection].
/// - Component draw priorities:
///   Backdrop 0 → Board 1 → Area Flash 2 → Board Shadows 3 → Stuck Darts 4 →
///   Flying Dart 5 → Resting Dart 6 → Score Popups 8
/// - Pure flick throwing (no aim preview), see [FlickController].
/// - Automated solo turn flow:
///   1. Player throws up to 3 darts (or bust/checkout).
///   2. 0.8s pause, darts pulled out (fade over 200 ms).
///   3. Bot throws 3 darts with 0.7s flight gaps via [DartsBot] + inverse ballistic solver.
///   4. 0.8s pause, bot darts pulled, back to player or match over.
/// - Physics runs at a fixed 240 Hz inside [DartPhysics].
/// - Zero per-frame heap allocations during active gameplay.
class DartsGame extends FlameGame implements DartsOnlineGame {
  final DartsGameEvents events;

  /// Set for a live online match; null in solo play against the bot.
  final DartsOnlineController? online;

  /// Global camera & coordinate projection between board millimeters and screen pixels.
  final BoardProjection projection = BoardProjection();

  late final DartSprites sprites;
  late final BoardBackdrop backdrop;
  late final Dartboard dartboard;
  late final FlyingDart flyingDart;
  late final RestingDart restingDart;
  late final HitPopupCanvas hitPopup;
  late final FlickController flickController;

  final List<StuckDart> stuckDarts = [];

  // ─── Turn Flow & Bot State ─────────────────────────────────────────────────
  bool _turnTransitioning = false;
  bool _isBotTurnActive = false;

  // ─── Online State ──────────────────────────────────────────────────────────
  /// Opponent darts waiting to be flown on this screen (in order).
  final List<DartHit> _remoteQueue = [];

  /// Your online turn ended here; input stays off until Firestore hands you
  /// the next turn ([beginOnlineTurn]).
  bool _awaitingOnlineTurn = false;

  DartsGame({required this.events, this.online});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    DartsAudio.init(this);

    sprites = await DartSprites.load();

    backdrop = BoardBackdrop(projection: projection);
    dartboard = Dartboard(projection: projection);
    flyingDart = FlyingDart(projection: projection, sprites: sprites);
    restingDart = RestingDart(projection: projection, sprites: sprites);
    hitPopup = HitPopupCanvas(projection: projection);
    flickController = FlickController(projection: projection);

    // Pure flick: pick the dart up, flick it. No aim preview.
    flickController.onPickUp = () {
      restingDart.visible = true;
    };

    flickController.onDrop = () {
      restingDart.visible = true; // it eases back to rest on its own
    };

    flickController.onThrow = (launchVel) {
      DartsAudio.playThrow();
      restingDart.visible = false;
      flickController.inputEnabled = false;

      flyingDart.launch(
        launchVel: launchVel,
        playerIndex: 0,
        onLanded: _onLocalDartLanded,
        startPxX: restingDart.tipX,
        startPxY: restingDart.tipY,
      );
    };

    await add(backdrop); // Priority 0
    await add(dartboard); // Priority 1
    await add(flyingDart.shadow); // Priority 3
    await add(flyingDart); // Priority 5
    await add(restingDart); // Priority 6
    await add(hitPopup); // Priority 8
    restingDart.resetToRest();

    final o = online;
    if (o != null) {
      // Online: nothing is thrown until Firestore says whose turn it is.
      flickController.inputEnabled = false;
      restingDart.visible = false;
      _awaitingOnlineTurn = true;
      o.attach(this); // after loading: turns touch the board and sprites
    } else {
      _setupCurrentDart();
    }
  }

  /// Puts a fresh dart in your hand and enables input when it's your throw.
  void _setupCurrentDart() {
    restingDart.resetToRest();
    flickController.inputEnabled =
        events.isMyTurn && !flyingDart.isFlying && !_turnTransitioning && !_isBotTurnActive;
  }

  /// [launched] is false for a shot-clock timeout: the dart counts as a miss
  /// but was never thrown, so nothing sticks in the wall.
  void _onLocalDartLanded(DartHit hit, {bool launched = true}) {
    dartboard.flashArea(hit);

    if (launched) {
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
    }

    if (!hit.isMiss) {
      DartsAudio.playHit(isBull: hit.isBull);
    } else {
      DartsAudio.playMiss();
    }

    final DartTurnResult result = events.dartLanded(hit);
    online?.onMyDart(hit, launched: launched);
    hitPopup.showHit(hit, isBust: result.bust, isCheckout: result.checkout);
    if (result.bust) {
      DartsAudio.playBust();
    }

    if (!result.turnOver && events.isMyTurn) {
      // More darts remaining in player's turn
      restingDart.visible = true;
      _setupCurrentDart();
    } else {
      // Turn is over (3 darts, bust, or checkout)
      restingDart.visible = false;
      flickController.inputEnabled = false;
      if (online != null) _awaitingOnlineTurn = true;
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

    // Online: Firestore hands out the next turn (see [beginOnlineTurn]). If
    // it already handed this phone a fresh turn while the darts were being
    // pulled, enable the throw now.
    if (online != null) {
      _turnTransitioning = false;
      if (events.isMyTurn && !_awaitingOnlineTurn) {
        restingDart.playerIndex = 0;
        restingDart.visible = true;
        _setupCurrentDart();
      }
      return;
    }

    // 3. Hand turn to bot in solo play
    if (!events.isMyTurn) {
      await _runBotTurn();
    }

    // Back to you. Input must be enabled AFTER the transition flag clears:
    // enabling it inside the bot's turn (while still transitioning) left
    // input off for good, which froze the game after the bot's turn.
    _turnTransitioning = false;
    if (!events.isMatchOver && events.isMyTurn) {
      restingDart.playerIndex = 0;
      restingDart.visible = true;
      _setupCurrentDart();
    }
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

      DartsAudio.playThrow();
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

          if (!hit.isMiss) {
            DartsAudio.playHit(isBull: hit.isBull);
          } else {
            DartsAudio.playMiss();
          }

          final DartTurnResult res = events.dartLanded(hit);
          hitPopup.showHit(hit, isBust: res.bust, isCheckout: res.checkout);
          if (res.bust) {
            DartsAudio.playBust();
          }

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
    // The caller ([_handlePlayerTurnOver]) hands the dart back to you.
  }

  /// Resets board and restarts a solo match for a rematch.
  void restartGame() {
    pullDarts();
    events.restartMatch();
    restingDart.playerIndex = 0;
    restingDart.visible = true;
    _turnTransitioning = false;
    _isBotTurnActive = false;
    _setupCurrentDart();
  }

  // ─── Pointer Input Hooks ───────────────────────────────────────────────────

  void onPointerDown(int pointerId, double x, double y) {
    DartsAudio.unlock();
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
    // Projection FIRST: the board and backdrop re-record themselves in their
    // own onGameResize (called by super) using these numbers. The other way
    // round they kept the old size, and the board drifted off-centre.
    projection.resize(size);
    super.onGameResize(size);
    if (isLoaded) restingDart.resetToRest();
  }

  @override
  void update(double dt) {
    flickController.update(dt);
    restingDart.setHold(
      flickController.isHolding,
      flickController.fingerX,
      flickController.fingerY,
    );

    // Clamp frame dt to avoid spiral of death on lag spikes (50 ms max)
    final double clampedDt =
        dt > DartsK.dtClamp ? DartsK.dtClamp : (dt < 0.0 ? 0.0 : dt);

    // Online: shot clocks, then the opponent's next dart once the board is free.
    online?.update(clampedDt);
    if (_remoteQueue.isNotEmpty && !flyingDart.isFlying && !_turnTransitioning) {
      _launchRemoteDart(_remoteQueue.removeAt(0));
    }

    super.update(dt);
  }

  /// Launches a test/debug dart toward target `(targetMmX, targetMmY)` on the dartboard.
  void throwDebugDart({
    int player = 0,
    double targetMmX = 0.0,
    double targetMmY = 0.0,
  }) {
    if (flyingDart.isFlying || _turnTransitioning || _isBotTurnActive) return;

    restingDart.visible = false;
    flickController.inputEnabled = false;

    final launchVel =
        FlickSolver.launchFor(targetMmX, targetMmY, DartsK.idealSpeed);

    DartsAudio.playThrow();
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

        if (!hit.isMiss) {
          DartsAudio.playHit(isBull: hit.isBull);
        } else {
          DartsAudio.playMiss();
        }

        final DartTurnResult result = events.dartLanded(hit);
        hitPopup.showHit(hit, isBust: result.bust, isCheckout: result.checkout);
        if (result.bust) {
          DartsAudio.playBust();
        }

        if (!result.turnOver && events.isMyTurn) {
          restingDart.visible = true;
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
    if (stuckDarts.isNotEmpty) {
      DartsAudio.playPull();
    }
    for (final dart in stuckDarts) {
      dart.startPull();
    }
    stuckDarts.clear();
  }

  @override
  void onRemove() {
    DartsAudio.leave(this);
    super.onRemove();
  }

  // ─── DartsOnlineGame Implementation ────────────────────────────────────────

  @override
  void beginOnlineTurn({
    required int round,
    required bool mine,
    required List<DartHit> turnDarts,
  }) {
    _remoteQueue.clear();
    _awaitingOnlineTurn = false;
    pullDarts();
    final int pIdx = mine ? 0 : 1;

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

    if (mine) {
      restingDart.playerIndex = 0;
      restingDart.visible = true;
      _setupCurrentDart();
    } else {
      flickController.onPointerCancel();
      flickController.inputEnabled = false;
      restingDart.visible = false;
    }
  }

  @override
  void playRemoteDart(DartHit hit) {
    _remoteQueue.add(hit);
  }

  /// Flies the opponent's dart and lands it exactly where their phone said
  /// it landed (the flight is only for show; [hit] is authoritative).
  void _launchRemoteDart(DartHit hit) {
    // Their shot clock ran out: a miss that was never thrown (nothing flies).
    if (hit.x == DartsLiveEvent.missX && hit.y == 0.0) {
      _onRemoteDartLanded(hit, launched: false);
      return;
    }
    final launchVel = FlickSolver.launchFor(hit.x, hit.y, DartsK.idealSpeed);
    DartsAudio.playThrow();
    flyingDart.launch(
      launchVel: launchVel,
      playerIndex: 1,
      onLanded: (_) => _onRemoteDartLanded(hit),
    );
  }

  void _onRemoteDartLanded(DartHit hit, {bool launched = true}) {
    dartboard.flashArea(hit);

    if (launched) {
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
    }

    if (!hit.isMiss) {
      DartsAudio.playHit(isBull: hit.isBull);
    } else {
      DartsAudio.playMiss();
    }

    final DartTurnResult res = events.dartLanded(hit);
    hitPopup.showHit(hit, isBust: res.bust, isCheckout: res.checkout);
    if (res.bust) {
      DartsAudio.playBust();
    }
    if (res.turnOver) {
      _handlePlayerTurnOver();
    }
  }

  @override
  void forceMiss() {
    if (!events.isMyTurn || flyingDart.isFlying || _awaitingOnlineTurn) return;
    flickController.onPointerCancel();
    flickController.inputEnabled = false;
    restingDart.visible = false;
    _onLocalDartLanded(
      DartScoring.score(DartsLiveEvent.missX, 0.0),
      launched: false,
    );
  }

  @override
  bool get isBusy =>
      flyingDart.isFlying ||
      _remoteQueue.isNotEmpty ||
      _isBotTurnActive ||
      _turnTransitioning;
}
