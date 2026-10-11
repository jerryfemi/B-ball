import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../models/cloud_match.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import 'audio/audio_engine.dart';
import 'components/background.dart';
import 'components/backboard_visual.dart';
import 'components/front_rim_visual.dart';
import 'components/hoop_physics.dart';
import 'components/ball.dart';
import 'components/ghost_ball.dart';
import 'components/ground.dart';
import 'match/match_session.dart';
import 'telemetry/shot_telemetry.dart';

/// Encapsulates details of a made basketball shot.
class ScoreEvent {
  final int points;
  final bool isSwish;
  final bool isBankShot;
  final int streak;

  const ScoreEvent({
    required this.points,
    required this.isSwish,
    required this.isBankShot,
    required this.streak,
  });
}

/// State of the 60-second basketball challenge.
enum GameModeState {
  ready,
  playing,
  gameOver,
  replay,
}

/// Detailed shooting metrics compiled at the conclusion of a 60-second round.
class GameRoundStats {
  final int score;
  final int bestScore;
  final int totalShots;
  final int madeShots;
  final int swishCount;
  final int bankCount;
  final int bestStreak;
  final bool isNewRecord;

  const GameRoundStats({
    required this.score,
    required this.bestScore,
    required this.totalShots,
    required this.madeShots,
    required this.swishCount,
    required this.bankCount,
    required this.bestStreak,
    required this.isNewRecord,
  });

  double get accuracy =>
      totalShots > 0 ? (madeShots / totalShots * 100.0) : 0.0;
}

/// Reactive ValueNotifier subclass allowing direct notification triggers on internal state mutations.
///
/// Resilient to reads after [dispose] — returns null instead of crashing,
/// which prevents JSNoSuchMethodError on Flutter Web hot restarts.
class MatchSessionNotifier extends ValueNotifier<MatchSession?> {
  MatchSessionNotifier(super.value);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  void notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  MatchSession? get value => _isDisposed ? null : super.value;

  @override
  set value(MatchSession? newValue) {
    if (!_isDisposed) {
      super.value = newValue;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!_isDisposed) {
      super.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_isDisposed) {
      super.removeListener(listener);
    }
  }
}

class BasketballGame extends Forge2DGame {
  BasketballGame() : super(gravity: Vector2(0, 30.0));

  static const double worldHeightInMeters = 20.0;
  static const int roundDurationSeconds = 60;
  MatchConfig currentMatchConfig = const MatchConfig();
  int currentRoundDurationSeconds = roundDurationSeconds;

  // Game state & scoring pipeline
  int score = 0;
  int currentStreak = 0;
  int bestStreak = 0;
  int totalShots = 0;
  int madeShots = 0;
  int swishCount = 0;
  int bankCount = 0;
  int bestStreakInRound = 0;
  double _secondAccumulator = 0.0;
  double _roundElapsedSeconds = 0.0;
  void Function(ScoreEvent event)? onScoreEvent;

  // Shot telemetry & ghost duel playback
  final List<RecordedShot> _currentRoundShots = [];
  RoundTelemetry? lastRoundTelemetry;
  RoundTelemetry? activeGhostTelemetry;
  int _nextGhostShotIndex = 0;

  // Reactive ValueNotifiers for zero-overhead Flutter UI binding
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> timeRemainingNotifier =
      ValueNotifier<int>(roundDurationSeconds);
  final ValueNotifier<int> bestScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<GameModeState> gameStateNotifier =
      ValueNotifier<GameModeState>(GameModeState.ready);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> ghostScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isGhostModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<GameRoundStats?> statsNotifier =
      ValueNotifier<GameRoundStats?>(null);
  final ValueNotifier<ScoreEvent?> scoreEventNotifier =
      ValueNotifier<ScoreEvent?>(null);

  // Match Mode & 1v1 turn progression
  final MatchSessionNotifier matchSessionNotifier =
      MatchSessionNotifier(null);
  final ValueNotifier<int> player1MatchScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> player2MatchScoreNotifier = ValueNotifier<int>(0);

  bool get isPaused => isPausedNotifier.value;
  bool _isManuallyPaused = false;
  bool get isManuallyPaused => _isManuallyPaused;

