import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cloud_match.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import '../services/vatar/vatar_bridge.dart';
import 'audio/audio_engine.dart';
import 'components/background.dart';
import 'components/background/distant_wall_renderer.dart';
import 'components/background/court_floor_renderer.dart';
import 'components/backboard_visual.dart';
import 'components/rear_rim_visual.dart';
import 'components/front_rim_visual.dart';
import 'components/hoop_physics.dart';
import 'components/ball.dart';
import 'components/ghost_ball.dart';
import 'components/ground.dart';
import 'match/match_session.dart';
import 'physics/shot_difficulty.dart';
import 'telemetry/shot_telemetry.dart';
import 'ui/match/live_turn_transition_overlay.dart';

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
enum GameModeState { ready, playing, gameOver, replay }

/// Connection and grace period states while spectating an opponent in live 1v1 showdowns.
enum SpectatorConnectionStatus {
  connected,
  aimingOrIdle,
  reconnecting,
  finalizingTurn,
  opponentAbandoned,
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
  final ValueNotifier<bool> streakFxEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<int> timeRemainingNotifier = ValueNotifier<int>(
    roundDurationSeconds,
  );
  final ValueNotifier<int> bestScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isTourActiveNotifier = ValueNotifier<bool>(false);

  /// GlobalKeys to locate scoreboard widgets dynamically for tour spotlight
  final GlobalKey playerAvatarKey = GlobalKey();
  final GlobalKey rightFlankKey = GlobalKey();

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
  final MatchSessionNotifier matchSessionNotifier = MatchSessionNotifier(null);
  final ValueNotifier<int> player1MatchScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> player2MatchScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<LiveTransitionData?> liveTransitionNotifier =
      ValueNotifier<LiveTransitionData?>(null);

  // Live spectator connection & grace guard
  final ValueNotifier<SpectatorConnectionStatus> spectatorStatusNotifier =
      ValueNotifier<SpectatorConnectionStatus>(
        SpectatorConnectionStatus.connected,
      );
  final ValueNotifier<int> spectatorGraceSecondsNotifier = ValueNotifier<int>(
    15,
  );
  DateTime? _lastLiveShotReceivedAt;
  double _zeroClockGraceElapsed = 0.0;
  static const double spectatorAimingThresholdSeconds = 6.0;
  static const double spectatorReconnectingThresholdSeconds = 12.0;
  static const double spectatorZeroClockGraceLimitSeconds = 15.0;

  StreamSubscription<RecordedShot>? _liveShotSubscription;
  StreamSubscription<CloudMatch?>? _liveMatchSubscription;
  String? _currentSubscribedMatchId;
  String? _currentActiveTurnUid;

  /// Difficulty preset for solo play (configurable in the pause menu).
  final ValueNotifier<ShotDifficulty> soloDifficultyNotifier =
      ValueNotifier<ShotDifficulty>(ShotDifficulty.easy);

  /// Active difficulty preset derived from the current match room, or soloDifficultyNotifier in solo play.
  ShotDifficulty get currentDifficulty =>
      matchSessionNotifier.value?.config.difficulty ??
      soloDifficultyNotifier.value;

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

