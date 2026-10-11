import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'audio/audio_engine.dart';
import 'components/background.dart';
import 'components/backboard_visual.dart';
import 'components/front_rim_visual.dart';
import 'components/hoop_physics.dart';
import 'components/ball.dart';
import 'components/ground.dart';

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

class BasketballGame extends Forge2DGame {
  BasketballGame() : super(gravity: Vector2(0, 30.0));

  static const double worldHeightInMeters = 20.0;
  static const int roundDurationSeconds = 60;

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
  void Function(ScoreEvent event)? onScoreEvent;

  // Reactive ValueNotifiers for zero-overhead Flutter UI binding
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> timeRemainingNotifier =
      ValueNotifier<int>(roundDurationSeconds);
  final ValueNotifier<int> bestScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<GameModeState> gameStateNotifier =
      ValueNotifier<GameModeState>(GameModeState.playing);
  final ValueNotifier<GameRoundStats?> statsNotifier =
      ValueNotifier<GameRoundStats?>(null);
  final ValueNotifier<ScoreEvent?> scoreEventNotifier =
      ValueNotifier<ScoreEvent?>(null);

  void recordShotAttempt() {
    totalShots++;
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
        timeRemainingNotifier.value > 0) {
      _secondAccumulator += dt;
      if (_secondAccumulator >= 1.0) {
        _secondAccumulator -= 1.0;
        final nextTime = timeRemainingNotifier.value - 1;
        timeRemainingNotifier.value = nextTime;
        if (nextTime <= 0) {
          _onTimeExpired();
        }
      }
    }
  }

  void _onTimeExpired() {
    gameStateNotifier.value = GameModeState.gameOver;
    AudioEngine.playBuzzer();
    _compileStats();
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

  void restartRound() {
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
    timeRemainingNotifier.value = roundDurationSeconds;
    statsNotifier.value = null;
    gameStateNotifier.value = GameModeState.playing;

    // Clear active balls from world
    final existingBalls = world.children.whereType<Basketball>().toList();
    for (final b in existingBalls) {
      b.removeFromParent();
    }

    _spawnReadyBall(animate: true);
  }

  @override
  Color backgroundColor() => const Color(0xFF090D16);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await AudioEngine.init();

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
                  gameStateNotifier.value == GameModeState.playing) {
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
    scoreNotifier.dispose();
    streakNotifier.dispose();
    timeRemainingNotifier.dispose();
    bestScoreNotifier.dispose();
    gameStateNotifier.dispose();
    statsNotifier.dispose();
    scoreEventNotifier.dispose();
    super.onRemove();
  }
}