  void pauseGame({bool manual = true}) {
    if (gameStateNotifier.value == GameModeState.gameOver) return;
    if (manual) _isManuallyPaused = true;
    isPausedNotifier.value = true;
    pauseEngine();
  }

  void resumeGame() {
    _isManuallyPaused = false;
    isPausedNotifier.value = false;
    resumeEngine();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // Intentionally keep paused overlay active so player can resume on ready
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (gameStateNotifier.value == GameModeState.playing) {
          pauseGame(manual: false);
        }
        break;
    }
  }

  void recordShotAttempt() {
    if (gameStateNotifier.value == GameModeState.ready) {
      gameStateNotifier.value = GameModeState.playing;
    }
    totalShots++;
  }

  void recordShotTelemetry({
    required double startX,
    required double startY,
    required double startZ,
    required double vx,
    required double vy,
    required double vz,
    required double backspin,
  }) {
    final shot = RecordedShot(
      timestampMs: (_roundElapsedSeconds * 1000).toInt(),
      startX: startX,
      startY: startY,
      startZ: startZ,
      vx: vx,
      vy: vy,
      vz: vz,
      backspin: backspin,
    );
    _currentRoundShots.add(shot);
  }

  void registerScore({required bool isSwish, required bool isBankShot}) {
    madeShots++;
    if (isSwish) swishCount++;
    if (isBankShot) bankCount++;

    currentStreak++;
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }
    if (currentStreak > bestStreakInRound) {
      bestStreakInRound = currentStreak;
    }

    // Regulation GamePigeon scoring rules:
    // Base basket: 2 pts. Swish bonus: +1 pt (3 pts total). Bank shot bonus: +1 pt (3 pts total).
    // Consecutive streak bonus: +1 additional point for streaks of 3 or more.
    final basePoints = isSwish ? 3 : (isBankShot ? 3 : 2);
    final streakBonus = currentStreak >= 3 ? (currentStreak - 2) : 0;
    final points = basePoints + streakBonus;
    score += points;

    if (_currentRoundShots.isNotEmpty) {
      final lastIdx = _currentRoundShots.length - 1;
      final lastShot = _currentRoundShots[lastIdx];
      _currentRoundShots[lastIdx] = lastShot.copyWith(
        isMake: true,
        isSwish: isSwish,
        isBankShot: isBankShot,
        points: points,
      );
    }

    final event = ScoreEvent(
      points: points,
      isSwish: isSwish,
      isBankShot: isBankShot,
      streak: currentStreak,
    );

    scoreNotifier.value = score;
    streakNotifier.value = currentStreak;
    scoreEventNotifier.value = event;
    onScoreEvent?.call(event);

    final session = matchSessionNotifier.value;
    if (session != null) {
      if (session.activePlayerIndex == 0) {
        player1MatchScoreNotifier.value =
            session.player1.scoreUpToRound(session.currentRoundIndex) + score;
      } else {
        player2MatchScoreNotifier.value =
            session.player2.scoreUpToRound(session.currentRoundIndex) + score;
      }
    }

    // If game ended, update stats in case of buzzer-beater basket
    if (gameStateNotifier.value == GameModeState.gameOver) {
      _compileStats();
    }
  }

  void resetStreak() {
    currentStreak = 0;
    streakNotifier.value = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameStateNotifier.value == GameModeState.playing &&
        !isPaused &&
        timeRemainingNotifier.value > 0) {
      _roundElapsedSeconds += dt;
      _playGhostShotsIfNeeded();

      _secondAccumulator += dt;
      if (_secondAccumulator >= 1.0) {
        _secondAccumulator -= 1.0;
        final nextTime = timeRemainingNotifier.value - 1;
        timeRemainingNotifier.value = nextTime;
        if (nextTime <= 0) {
          _onTimeExpired();
        }
      }
    } else if (gameStateNotifier.value == GameModeState.replay && !isPaused) {
      _roundElapsedSeconds += dt;
      _playGhostShotsIfNeeded();

      _secondAccumulator += dt;
      if (_secondAccumulator >= 1.0) {
        _secondAccumulator -= 1.0;
        final nextTime = timeRemainingNotifier.value - 1;
        timeRemainingNotifier.value = nextTime;
        if (nextTime <= 0) {
          _onReplayFinished();
        }
      }

      // Check if all replay shots have executed and settled
      final ghost = activeGhostTelemetry;
      if (ghost != null && _nextGhostShotIndex >= ghost.shots.length) {
        final activeReplayBalls = world.children.whereType<GhostBasketball>();
        final double lastShotTimeSec = ghost.shots.isNotEmpty
            ? (ghost.shots.last.timestampMs / 1000.0)
            : 0.0;
        if (activeReplayBalls.isEmpty &&
            _roundElapsedSeconds >= lastShotTimeSec + 2.5) {
          _onReplayFinished();
        }
      }
    }
  }

  void _playGhostShotsIfNeeded() {
    final ghost = activeGhostTelemetry;
    if (ghost == null) return;

    final currentElapsedMs = (_roundElapsedSeconds * 1000).toInt();
    while (_nextGhostShotIndex < ghost.shots.length) {
      final nextShot = ghost.shots[_nextGhostShotIndex];
      if (currentElapsedMs >= nextShot.timestampMs) {
        world.add(GhostBasketball(shot: nextShot));
        _nextGhostShotIndex++;
      } else {
        break;
      }
    }
  }

  void onGhostScored({
    required int points,
    required bool isSwish,
    required bool isBankShot,
  }) {
    if (gameStateNotifier.value == GameModeState.replay) {
      final session = matchSessionNotifier.value;
      if (session != null &&
          session.phase == MatchTurnPhase.watchingOpponentReplay) {
        // Increment opponent's live scoreboard bay as each ghost basket is made
        if (session.activePlayerIndex == 1) {
          player1MatchScoreNotifier.value += points;
        } else {
          player2MatchScoreNotifier.value += points;
        }
      }
      final event = ScoreEvent(
        points: points,
        isSwish: isSwish,
        isBankShot: isBankShot,
        streak: 0,
      );
      scoreEventNotifier.value = event;
      onScoreEvent?.call(event);
    } else {
      ghostScoreNotifier.value += points;
    }
    if (isSwish) {
      AudioEngine.playSwish();
    }
  }

  void _onReplayFinished() {
    final session = matchSessionNotifier.value;
    if (session != null &&
        session.phase == MatchTurnPhase.watchingOpponentReplay) {
      // Finished watching opponent's performance: start current player's turn!
      skipOpponentReplayAndStartTurn();
    } else {
      stopReplayMode();
    }
  }

  void _onTimeExpired() {
    AudioEngine.playBuzzer();
    lastRoundTelemetry = RoundTelemetry(
      roundScore: score,
      madeShots: madeShots,
      totalShots: totalShots,
      shots: List.unmodifiable(_currentRoundShots),
    );

    final session = matchSessionNotifier.value;
    if (session != null) {
      _finishMatchTurn(session);
    } else {
      gameStateNotifier.value = GameModeState.gameOver;
      _compileStats();
    }
  }

  void _finishMatchTurn(MatchSession session) {
    session.activePlayer.roundScores.add(score);
    if (lastRoundTelemetry != null) {
      session.activePlayer.roundTelemetries.add(lastRoundTelemetry!);
    }
    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    if (session.mode == MatchGameMode.onlineCloud1v1 &&
        session.cloudMatchId != null &&
        lastRoundTelemetry != null) {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        unawaited(FirestoreMatchService.instance.submitTurn(
          matchId: session.cloudMatchId!,
          shooterUid: user.uid,
          roundIndex: session.currentRoundNumber,
          telemetry: lastRoundTelemetry!,
        ));
      }
    }

    final isBothFinished = session.isFinalRound &&
        (session.mode == MatchGameMode.onlineCloud1v1
            ? session.player2.roundScores.length >= session.totalRounds
            : session.activePlayerIndex == 1);

    if (isBothFinished) {
      // Both players have completed all rounds! Direct to Winner Podium!
      session.phase = MatchTurnPhase.matchComplete;
    } else {
      session.phase = MatchTurnPhase.turnComplete;
    }
    matchSessionNotifier.notify();
    gameStateNotifier.value = GameModeState.gameOver;
  }

  void _compileStats() {
    final bool isNew = score > bestScoreNotifier.value;
    if (isNew) {
      bestScoreNotifier.value = score;
    }
    statsNotifier.value = GameRoundStats(
      score: score,
      bestScore: bestScoreNotifier.value,
      totalShots: totalShots,
      madeShots: madeShots,
      swishCount: swishCount,
      bankCount: bankCount,
      bestStreak: bestStreakInRound,
      isNewRecord: isNew,
    );
  }

  void startReplayMode() {
    if (lastRoundTelemetry == null || lastRoundTelemetry!.shots.isEmpty) return;

    activeGhostTelemetry = lastRoundTelemetry;
    isGhostModeNotifier.value = false;
    ghostScoreNotifier.value = 0;
    _nextGhostShotIndex = 0;
    _roundElapsedSeconds = 0.0;
    _secondAccumulator = 0.0;

    score = 0;
    currentStreak = 0;
    scoreNotifier.value = 0;
    streakNotifier.value = 0;
    timeRemainingNotifier.value = roundDurationSeconds;

    if (isPaused) {
      resumeGame();
    }

    // Clear active balls from world
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }

    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }

    gameStateNotifier.value = GameModeState.replay;
  }

  void stopReplayMode() {
    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }
    activeGhostTelemetry = null;

    if (lastRoundTelemetry != null) {
      gameStateNotifier.value = GameModeState.gameOver;
    } else {
      restartRound();
    }
  }

  void restartRound({bool enableGhostReplay = false, bool resetToSolo = true}) {
    if (resetToSolo) {
      currentRoundDurationSeconds = roundDurationSeconds;
      matchSessionNotifier.value = null;
      player1MatchScoreNotifier.value = 0;
      player2MatchScoreNotifier.value = 0;
    }

    if (enableGhostReplay && lastRoundTelemetry != null) {
      activeGhostTelemetry = lastRoundTelemetry;
      isGhostModeNotifier.value = false;
    } else {
      activeGhostTelemetry = null;
      isGhostModeNotifier.value = false;
    }

    ghostScoreNotifier.value = 0;
    _nextGhostShotIndex = 0;
    _roundElapsedSeconds = 0.0;
    _currentRoundShots.clear();

    score = 0;
    currentStreak = 0;
    totalShots = 0;
    madeShots = 0;
    swishCount = 0;
    bankCount = 0;
    bestStreakInRound = 0;
    _secondAccumulator = 0.0;

    scoreNotifier.value = 0;
    streakNotifier.value = 0;
    timeRemainingNotifier.value = currentRoundDurationSeconds;
    statsNotifier.value = null;
    gameStateNotifier.value = GameModeState.ready;

    if (isPaused) {
      resumeGame();
    }

    // Clear active balls from world
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }

    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }

    _spawnReadyBall(animate: true);
  }

  /// Dispatches the completed turn to the recipient (GamePigeon turn handoff).
  ///
  /// Immediately transitions recipient to automatically spectate the opponent's
  /// recorded ghost round, with an omnipresent "SKIP" trigger to jump into shooting.
  void sendMatchTurn() {
    final session = matchSessionNotifier.value;
    if (session == null) return;

    if (session.activePlayerIndex == 0) {
      // Player 1 finished -> Hand over to Player 2
      session.activePlayerIndex = 1;
      matchSessionNotifier.notify();
      startOpponentReplay();
    } else {
      // Player 2 finished their turn
      if (session.isFinalRound) {
        // All rounds complete -> show celebratory Match Winner Podium
        session.phase = MatchTurnPhase.matchComplete;
        matchSessionNotifier.notify();
        gameStateNotifier.value = GameModeState.gameOver;
      } else {
        // Advance to next round (e.g. Round 1 -> Round 2)
        session.currentRoundIndex++;
        session.activePlayerIndex = 0; // Back to Player 1
        matchSessionNotifier.notify();
        startOpponentReplay();
      }
    }
  }

  void startPassAndPlayMatch({MatchConfig? config, int? totalRounds}) {
    if (config != null) {
      currentMatchConfig = config;
    } else if (totalRounds != null) {
      currentMatchConfig = currentMatchConfig.copyWith(totalRounds: totalRounds);
    }
    currentRoundDurationSeconds = currentMatchConfig.roundDurationSeconds;

    final session = MatchSession(
      mode: MatchGameMode.passAndPlay1v1,
      config: currentMatchConfig,
      totalRounds: currentMatchConfig.totalRounds,
      currentRoundIndex: 0,
      activePlayerIndex: 0,
      phase: MatchTurnPhase.playingTurn,
    );
    matchSessionNotifier.value = session;
    player1MatchScoreNotifier.value = 0;
    player2MatchScoreNotifier.value = 0;

    _prepareTurn();
  }

  /// Initiates or resumes an online asynchronous 1v1 match from a synced [CloudMatch].
  void startCloudMatch(CloudMatch match, String myUid) {
    final session = MatchSession.fromCloudMatch(match, myUid);
    currentMatchConfig = session.config;
    currentRoundDurationSeconds = match.roundDurationSeconds;
    matchSessionNotifier.value = session;

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    if (session.phase == MatchTurnPhase.watchingOpponentReplay) {
      startOpponentReplay();
    } else {
      startMatchTurn();
    }
  }

  void startMatchTurn() {
    final session = matchSessionNotifier.value;
    if (session == null) return;

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    session.phase = MatchTurnPhase.playingTurn;
    matchSessionNotifier.notify();
    activeGhostTelemetry = null;

    _prepareTurn();
  }

  void startOpponentReplay() {
    final session = matchSessionNotifier.value;
    if (session == null) return;

    final opponentTelemetry = session.opponentPlayer.latestTelemetry;
    if (opponentTelemetry == null || opponentTelemetry.shots.isEmpty) {
      startMatchTurn();
      return;
    }

    session.phase = MatchTurnPhase.watchingOpponentReplay;
    matchSessionNotifier.notify();

    // Start opponent score at baseline strictly prior to the round being replayed
    final opponent = session.opponentPlayer;
    final replayedRoundIndex =
        (opponent.roundTelemetries.length - 1).clamp(0, session.totalRounds - 1);
    final opponentBaseline = opponent.scoreUpToRound(replayedRoundIndex);
    if (session.activePlayerIndex == 1) {
      // Opponent is Player 1 (YOU bay)
      player1MatchScoreNotifier.value = opponentBaseline;
      player2MatchScoreNotifier.value = session.player2.totalScore;
    } else {
      // Opponent is Player 2 (THEM bay)
      player1MatchScoreNotifier.value = session.player1.totalScore;
      player2MatchScoreNotifier.value = opponentBaseline;
    }

    activeGhostTelemetry = opponentTelemetry;
    _nextGhostShotIndex = 0;
    _roundElapsedSeconds = 0.0;
    _secondAccumulator = 0.0;
    timeRemainingNotifier.value = currentRoundDurationSeconds;

    if (isPaused) {
      resumeGame();
    }

    // Clear live balls
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }

    gameStateNotifier.value = GameModeState.replay;
  }

  void skipOpponentReplayAndStartTurn() {
    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }
    activeGhostTelemetry = null;

    final session = matchSessionNotifier.value;
    if (session != null) {
      // Snap both players' scores to their full completed totals
      player1MatchScoreNotifier.value = session.player1.totalScore;
      player2MatchScoreNotifier.value = session.player2.totalScore;

      session.phase = MatchTurnPhase.playingTurn;
      matchSessionNotifier.notify();
    }

    _prepareTurn();
  }

  void exitToSoloMode() {
    currentRoundDurationSeconds = roundDurationSeconds;
    matchSessionNotifier.value = null;
    player1MatchScoreNotifier.value = 0;
    player2MatchScoreNotifier.value = 0;
    activeGhostTelemetry = null;
    restartRound(resetToSolo: true);
  }

  void _prepareTurn() {
    score = 0;
    currentStreak = 0;
    totalShots = 0;
    madeShots = 0;
    swishCount = 0;
    bankCount = 0;
    bestStreakInRound = 0;
    _secondAccumulator = 0.0;
    _roundElapsedSeconds = 0.0;
    _currentRoundShots.clear();
    _nextGhostShotIndex = 0;
    activeGhostTelemetry = null;

    scoreNotifier.value = 0;
    streakNotifier.value = 0;
    timeRemainingNotifier.value = currentRoundDurationSeconds;
    statsNotifier.value = null;
    gameStateNotifier.value = GameModeState.ready;

    if (isPaused) {
      resumeGame();
    }

    // Clear active balls from world
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }

    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }

    _spawnReadyBall(animate: true);
  }

  @override
  Color backgroundColor() => const Color(0xFF090D16);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait([
      AudioEngine.init(),
      Basketball.loadProgram(),
    ]);

    // 1. Fluid Full-Screen Viewport
    final metersToPixels = size.y / worldHeightInMeters;

    final viewfinder = camera.viewfinder as Forge2DViewfinder;
    viewfinder.metersToPixels = metersToPixels;
    viewfinder.zoom = 1.0;
    // Set anchor to topCenter so that x=0 is always the horizontal middle of the screen.
    viewfinder.anchor = Anchor.topCenter;
    viewfinder.position = Vector2.zero();

    // 2. Procedural Arena & Hardwood Court Background
    camera.backdrop.add(GameBackground());

    // 3. Ground physics floor at the bottom of the court
    final floorYInMeters = 19.2;
    world.add(
      Ground(
        groundPosition: Vector2(0, floorYInMeters),
        groundSize: Vector2(
          100.0,
          1.0,
        ), // Arbitrarily wide to cover any screen width
      ),
    );

    // 4. Hoop positioned in world coordinates (25% down, horizontally centered at x=0)
    final hoopCenterInMeters = Vector2(0, 5.0);
    const hoopWidthInMeters = 1.8; // Increased from 1.4 to make hoop bigger

    // 5. 2.5D Layering Pipeline:
    // Priority 1: Backboard, wall mounts, rear rim half, and rear net mesh
    world.add(
      BackboardVisual(
        position: hoopCenterInMeters,
        hoopWidth: hoopWidthInMeters,
      ),
    );

    // Physics colliders (circles for rims, deflector plate, score sensor)
    world.add(
      HoopPhysics(
        hoopCenterInMeters: hoopCenterInMeters,
        hoopWidthInMeters: hoopWidthInMeters,
      ),
    );

    // Priority 2: Basketball (passes over backboard, behind front rim)
    _spawnReadyBall();

    // Priority 3: Front rim half and front net cords
    world.add(
      FrontRimVisual(
        position: hoopCenterInMeters,
        hoopWidth: hoopWidthInMeters,
      ),
    );
  }

  double _lastSpawnX = 0.0;
  final math.Random _rng = math.Random();

  double _pickNextSpawnX() {
    // Diverse shooting positions along the bottom baseline (in Forge2D meters)
    const candidates = [-1.4, -0.7, 0.0, 0.7, 1.4];
    final options =
        candidates.where((x) => (x - _lastSpawnX).abs() >= 0.5).toList();
    final chosen = options[_rng.nextInt(options.length)];
    _lastSpawnX = chosen;
    return chosen;
  }

  void _spawnReadyBall({bool animate = false}) {
    if (gameStateNotifier.value == GameModeState.gameOver) return;

    final spawnX = animate ? _pickNextSpawnX() : 0.0;
    final ball = Basketball(
      // Rest directly on the hardwood court floor at the chosen baseline spot
      initialPosition: Vector2(spawnX, 18.62),
      radius: 0.58,
      animateEntrance: animate,
      onLaunched: () {
        if (gameStateNotifier.value == GameModeState.gameOver) return;

        // Snappy feed of next ball: 250ms delay managed via Flame TimerComponent
        add(
          TimerComponent(
            period: 0.25,
            removeOnFinish: true,
            onTick: () {
              if (isLoaded &&
                  (gameStateNotifier.value == GameModeState.playing ||
                      gameStateNotifier.value == GameModeState.ready)) {
                _spawnReadyBall(animate: true);
              }
            },
          ),
        );
      },
    );
    world.add(ball);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final viewfinder = camera.viewfinder as Forge2DViewfinder;
      viewfinder.metersToPixels = size.y / worldHeightInMeters;
    }
  }

  @override
  void onRemove() {
    AudioEngine.dispose();
    scoreNotifier.dispose();
    streakNotifier.dispose();
    timeRemainingNotifier.dispose();
    bestScoreNotifier.dispose();
    gameStateNotifier.dispose();
    isPausedNotifier.dispose();
    ghostScoreNotifier.dispose();
    isGhostModeNotifier.dispose();
    statsNotifier.dispose();
    scoreEventNotifier.dispose();
    matchSessionNotifier.dispose();
    player1MatchScoreNotifier.dispose();
    player2MatchScoreNotifier.dispose();
    super.onRemove();
  }
}