  /// Toggles player's streak visual effects (Flame at 6+, Lightning at 11+)
  /// and persists their preference to local SharedPreferences.
  Future<void> toggleStreakFx() async {
    final nextVal = !streakFxEnabledNotifier.value;
    streakFxEnabledNotifier.value = nextVal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('streak_fx_enabled', nextVal);
    } catch (e) {
      debugPrint('[BasketballGame] Error persisting streak_fx_enabled: $e');
    }
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
      streak: streakNotifier.value,
    );
    _currentRoundShots.add(shot);

    final session = matchSessionNotifier.value;
    if (session != null &&
        session.mode == MatchGameMode.onlineCloud1v1 &&
        session.cloudMatchId != null &&
        session.phase == MatchTurnPhase.playingTurn) {
      final myUid = AuthService.instance.currentUser?.uid ?? '';
      unawaited(
        FirestoreMatchService.instance.broadcastLiveShot(
          matchId: session.cloudMatchId!,
          shot: shot,
          shooterUid: myUid,
          shotIndex: _currentRoundShots.length,
        ),
      );
    }
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
    if (session != null &&
        session.phase != MatchTurnPhase.waitingForOpponentTurn) {
      if (session.activePlayerIndex == 0) {
        player1MatchScoreNotifier.value =
            session.player1.scoreUpToRound(session.currentRoundIndex) + score;
      } else {
        player2MatchScoreNotifier.value =
            session.player2.scoreUpToRound(session.currentRoundIndex) + score;
      }

      if (session.mode == MatchGameMode.onlineCloud1v1 &&
          session.cloudMatchId != null &&
          session.phase == MatchTurnPhase.playingTurn) {
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        unawaited(
          FirestoreMatchService.instance.updateLiveShooterScore(
            matchId: session.cloudMatchId!,
            currentRoundScore: score,
            shooterUid: myUid,
          ),
        );
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

    final session = matchSessionNotifier.value;
    final isSpectatingLive =
        session != null &&
        session.phase == MatchTurnPhase.watchingLiveOpponent &&
        !isPaused;

    if (isSpectatingLive) {
      _updateLiveSpectatorStatus(dt);
    }

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
          if (session != null &&
              session.phase == MatchTurnPhase.watchingLiveOpponent) {
            // Live spectator clock reached zero; wait for opponent's turn submission via Firestore
          } else {
            _onTimeExpired();
          }
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

  void _updateLiveSpectatorStatus(double dt) {
    if (spectatorStatusNotifier.value ==
        SpectatorConnectionStatus.opponentAbandoned) {
      return;
    }

    if (timeRemainingNotifier.value > 0) {
      final now = DateTime.now();
      final lastShot = _lastLiveShotReceivedAt;
      final idleSeconds = lastShot != null
          ? now.difference(lastShot).inMilliseconds / 1000.0
          : _roundElapsedSeconds;

      if (idleSeconds >= spectatorReconnectingThresholdSeconds) {
        if (spectatorStatusNotifier.value !=
            SpectatorConnectionStatus.reconnecting) {
          spectatorStatusNotifier.value =
              SpectatorConnectionStatus.reconnecting;
        }
      } else if (idleSeconds >= spectatorAimingThresholdSeconds) {
        if (spectatorStatusNotifier.value !=
            SpectatorConnectionStatus.aimingOrIdle) {
          spectatorStatusNotifier.value =
              SpectatorConnectionStatus.aimingOrIdle;
        }
      } else {
        if (spectatorStatusNotifier.value !=
            SpectatorConnectionStatus.connected) {
          spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
        }
      }
    } else {
      _zeroClockGraceElapsed += dt;
      final remainingGrace =
          (spectatorZeroClockGraceLimitSeconds - _zeroClockGraceElapsed)
              .clamp(0.0, spectatorZeroClockGraceLimitSeconds)
              .ceil();
      if (spectatorGraceSecondsNotifier.value != remainingGrace) {
        spectatorGraceSecondsNotifier.value = remainingGrace;
      }

      if (_zeroClockGraceElapsed >= spectatorZeroClockGraceLimitSeconds) {
        if (spectatorStatusNotifier.value !=
            SpectatorConnectionStatus.opponentAbandoned) {
          spectatorStatusNotifier.value =
              SpectatorConnectionStatus.opponentAbandoned;
        }
      } else {
        if (spectatorStatusNotifier.value !=
            SpectatorConnectionStatus.finalizingTurn) {
          spectatorStatusNotifier.value =
              SpectatorConnectionStatus.finalizingTurn;
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
    final session = matchSessionNotifier.value;
    final is1v1Spectating =
        session != null &&
        (session.phase == MatchTurnPhase.watchingOpponentReplay ||
            session.phase == MatchTurnPhase.watchingLiveOpponent);

    if (gameStateNotifier.value == GameModeState.replay || is1v1Spectating) {
      if (is1v1Spectating &&
          session.phase == MatchTurnPhase.watchingOpponentReplay) {
        // Increment opponent's scoreboard bay only during deterministic recorded replay
        if (session.opponentPlayer == session.player2) {
          player2MatchScoreNotifier.value += points;
        } else {
          player1MatchScoreNotifier.value += points;
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
        unawaited(
          FirestoreMatchService.instance.submitTurn(
            matchId: session.cloudMatchId!,
            shooterUid: user.uid,
            roundIndex: session.currentRoundNumber,
            telemetry: lastRoundTelemetry!,
          ),
        );
      }
    }

    final isBothFinished =
        session.isFinalRound &&
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
      _saveBestScore(score);
    }
    // Automatically submit score to Lagos Life leaderboard when running embedded
    if (VatarBridge.instance.isInsideVatar && score > 0) {
      unawaited(VatarBridge.instance.submitScore(score));
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

  void _saveBestScore(int newBest) {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('b_ball_best_score', newBest);
        final user = AuthService.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'highScore': newBest,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
                'expireAt': Timestamp.fromDate(
                  DateTime.now().add(const Duration(days: 30)),
                ),
              }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[BasketballGame] Error saving best score: $e');
      }
    }());
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
      currentMatchConfig = currentMatchConfig.copyWith(
        totalRounds: totalRounds,
      );
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

  /// Initiates or resumes an online 1v1 match from a synced [CloudMatch].
  void startCloudMatch(CloudMatch match, String myUid) {
    final session = MatchSession.fromCloudMatch(match, myUid);
    currentMatchConfig = session.config;
    currentRoundDurationSeconds = match.roundDurationSeconds;
    matchSessionNotifier.value = session;

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    _setupCloudMatchSync(match, myUid);

    if (session.phase == MatchTurnPhase.watchingLiveOpponent) {
      startLiveSpectatorMode();
    } else if (session.phase == MatchTurnPhase.watchingOpponentReplay) {
      startOpponentReplay();
    } else {
      startMatchTurn();
    }
  }

  void _setupCloudMatchSync(CloudMatch match, String myUid) {
    if (_currentSubscribedMatchId == match.id &&
        _liveMatchSubscription != null) {
      return;
    }
    _currentSubscribedMatchId = match.id;
    _currentActiveTurnUid = match.activeTurnPlayerUid;

    _liveMatchSubscription?.cancel();
    _liveMatchSubscription = FirestoreMatchService.instance
        .streamMatch(match.id)
        .listen((updatedMatch) {
          _onCloudMatchUpdated(updatedMatch, myUid);
        });
  }

  void _onCloudMatchUpdated(CloudMatch? updatedMatch, String myUid) {
    if (updatedMatch == null) return;
    final session = matchSessionNotifier.value;
    if (session == null || session.cloudMatchId != updatedMatch.id) return;

    // Dynamically connect Player 2 when they join via code or accept invite
    if (session.isWaitingForOpponent && updatedMatch.player2 != null) {
      session.isWaitingForOpponent = false;
      session.player2 = session.player2.copyWith(
        id: updatedMatch.player2!.uid,
        name: updatedMatch.player2!.displayName,
        avatar: updatedMatch.player2!.avatarEmoji,
      );
      currentMatchConfig = currentMatchConfig.copyWith(
        player2Name: updatedMatch.player2!.displayName,
        player2Avatar: updatedMatch.player2!.avatarEmoji,
        player2Uid: updatedMatch.player2!.uid,
      );
      session.config = currentMatchConfig;
      matchSessionNotifier.notify();
    }

    final isP1 = updatedMatch.player1.uid == myUid;
    final myCloudPlayer = isP1 ? updatedMatch.player1 : updatedMatch.player2;
    final oppCloudPlayer = isP1 ? updatedMatch.player2 : updatedMatch.player1;

    // Synchronize round scores from cloud match unconditionally
    if (myCloudPlayer != null) {
      session.player1.roundScores
        ..clear()
        ..addAll(myCloudPlayer.roundScores);
    }
    if (oppCloudPlayer != null) {
      session.player2.roundScores
        ..clear()
        ..addAll(oppCloudPlayer.roundScores);
    }

    // Check if match was completed or forfeited
    if (updatedMatch.status == MatchStatus.completed ||
        updatedMatch.status == MatchStatus.forfeited) {
      if (updatedMatch.status == MatchStatus.forfeited) {
        if (updatedMatch.forfeitedByUid != null &&
            updatedMatch.forfeitedByUid!.isNotEmpty) {
          if (updatedMatch.forfeitedByUid == myUid) {
            session.forfeitWinner = session.player2;
          } else {
            session.forfeitWinner = session.player1;
          }
        } else if (updatedMatch.winnerUid != null &&
            updatedMatch.winnerUid!.isNotEmpty) {
          if (updatedMatch.winnerUid == session.player1.id) {
            session.forfeitWinner = session.player1;
          } else if (updatedMatch.winnerUid == session.player2.id) {
            session.forfeitWinner = session.player2;
          }
        }
        if (session.forfeitWinner == session.player1) {
          AudioEngine.playSwish();
        }
      } else if (updatedMatch.winnerUid != null &&
          updatedMatch.winnerUid!.isNotEmpty) {
        if (updatedMatch.winnerUid == session.player1.id) {
          session.forfeitWinner = session.player1;
        } else if (updatedMatch.winnerUid == session.player2.id) {
          session.forfeitWinner = session.player2;
        }
      }

      _liveShotSubscription?.cancel();
      _liveShotSubscription = null;
      _liveMatchSubscription?.cancel();
      _liveMatchSubscription = null;

      spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
      session.phase = MatchTurnPhase.matchComplete;
      gameStateNotifier.value = GameModeState.gameOver;
      player1MatchScoreNotifier.value = session.player1.totalScore;
      player2MatchScoreNotifier.value = session.player2.totalScore;
      matchSessionNotifier.notify();
      return;
    }

    final isMyTurn = updatedMatch.isMyTurn(myUid);
    final previousTurnUid = _currentActiveTurnUid;
    _currentActiveTurnUid = updatedMatch.activeTurnPlayerUid;

    // Detect turn alternation between players
    if (previousTurnUid != null &&
        previousTurnUid != updatedMatch.activeTurnPlayerUid &&
        updatedMatch.activeTurnPlayerUid.isNotEmpty) {
      session.currentRoundIndex = (updatedMatch.currentRound - 1).clamp(
        0,
        session.totalRounds - 1,
      );
      spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
      _zeroClockGraceElapsed = 0.0;
      spectatorGraceSecondsNotifier.value = 15;
      _lastLiveShotReceivedAt = null;

      // Trigger interstitial countdown
      _triggerLiveTurnTransition(
        isMyTurnNow: isMyTurn,
        opponentName: session.opponentPlayer.name,
        currentRound: updatedMatch.currentRound,
        totalRounds: updatedMatch.totalRounds,
        onFinished: () {
          if (isMyTurn) {
            startMatchTurn();
          } else {
            startLiveSpectatorMode();
          }
        },
      );
      return;
    }

    // Sync live scoreboard ticks if opponent is shooting and we are spectating
    if (session.phase == MatchTurnPhase.watchingLiveOpponent &&
        updatedMatch.liveShooterScore != null) {
      final oppBase = session.opponentPlayer.scoreUpToRound(
        session.currentRoundIndex,
      );
      final totalLive = oppBase + updatedMatch.liveShooterScore!;
      if (session.activePlayerIndex == 1) {
        player2MatchScoreNotifier.value = totalLive;
      } else {
        player1MatchScoreNotifier.value = totalLive;
      }
    }
  }

  void _triggerLiveTurnTransition({
    required bool isMyTurnNow,
    required String opponentName,
    required int currentRound,
    required int totalRounds,
    required VoidCallback onFinished,
  }) {
    liveTransitionNotifier.value = LiveTransitionData(
      isMyTurnNow: isMyTurnNow,
      opponentName: opponentName,
      currentRound: currentRound,
      totalRounds: totalRounds,
      onFinished: () {
        liveTransitionNotifier.value = null;
        onFinished();
      },
    );
  }

  void startLiveSpectatorMode() {
    final session = matchSessionNotifier.value;
    if (session == null) return;

    session.phase = MatchTurnPhase.watchingLiveOpponent;
    session.activePlayerIndex = 1; // Opponent is active shooter
    matchSessionNotifier.notify();

    _roundElapsedSeconds = 0.0;
    _secondAccumulator = 0.0;
    _zeroClockGraceElapsed = 0.0;
    _lastLiveShotReceivedAt = DateTime.now();
    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    spectatorGraceSecondsNotifier.value = 15;
    timeRemainingNotifier.value = currentRoundDurationSeconds;

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    // Clear live player balls and residual ghost balls so screen is pure courtside
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }
    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }

    if (isPaused) {
      resumeGame();
    }

    // Initialize in ready mode sitting at full clock (01:00); starts ticking when shooter's first shot fires
    gameStateNotifier.value = GameModeState.ready;

    // Connect real-time live shot listener
    _liveShotSubscription?.cancel();
    if (session.cloudMatchId != null) {
      _liveShotSubscription = FirestoreMatchService.instance
          .streamLiveShots(session.cloudMatchId!)
          .listen(
            (shot) {
              _lastLiveShotReceivedAt = DateTime.now();
              if (timeRemainingNotifier.value > 0 &&
                  spectatorStatusNotifier.value !=
                      SpectatorConnectionStatus.connected) {
                spectatorStatusNotifier.value =
                    SpectatorConnectionStatus.connected;
              }
              spawnLiveGhostShot(shot);
            },
            onError: (err) {
              debugPrint('[BasketballGame] Live shot stream error: $err');
              if (matchSessionNotifier.value?.phase ==
                      MatchTurnPhase.watchingLiveOpponent &&
                  spectatorStatusNotifier.value !=
                      SpectatorConnectionStatus.opponentAbandoned) {
                spectatorStatusNotifier.value =
                    SpectatorConnectionStatus.reconnecting;
              }
            },
          );
    }
  }

  void spawnLiveGhostShot(RecordedShot shot) {
    // When the first shot is received, start the spectator's round timer in sync with shooter
    if (gameStateNotifier.value == GameModeState.ready) {
      gameStateNotifier.value = GameModeState.playing;
    }
    _lastLiveShotReceivedAt = DateTime.now();
    if (timeRemainingNotifier.value > 0 &&
        spectatorStatusNotifier.value != SpectatorConnectionStatus.connected) {
      spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    }
    // Cap concurrent ghost balls to max 2 in physics world to prevent clumping
    final activeGhosts = world.children.whereType<GhostBasketball>().toList();
    if (activeGhosts.length >= 2) {
      activeGhosts.first.removeFromParent();
    }
    final ghost = GhostBasketball(shot: shot);
    world.add(ghost);
  }

  void startMatchTurn() {
    final session = matchSessionNotifier.value;
    if (session == null) return;

    _liveShotSubscription?.cancel();
    _liveShotSubscription = null;
    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    _zeroClockGraceElapsed = 0.0;
    spectatorGraceSecondsNotifier.value = 15;
    _lastLiveShotReceivedAt = null;

    // Purge any residual ghost balls from courtside
    final existingGhosts = world.children.whereType<GhostBasketball>().toList();
    for (final g in existingGhosts) {
      g.removeFromParent();
    }

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    session.phase = MatchTurnPhase.playingTurn;
    session.activePlayerIndex = 0; // YOU are active shooter
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
    final replayedRoundIndex = (opponent.roundTelemetries.length - 1).clamp(
      0,
      session.totalRounds - 1,
    );
    final opponentBaseline = opponent.scoreUpToRound(replayedRoundIndex);
    if (opponent == session.player2) {
      // Opponent is Player 2 (THEM bay)
      player1MatchScoreNotifier.value = session.player1.totalScore;
      player2MatchScoreNotifier.value = opponentBaseline;
    } else {
      // Opponent is Player 1 (YOU bay)
      player1MatchScoreNotifier.value = opponentBaseline;
      player2MatchScoreNotifier.value = session.player2.totalScore;
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

  /// Returns player to court while keeping active 1v1 match session and scoreboard intact.
  void stayInMatchCourt() {
    final session = matchSessionNotifier.value;
    if (session != null) {
      session.phase = MatchTurnPhase.waitingForOpponentTurn;
      matchSessionNotifier.notify();
      player1MatchScoreNotifier.value = session.player1.totalScore;
      player2MatchScoreNotifier.value = session.player2.totalScore;
    }
    score = 0;
    currentStreak = 0;
    scoreNotifier.value = 0;
    streakNotifier.value = 0;
    timeRemainingNotifier.value = 0;
    gameStateNotifier.value = GameModeState.playing;
    resumeGame();

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

  void exitToSoloMode() {
    _liveShotSubscription?.cancel();
    _liveShotSubscription = null;
    _liveMatchSubscription?.cancel();
    _liveMatchSubscription = null;
    _currentSubscribedMatchId = null;
    _currentActiveTurnUid = null;
    liveTransitionNotifier.value = null;

    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    _zeroClockGraceElapsed = 0.0;
    spectatorGraceSecondsNotifier.value = 15;
    _lastLiveShotReceivedAt = null;

    currentRoundDurationSeconds = roundDurationSeconds;
    matchSessionNotifier.value = null;
    player1MatchScoreNotifier.value = 0;
    player2MatchScoreNotifier.value = 0;
    activeGhostTelemetry = null;
    restartRound(resetToSolo: true);
  }

  /// Awards forfeit victory to the local spectator when an opponent abandons the match.
  void claimAbandonedVictory() {
    HapticFeedback.heavyImpact();
    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;

    final session = matchSessionNotifier.value;
    if (session == null) {
      exitToSoloMode();
      return;
    }

    session.forfeitWinner = session.player1;
    session.phase = MatchTurnPhase.matchComplete;
    gameStateNotifier.value = GameModeState.gameOver;

    _liveShotSubscription?.cancel();
    _liveShotSubscription = null;
    _liveMatchSubscription?.cancel();
    _liveMatchSubscription = null;

    AudioEngine.playSwish();

    final matchId = session.cloudMatchId;
    final myUid = AuthService.instance.currentUser?.uid ?? session.player1.id;
    if (matchId != null) {
      unawaited(
        FirestoreMatchService.instance.claimForfeitVictory(
          matchId: matchId,
          winnerUid: myUid,
        ),
      );
    }

    matchSessionNotifier.notify();
  }

  /// Exits an abandoned match cleanly back to solo shootaround.
  void exitAbandonedMatch() {
    HapticFeedback.mediumImpact();
    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    exitToSoloMode();
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
      DistantWallRenderer.loadBrickImage(),
      CourtFloorRenderer.loadFloorImage(),
    ]);

    // Bind Lagos Life frame pause and resume events
    VatarBridge.instance.onPause(() {
      if (gameStateNotifier.value == GameModeState.playing) {
        pauseGame(manual: true);
      }
      AudioEngine.onAppBackground();
    });
    VatarBridge.instance.onResume(() {
      AudioEngine.onAppForeground();
    });

    // Asynchronously restore high score and check onboarding tour status
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localBest = prefs.getInt('b_ball_best_score') ?? 0;
        if (localBest > bestScoreNotifier.value) {
          bestScoreNotifier.value = localBest;
        }

        final hasSeenTour = prefs.getBool('b_ball_has_seen_tour') ?? false;
        if (!hasSeenTour) {
          isTourActiveNotifier.value = true;
        }

        final streakFxPref = prefs.getBool('streak_fx_enabled') ?? true;
        streakFxEnabledNotifier.value = streakFxPref;

        final user = AuthService.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final cloudBest = (doc.data()?['highScore'] as num?)?.toInt() ?? 0;
          if (cloudBest > bestScoreNotifier.value) {
            bestScoreNotifier.value = cloudBest;
            await prefs.setInt('b_ball_best_score', cloudBest);
          }
        }
      } catch (e) {
        debugPrint('[BasketballGame] Error loading persisted data: $e');
      }
    }());

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
    // Priority 1: Backboard, pole, glass plate, target rectangle, wall shadows
    world.add(
      BackboardVisual(
        position: hoopCenterInMeters,
        hoopWidth: hoopWidthInMeters,
      ),
    );

    // Priority 3: Rear rim arc, mounting bracket flange, and rear net mesh
    world.add(
      RearRimVisual(
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

    // Dynamic Basketball:
    // Priority 0: Behind backboard glass (Z > 4.96)
    // Priority 2: In front of glass, behind rear rim & neck (4.70 <= Z <= 4.96)
    // Priority 4: Inside hoop cylinder / net (4.23 <= Z < 4.70)
    // Priority 6: Foreground in front of hoop (Z < 4.23)
    _spawnReadyBall();

    // Priority 5: Front rim half, metallic highlight, and front net cords
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
    final options = candidates
        .where((x) => (x - _lastSpawnX).abs() >= 0.5)
        .toList();
    final chosen = options[_rng.nextInt(options.length)];
    _lastSpawnX = chosen;
    return chosen;
  }

  /// Caps active in-world balls to at most [maxAllowed] launched balls (default 2 in-flight/settled + 1 ready = 3 total).
  /// Safely retires the oldest settled or scored ball to preserve mobile GPU fill rate.
  void _pruneExcessBalls({int maxAllowed = 2}) {
    final activeBalls = world.children
        .whereType<Basketball>()
        .where((b) => b.isLaunched)
        .toList();
    if (activeBalls.length <= maxAllowed) return;

    // Only prune balls whose scoring/streak has already been evaluated
    // (settled on floor, bounced 1+ times, scored through rim, or marked dead ball)
    final candidates = activeBalls.where((b) {
      return b.physics.isSettled ||
          b.physics.bounceCount >= 1 ||
          b.passedThroughRim ||
          b.physics.isDeadBall;
    }).toList();

    if (candidates.isNotEmpty) {
      candidates.sort(
        (a, b) => b.physics.timeSinceLaunch.compareTo(a.physics.timeSinceLaunch),
      );
      candidates.first.removeFromParent();
    }
  }

  void _spawnReadyBall({bool animate = false}) {
    if (gameStateNotifier.value == GameModeState.gameOver) return;

    final session = matchSessionNotifier.value;
    if (session != null &&
        session.phase == MatchTurnPhase.watchingLiveOpponent) {
      return; // Do not spawn interactive balls when spectating live
    }

    _pruneExcessBalls(maxAllowed: 2);

    final spawnX = animate ? _pickNextSpawnX() : 0.0;
    final ball = Basketball(
      // Rest directly on the hardwood court floor at the chosen baseline spot
      initialPosition: Vector2(spawnX, 18.62),
      radius: 0.58,
      animateEntrance: animate,
      onLaunched: () {
        if (gameStateNotifier.value == GameModeState.gameOver) return;

        // Hard cap: keep maximum 3 balls in world (2 launched + 1 ready)
        _pruneExcessBalls(maxAllowed: 2);

        // Ultra-responsive feed of next ball: 100ms delay to eliminate rapid swipe deadzones
        add(
          TimerComponent(
            period: 0.10,
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
    _liveShotSubscription?.cancel();
    _liveMatchSubscription?.cancel();
    liveTransitionNotifier.dispose();
    AudioEngine.dispose();
    scoreNotifier.dispose();
    streakNotifier.dispose();
    streakFxEnabledNotifier.dispose();
    timeRemainingNotifier.dispose();
    bestScoreNotifier.dispose();
    isTourActiveNotifier.dispose();
    gameStateNotifier.dispose();
    isPausedNotifier.dispose();
    ghostScoreNotifier.dispose();
    isGhostModeNotifier.dispose();
    statsNotifier.dispose();
    scoreEventNotifier.dispose();
    matchSessionNotifier.dispose();
    player1MatchScoreNotifier.dispose();
    player2MatchScoreNotifier.dispose();
    spectatorStatusNotifier.dispose();
    spectatorGraceSecondsNotifier.dispose();
    super.onRemove();
  }
}
