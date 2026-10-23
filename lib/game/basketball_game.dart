import 'dart:async';
// Flame also exports a `Timer` (game-loop timer); this is the wall-clock one.
import 'dart:async' as async show Timer;
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
import '../services/update/update_platform.dart';
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
import 'fx/game_feel.dart';
import 'fx/streak_celebration.dart';
import 'performance/adaptive_quality.dart';
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

  /// Live online turn: device time (ms) the round clock started, or null.
  /// The clock is wall-time from here, so it keeps running while the game is
  /// paused, the tab is hidden, or the player is away in the lobby.
  int? _liveTurnStartMs;

  /// Ends a live turn whose clock runs out while the game is paused.
  async.Timer? _liveExpiryTimer;

  /// The live turn in progress, kept outside the game so leaving for the
  /// lobby and coming back (same tab) continues it exactly.
  static _LiveTurnMemory? _liveTurnMemory;

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
  final GlobalKey playFriendKey = GlobalKey();

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
    spectatorZeroClockGraceLimitSeconds.toInt(),
  );
  DateTime? _lastLiveShotReceivedAt;
  double _zeroClockGraceElapsed = 0.0;
  static const double spectatorAimingThresholdSeconds = 6.0;
  static const double spectatorReconnectingThresholdSeconds = 12.0;
  /// How long the spectator waits after the clock hits 0:00 for the
  /// shooter's round to arrive before CLAIM VICTORY is offered. Generous on
  /// purpose: on 3G, uploading a finished round can take well over 15s, and
  /// a too-early claim could cost a player a match they were still playing.
  /// Any sign of life from the shooter (a shot, a score tick) restarts it.
  /// The Firestore rule independently refuses claims earlier than 50s after
  /// the turn's server-side end.
  static const double spectatorZeroClockGraceLimitSeconds = 60.0;

  /// A live shot this far behind the synced clock is history (e.g. the turn's
  /// earlier shots delivered on reconnect): it syncs the clock but isn't
  /// replayed as a ghost ball.
  static const double _staleLiveShotSeconds = 2.5;

  /// Connection quality, 0 = unknown (hidden), 1 = poor, 2 = fair, 3 = good.
  /// Mine is measured from how long my live-shot writes take to be confirmed
  /// by the server; the opponent's rides along on their live shots.
  final ValueNotifier<int> myNetLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> opponentNetLevelNotifier = ValueNotifier<int>(0);
  int _pendingLiveWrites = 0;
  async.Timer? _netStallTimer;

  int? _lastSeenLiveShooterScore;

  StreamSubscription<LiveShotPacket>? _liveShotSubscription;
  StreamSubscription<CloudMatch?>? _liveMatchSubscription;
  String? _currentSubscribedMatchId;
  String? _currentActiveTurnUid;

  /// Frame-pacing monitor that steps visual effects down on struggling phones.
  final AdaptiveQuality quality = AdaptiveQuality();

  /// Camera shake + zoom punch (applied to the game canvas only, not the HUD).
  final ScreenFx screenFx = ScreenFx();

  /// Rim / backboard vibration after impacts.
  final HoopFx hoopFx = HoopFx();

  /// The backboard owns the cloth net; balls kick it on rim clanks.
  BackboardVisual? backboardVisual;

  /// Streak rewards at the hoop (shockwaves, sparks, rim glow, tier-up flash).
  StreakCelebration? streakCelebration;
  static final Paint _flashPaint = Paint()..blendMode = BlendMode.plus;
  Rect _flashRect = Rect.zero;

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
    _armLiveExpiryTimer();
  }

  void resumeGame() {
    _isManuallyPaused = false;
    isPausedNotifier.value = false;
    _liveExpiryTimer?.cancel();
    _liveExpiryTimer = null;
    resumeEngine();
  }

  /// A live turn's clock keeps running while paused: end the round on time
  /// even if the player never resumes.
  void _armLiveExpiryTimer() {
    _liveExpiryTimer?.cancel();
    _liveExpiryTimer = null;
    final start = _liveTurnStartMs;
    if (start == null || !_isLiveTurn ||
        gameStateNotifier.value != GameModeState.playing) {
      return;
    }
    final int endsAt = start + currentRoundDurationSeconds * 1000;
    final int waitMs = endsAt - DateTime.now().millisecondsSinceEpoch;
    _liveExpiryTimer = async.Timer(Duration(milliseconds: waitMs < 0 ? 0 : waitMs), () {
      _liveExpiryTimer = null;
      if (_liveTurnStartMs == start &&
          _isLiveTurn &&
          gameStateNotifier.value == GameModeState.playing) {
        timeRemainingNotifier.value = 0;
        _onTimeExpired();
      }
    });
  }

  /// Toggles player's streak visual effects (Lightning at 3+, Flame at 6+)
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
      if (_isLiveTurn) {
        _liveTurnStartMs = DateTime.now().millisecondsSinceEpoch -
            (_roundElapsedSeconds * 1000).round();
      }
    }
    totalShots++;
  }

  /// This device is shooting its round in an online 1v1.
  bool get _isLiveTurn {
    final s = matchSessionNotifier.value;
    return s != null &&
        s.mode == MatchGameMode.onlineCloud1v1 &&
        s.cloudMatchId != null &&
        s.phase == MatchTurnPhase.playingTurn;
  }

  /// Saves the live turn so far (called on each shot and each make).
  void _rememberLiveTurn() {
    final s = matchSessionNotifier.value;
    final start = _liveTurnStartMs;
    if (!_isLiveTurn || s == null || start == null) return;
    _liveTurnMemory = _LiveTurnMemory(
      matchId: s.cloudMatchId!,
      round: s.currentRoundNumber,
      startMs: start,
      score: score,
      madeShots: madeShots,
      totalShots: totalShots,
      swishes: swishCount,
      banks: bankCount,
      streak: currentStreak,
      bestStreak: bestStreakInRound,
      shots: List.of(_currentRoundShots),
    );
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
    // How the previous shot ended rides along with this one, so the turn can
    // be rebuilt if this player leaves and comes back.
    final RecordedShot? previous =
        _currentRoundShots.isEmpty ? null : _currentRoundShots.last;
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
      if (_currentRoundShots.length == 1) {
        // First shot of this turn: arm the spectator ticker with a server timestamp.
        unawaited(
          FirestoreMatchService.instance.markTurnStarted(
            matchId: session.cloudMatchId!,
            shooterUid: myUid,
          ),
        );
      }
      _trackLiveWrite(
        FirestoreMatchService.instance.broadcastLiveShot(
          matchId: session.cloudMatchId!,
          shot: shot,
          shooterUid: myUid,
          shotIndex: _currentRoundShots.length,
          round: session.currentRoundNumber,
          netLevel: myNetLevelNotifier.value,
          previousResult: previous == null
              ? null
              : {
                  'm': previous.isMake,
                  's': previous.isSwish,
                  'b': previous.isBankShot,
                  'p': previous.points,
                },
        ),
      );
      _rememberLiveTurn();
    }
  }

  // ── Network gauge ─────────────────────────────────────────────────────────

  /// Maps a server round-trip time to signal bars.
  static int _netLevelForLatency(int ms) {
    if (ms < 400) return 3;
    if (ms < 1200) return 2;
    return 1;
  }

  /// Times a live-shot write: the server's confirmation delay becomes my
  /// signal bars. If a write is still unconfirmed after 5s (or the device
  /// is offline) the gauge drops to 1 bar straight away.
  void _trackLiveWrite(Future<int?> write) {
    _pendingLiveWrites++;
    _netStallTimer ??= async.Timer(const Duration(seconds: 5), () {
      _netStallTimer = null;
      if (_pendingLiveWrites > 0) myNetLevelNotifier.value = 1;
    });
    unawaited(
      write.then((latencyMs) {
        _pendingLiveWrites = (_pendingLiveWrites - 1).clamp(0, 1 << 20);
        if (_pendingLiveWrites == 0) {
          _netStallTimer?.cancel();
          _netStallTimer = null;
        }
        myNetLevelNotifier.value = latencyMs == null || !isDeviceOnline()
            ? 1
            : _netLevelForLatency(latencyMs);
      }),
    );
  }

  /// The shooter is still active: restart the 0:00 grace window, and if the
  /// CLAIM VICTORY offer was already showing, take it back.
  void _reviveSpectatorGrace() {
    _zeroClockGraceElapsed = 0.0;
    if (spectatorStatusNotifier.value ==
        SpectatorConnectionStatus.opponentAbandoned) {
      spectatorStatusNotifier.value = timeRemainingNotifier.value > 0
          ? SpectatorConnectionStatus.connected
          : SpectatorConnectionStatus.finalizingTurn;
    }
  }

  void _resetNetGauges() {
    _netStallTimer?.cancel();
    _netStallTimer = null;
    _pendingLiveWrites = 0;
    myNetLevelNotifier.value = 0;
    opponentNetLevelNotifier.value = 0;
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
    // Streak bonus: a flat +1 on every make while on a streak of 3 or more.
    final basePoints = isSwish ? 3 : (isBankShot ? 3 : 2);
    final streakBonus = currentStreak >= 3 ? 1 : 0;
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

    if (streakFxEnabledNotifier.value) {
      streakCelebration?.onMake(streak: currentStreak, isLocalPlayer: true);
    }

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
        _rememberLiveTurn();
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
    // Raw dt (before any clamping) is the truest signal of thermal/GPU stalls.
    screenFx.update(dt);
    hoopFx.update(dt);
    super.update(dt);

    final session = matchSessionNotifier.value;
    final isSpectatingLive =
        session != null &&
        session.phase == MatchTurnPhase.watchingLiveOpponent &&
        !isPaused;

    if (isSpectatingLive) {
      _updateLiveSpectatorStatus(dt);
    }

    final int? liveStart = _liveTurnStartMs;
    if (liveStart != null &&
        gameStateNotifier.value == GameModeState.playing &&
        _isLiveTurn) {
      // Live online turn: wall-clock time, so the clock can't be stopped by
      // pausing, hiding the tab or leaving.
      _roundElapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - liveStart) / 1000.0;
      final int left = (currentRoundDurationSeconds - _roundElapsedSeconds)
          .ceil()
          .clamp(0, currentRoundDurationSeconds)
          .toInt();
      if (left != timeRemainingNotifier.value) timeRemainingNotifier.value = left;
      if (left <= 0) _onTimeExpired();
    } else if (gameStateNotifier.value == GameModeState.playing &&
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
    int streak = 0,
  }) {
    // Opponent / replay streaks get the hoop burst too (no flash or punch).
    if (streak >= 3) {
      streakCelebration?.onMake(streak: streak, isLocalPlayer: false);
    }
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
    _liveTurnStartMs = null;
    _liveExpiryTimer?.cancel();
    _liveExpiryTimer = null;
    if (_liveTurnMemory?.matchId == session.cloudMatchId) _liveTurnMemory = null;
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
                // Profile docs are permanent (friends + high score): clear legacy TTL.
                'expireAt': FieldValue.delete(),
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
    _liveTurnStartMs = null;
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
  /// Called instead of [startCloudMatch] for another game's match (archery,
  /// darts): the screen navigates to `/match/:id`.
  void Function(CloudMatch match)? onOtherGameMatch;

  void startCloudMatch(CloudMatch match, String myUid) {
    if (!match.isBasketball) {
      onOtherGameMatch?.call(match);
      return;
    }
    _resetNetGauges();
    _lastSeenLiveShooterScore = null;
    final session = MatchSession.fromCloudMatch(match, myUid);
    currentMatchConfig = session.config;
    currentRoundDurationSeconds = match.roundDurationSeconds;
    matchSessionNotifier.value = session;

    player1MatchScoreNotifier.value = session.player1.totalScore;
    player2MatchScoreNotifier.value = session.player2.totalScore;

    _setupCloudMatchSync(match, myUid);

    if (session.phase == MatchTurnPhase.watchingLiveOpponent) {
      startLiveSpectatorMode();
      // Rejoining mid-round: show the opponent's round score so far.
      final live = match.liveShooterScore;
      if (live != null && match.liveShooterUid == session.player2.id) {
        _lastSeenLiveShooterScore = live;
        player2MatchScoreNotifier.value =
            session.player2.scoreUpToRound(session.currentRoundIndex) + live;
      }
    } else if (session.phase == MatchTurnPhase.watchingOpponentReplay) {
      startOpponentReplay();
    } else if (_hasLiveTurnInProgress(match, myUid)) {
      _clearCourtBalls();
      unawaited(_resumeLiveTurn(match, myUid));
    } else {
      startMatchTurn();
    }
  }

  /// My round in this match was already under way (I left mid-round).
  bool _hasLiveTurnInProgress(CloudMatch m, String myUid) {
    if (!m.isMyTurn(myUid)) return false;
    final mem = _liveTurnMemory;
    if (mem != null && mem.matchId == m.id && mem.round == m.currentRound) {
      return true;
    }
    return m.liveShooterUid == myUid && m.turnStartedAtMs != null;
  }

  void _clearCourtBalls() {
    for (final b in world.children.whereType<Basketball>().toList()) {
      b.removeFromParent();
    }
    for (final g in world.children.whereType<GhostBasketball>().toList()) {
      g.removeFromParent();
    }
  }

  /// Continues a round I left: same clock (it kept running), my made shots
  /// and score kept. If the clock ran out meanwhile, the round is submitted
  /// with what I had.
  Future<void> _resumeLiveTurn(CloudMatch m, String myUid) async {
    _LiveTurnMemory? mem = _liveTurnMemory;
    if (mem == null || mem.matchId != m.id || mem.round != m.currentRound) {
      mem = await _rebuildLiveTurn(m, myUid);
    }
    final session = matchSessionNotifier.value;
    if (session == null || session.cloudMatchId != m.id) return; // moved on
    startMatchTurn();
    if (mem == null) return; // nothing was shot yet: a normal fresh round

    score = mem.score;
    madeShots = mem.madeShots;
    totalShots = mem.totalShots;
    swishCount = mem.swishes;
    bankCount = mem.banks;
    currentStreak = mem.streak;
    bestStreakInRound = mem.bestStreak;
    _currentRoundShots
      ..clear()
      ..addAll(mem.shots);
    scoreNotifier.value = score;
    streakNotifier.value = currentStreak;
    player1MatchScoreNotifier.value =
        session.player1.scoreUpToRound(session.currentRoundIndex) + score;

    _liveTurnStartMs = mem.startMs;
    _roundElapsedSeconds =
        (DateTime.now().millisecondsSinceEpoch - mem.startMs) / 1000.0;
    final int left = (currentRoundDurationSeconds - _roundElapsedSeconds)
        .ceil()
        .clamp(0, currentRoundDurationSeconds)
        .toInt();
    timeRemainingNotifier.value = left;
    gameStateNotifier.value = GameModeState.playing;
    _liveTurnMemory = mem;
    if (left <= 0) _onTimeExpired();
  }

  /// Rebuilds a turn from the match's stored live shots (after a refresh or
  /// on another device). Each shot carries how the one before it ended; the
  /// last shot's result comes from the live score.
  Future<_LiveTurnMemory?> _rebuildLiveTurn(CloudMatch m, String myUid) async {
    final records = await FirestoreMatchService.instance.getLiveShotRecords(
      m.id,
      shooterUid: myUid,
      round: m.currentRound,
    );
    if (records.isEmpty) {
      final started = m.turnStartedAtMs;
      if (started == null) return null;
      return _LiveTurnMemory(
        matchId: m.id,
        round: m.currentRound,
        startMs: started,
        score: m.liveShooterScore ?? 0,
        madeShots: 0,
        totalShots: 0,
        swishes: 0,
        banks: 0,
        streak: 0,
        bestStreak: 0,
        shots: const [],
      );
    }

    final shots = <RecordedShot>[];
    int known = 0;
    for (int i = 0; i < records.length; i++) {
      RecordedShot s = records[i].shot;
      final pr = i + 1 < records.length ? records[i + 1].previousResult : null;
      if (pr != null) {
        s = s.copyWith(
          isMake: pr['m'] as bool? ?? false,
          isSwish: pr['s'] as bool? ?? false,
          isBankShot: pr['b'] as bool? ?? false,
          points: (pr['p'] as num?)?.toInt() ?? 0,
        );
        known += s.isMake ? s.points : 0;
      }
      shots.add(s);
    }
    // Last shot: made if the live score is above what the others add up to.
    final int liveScore = m.liveShooterUid == myUid ? (m.liveShooterScore ?? known) : known;
    final int lastPoints = liveScore - known;
    if (lastPoints > 0) {
      shots[shots.length - 1] = shots.last.copyWith(
        isMake: true,
        isSwish: lastPoints >= 3,
        points: lastPoints,
      );
    }

    int made = 0, swishes = 0, banks = 0, streak = 0, best = 0;
    for (final s in shots) {
      if (s.isMake) {
        made++;
        if (s.isSwish) swishes++;
        if (s.isBankShot) banks++;
        streak++;
        if (streak > best) best = streak;
      } else {
        streak = 0;
      }
    }
    // Round start on the shooter's own clock: send time minus round time.
    final starts = [for (final r in records) r.sentAtMs - r.shot.timestampMs]..sort();
    final int startMs = starts[starts.length ~/ 2];

    return _LiveTurnMemory(
      matchId: m.id,
      round: m.currentRound,
      startMs: startMs,
      score: liveScore,
      madeShots: made,
      totalShots: shots.length,
      swishes: swishes,
      banks: banks,
      streak: streak,
      bestStreak: best,
      shots: shots,
    );
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
      session.player1.roundSummaries
        ..clear()
        ..addAll(myCloudPlayer.roundSummaries);
    }
    if (oppCloudPlayer != null) {
      session.player2.roundScores
        ..clear()
        ..addAll(oppCloudPlayer.roundScores);
      session.player2.roundSummaries
        ..clear()
        ..addAll(oppCloudPlayer.roundSummaries);
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
      spectatorGraceSecondsNotifier.value =
        spectatorZeroClockGraceLimitSeconds.toInt();
      _lastLiveShotReceivedAt = null;

      // Trigger interstitial countdown
      _triggerLiveTurnTransition(
        isMyTurnNow: isMyTurn,
        // Cloud sessions always seat me as player1 and the opponent as player2.
        opponentName: session.player2.name,
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
    // Only trust the ticker when it belongs to the opponent's current turn —
    // a leftover value from my own previous turn must never land in their bay.
    if (session.phase == MatchTurnPhase.watchingLiveOpponent &&
        updatedMatch.liveShooterScore != null &&
        updatedMatch.liveShooterUid == session.player2.id) {
      // A changed live score is a sign of life: restart the 0:00 grace.
      if (updatedMatch.liveShooterScore != _lastSeenLiveShooterScore) {
        _lastSeenLiveShooterScore = updatedMatch.liveShooterScore;
        _reviveSpectatorGrace();
      }
      // While spectating, activePlayerIndex == 1 so `opponentPlayer` would
      // resolve to *me*; in cloud mode the opponent is always player2.
      final oppBase = session.player2.scoreUpToRound(
        session.currentRoundIndex,
      );
      player2MatchScoreNotifier.value =
          oppBase + updatedMatch.liveShooterScore!;
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
    spectatorGraceSecondsNotifier.value =
        spectatorZeroClockGraceLimitSeconds.toInt();
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
          .streamLiveShots(
            session.cloudMatchId!,
            shooterUid: session.player2.id,
            round: session.currentRoundNumber,
          )
          .listen(
            (packet) {
              _lastLiveShotReceivedAt = DateTime.now();
              if (packet.netLevel > 0) {
                opponentNetLevelNotifier.value = packet.netLevel;
              }
              if (timeRemainingNotifier.value > 0 &&
                  spectatorStatusNotifier.value !=
                      SpectatorConnectionStatus.connected) {
                spectatorStatusNotifier.value =
                    SpectatorConnectionStatus.connected;
              }
              spawnLiveGhostShot(packet.shot);
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
    // Any sign of life from the shooter restarts the 0:00 grace window and
    // withdraws a CLAIM VICTORY offer that appeared too early.
    _reviveSpectatorGrace();

    // Shared clock: every shot carries the shooter's own round time, so the
    // spectator's clock jumps forward to match it. A slow or stalled network
    // can no longer leave the spectator's timer 20 seconds behind. (Only ever
    // forward: the clock never runs backwards on screen.)
    final shotTime = shot.timestampMs / 1000.0;
    if (shotTime > _roundElapsedSeconds) {
      _roundElapsedSeconds = shotTime;
      final wholeSeconds = shotTime.floor();
      _secondAccumulator = shotTime - wholeSeconds;
      final synced = (currentRoundDurationSeconds - wholeSeconds)
          .clamp(0, currentRoundDurationSeconds)
          .toInt();
      if (synced < timeRemainingNotifier.value) {
        timeRemainingNotifier.value = synced;
      }
    } else if (shotTime < _roundElapsedSeconds - _staleLiveShotSeconds) {
      // An earlier shot of this turn (e.g. delivered on reconnect): it has
      // already happened, so don't replay it as a ghost ball.
      return;
    }
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
    spectatorGraceSecondsNotifier.value =
        spectatorZeroClockGraceLimitSeconds.toInt();
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
    _liveTurnStartMs = null;
    _liveExpiryTimer?.cancel();
    _liveExpiryTimer = null;
    _resetNetGauges();
    _liveShotSubscription?.cancel();
    _liveShotSubscription = null;
    _liveMatchSubscription?.cancel();
    _liveMatchSubscription = null;
    _currentSubscribedMatchId = null;
    _currentActiveTurnUid = null;
    liveTransitionNotifier.value = null;

    spectatorStatusNotifier.value = SpectatorConnectionStatus.connected;
    _zeroClockGraceElapsed = 0.0;
    spectatorGraceSecondsNotifier.value =
        spectatorZeroClockGraceLimitSeconds.toInt();
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
    final abandonedByUid = session.player2.id;
    if (matchId != null && abandonedByUid.isNotEmpty) {
      unawaited(
        FirestoreMatchService.instance.claimForfeitVictory(
          matchId: matchId,
          winnerUid: myUid,
          forfeiterUid: abandonedByUid,
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
    _liveTurnStartMs = null;
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

  /// Applies [screenFx] (shake + zoom punch) to the whole court — background,
  /// hoop and balls — while Flutter HUD overlays stay perfectly still.
  @override
  void render(Canvas canvas) {
    final fx = screenFx;
    if (!fx.isActive) {
      super.render(canvas);
    } else {
      canvas.save();
      canvas.translate(fx.offsetX + fx.originX, fx.offsetY + fx.originY);
      canvas.scale(fx.scale);
      canvas.translate(-fx.originX, -fx.originY);
      super.render(canvas);
      canvas.restore();
    }

    // Tier-up flash: a brief additive tint over the court (HUD stays clear).
    final flash = streakCelebration?.flashColor;
    if (flash != null) {
      _flashPaint.color = flash;
      canvas.drawRect(_flashRect, _flashPaint);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait([
      Basketball.loadProgram(),
      DistantWallRenderer.loadBrickImage(),
      CourtFloorRenderer.loadFloorImage(),
    ]);

    // Audio must never block the court from appearing (awaiting it here once
    // left players on a blank screen when audio was slow to start). It
    // finishes in the background; AudioEngine retries on the next tap.
    unawaited(AudioEngine.init());

    unawaited(quality.load());

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
    final backboard = BackboardVisual(
      position: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    );
    backboardVisual = backboard;
    world.add(backboard);

    // Priority 3: Rear rim arc, mounting bracket flange, and rear net mesh
    world.add(
      RearRimVisual(position: hoopCenterInMeters, hoopWidth: hoopWidthInMeters),
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

    // Streak celebration: same priority as the front rim but added after it,
    // so sparks/rings draw over the rim yet under foreground balls (6).
    final celebration = StreakCelebration(
      hoopCenter: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    );
    streakCelebration = celebration;
    world.add(celebration);
  }

  double _lastSpawnX = 0.0;
  final math.Random _rng = math.Random();

  /// Seven shooting stations across the baseline (Forge2D units: one unit
  /// is 1/20 of the screen height). Spread across ~60% of a phone's width,
  /// so the ball genuinely visits the wings and corners.
  static const List<double> _spawnStations = [
    -2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4,
  ];

  /// Small random nudge per spawn so stations don't feel like fixed tracks.
  static const double _spawnJitter = 0.12;

  /// Keep the ball's edge at least this far (logical px) from the screen's
  /// left/right edges: thumb room, and clear of edge-swipe/back gestures.
  static const double _spawnEdgeMarginPx = 60.0;

  /// Visual ready-ball radius in Forge2D units (0.58 radius × 1.38 sprite
  /// scale at the baseline depth).
  static const double _readyBallVisualRadius = 0.8;

  double _pickNextSpawnX() {
    // Widest spawn the current screen allows (narrow phones clamp in).
    final pxPerUnit = size.y / worldHeightInMeters;
    final maxX = pxPerUnit > 0
        ? ((size.x / 2 - _spawnEdgeMarginPx) / pxPerUnit -
                  _readyBallVisualRadius)
              .clamp(0.0, _spawnStations.last)
        : 1.4;

    // Never the same spot twice in a row (stations that clamp onto the
    // previous spot on a narrow screen count as the same spot).
    final options = <double>[];
    for (final station in _spawnStations) {
      final x = station.clamp(-maxX, maxX).toDouble();
      if ((x - _lastSpawnX).abs() >= 0.5 && !options.contains(x)) {
        options.add(x);
      }
    }
    final base = options.isEmpty
        ? 0.0
        : options[_rng.nextInt(options.length)];
    final x = (base + (_rng.nextDouble() * 2 - 1) * _spawnJitter)
        .clamp(-maxX, maxX)
        .toDouble();
    _lastSpawnX = base;
    return x;
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
        (a, b) =>
            b.physics.timeSinceLaunch.compareTo(a.physics.timeSinceLaunch),
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
    // Zoom-punch origin = the hoop (Forge2D (0, 5) with a top-center anchor).
    screenFx
      ..originX = size.x / 2
      ..originY = 5.0 * size.y / worldHeightInMeters
      ..viewportWidth = size.x;
    _flashRect = Rect.fromLTWH(0, 0, size.x, size.y);
    if (isLoaded) {
      final viewfinder = camera.viewfinder as Forge2DViewfinder;
      viewfinder.metersToPixels = size.y / worldHeightInMeters;
    }
  }

  @override
  void onRemove() {
    _liveShotSubscription?.cancel();
    _liveMatchSubscription?.cancel();
    _liveExpiryTimer?.cancel();
    liveTransitionNotifier.dispose();
    // The audio engine is app-wide (archery and the lobby use it too), so
    // it is never disposed here; basketball only gives up its music.
    AudioEngine.releaseSoundtrack(this);
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
    quality.dispose();
    _netStallTimer?.cancel();
    myNetLevelNotifier.dispose();
    opponentNetLevelNotifier.dispose();
    super.onRemove();
  }
}

/// A live online turn in progress, kept across leaving and re-entering the
/// basketball screen (see [BasketballGame._resumeLiveTurn]).
class _LiveTurnMemory {
  final String matchId;
  final int round;

  /// Device time (ms) the round clock started.
  final int startMs;
  final int score;
  final int madeShots;
  final int totalShots;
  final int swishes;
  final int banks;
  final int streak;
  final int bestStreak;
  final List<RecordedShot> shots;

  const _LiveTurnMemory({
    required this.matchId,
    required this.round,
    required this.startMs,
    required this.score,
    required this.madeShots,
    required this.totalShots,
    required this.swishes,
    required this.banks,
    required this.streak,
    required this.bestStreak,
    required this.shots,
  });
}
