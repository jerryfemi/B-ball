import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'archery_constants.dart';
import 'audio/archery_audio.dart';
import 'camera/archery_camera.dart';
import 'camera/camera_rig.dart';
import 'components/bow_overlay.dart';
import 'components/flying_arrow.dart';
import 'components/range_background.dart';
import 'components/stuck_arrow.dart';
import 'components/target_board.dart';
import 'components/wind_flag.dart';
import 'components/wind_particles.dart';
import 'components/wind_pill.dart';
import 'input/draw_aim_controller.dart';
import 'physics/arrow_physics.dart';
import 'physics/sight_solver.dart';
import 'physics/target_scoring.dart';
import 'physics/wind_model.dart';

/// Flame game instance managing the 50 ft GamePigeon-style archery range (Build Plan v2).
///
/// Features:
/// - 50 ft (15.24 m) fixed target distance.
/// - Sets of 3 arrows format with set points.
/// - Per-arrow deterministic wind and sway.
/// - Dolly-only camera with 7-phase cinematic shot sequence.
/// - World-anchored wind pill.
/// - Fixed HUD notification bug: only notifies on discrete state events.
/// - Zero allocations per frame in [update] and [render].
class ArcheryGame extends FlameGame {
  // --- Core Systems ---
  late final ArcheryCamera archeryCamera;
  late final CameraRig cameraRig;
  late final DrawAimController controller;

  // --- Physics & Wind Models ---
  final ArrowPhysics3D arrowPhysics = ArrowPhysics3D();
  late WindModel windModel;
  final int matchSeed = 101;

  // --- Components ---
  late final RangeBackground background;
  late final TargetBoard targetBoard;
  late final WindFlag windFlag;
  late final WindParticles windParticles;
  late final WindPill windPill;
  late final BowOverlay bowOverlay;
  late final FlyingArrow flyingArrow;
  final List<StuckArrow> stuckArrows = [];

  // --- Sets & Match Scoring State ---
  int currentSetIndex = 0; // 0-indexed set number
  int currentArrowIndex = 0; // 0, 1, 2
  final List<List<ShotScore>> setScores = [[]];
  int userSetPoints = 0;
  int opponentSetPoints = 0;
  bool isSetComplete = false;
  bool isMatchComplete = false;

  // --- Hit Popup Trigger State ---
  ShotScore? lastShotScore;
  Offset? lastHitScreenPos;

  // --- State & HUD Link ---
  final ValueNotifier<int> hudNotifier = ValueNotifier<int>(0);
  double targetDistance = ArcheryK.distanceM;

  ArcheryGame() {
    archeryCamera = ArcheryCamera();
    cameraRig = CameraRig(camera: archeryCamera);
    controller = DrawAimController(camera: archeryCamera, cameraRig: cameraRig);
    background = RangeBackground(camera: archeryCamera);
    targetBoard = TargetBoard(camera: archeryCamera, initialDistance: targetDistance);
    windFlag = WindFlag(camera: archeryCamera);
    windParticles = WindParticles(camera: archeryCamera);
    windPill = WindPill(camera: archeryCamera, cameraRig: cameraRig);
    bowOverlay = BowOverlay();
    flyingArrow = FlyingArrow(camera: archeryCamera, physics: arrowPhysics);

    _setupCurrentArrow();
  }

  int _getArrowSeed(int setIdx, int arrowIdx) {
    int h = matchSeed;
    h = (h * 31 + setIdx) & 0x7FFFFFFF;
    h = (h * 31 + arrowIdx) & 0x7FFFFFFF;
    return h;
  }

  void _setupCurrentArrow() {
    final int arrowSeed = _getArrowSeed(currentSetIndex, currentArrowIndex);
    windModel = WindModel.fromSeed(arrowSeed);
    controller.initSwaySeed(arrowSeed);
    windFlag.reset(targetDistance);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    ArcheryAudio.init();
    cameraRig.setTargetDistance(targetDistance);
    background.activeDistance = targetDistance;
    await background.load();

    // Connect aim controller firing hook
    controller.onFireAt = (double crossX, double crossY) {
      if (isSetComplete || arrowPhysics.inFlight) return;

      ArcheryAudio.playReleaseTwang();

      // 1. Unproject visible crosshair point to target plane Z = D
      archeryCamera.unprojectToPlane(crossX, crossY, targetDistance);
      final double px = archeryCamera.outX;
      final double py = archeryCamera.outY;

      // 2. Solve launch yaw and pitch
      final double launchYaw = SightSolver.solveYaw(targetDistance, px);
      final double launchPitch = SightSolver.solvePitch(targetDistance, py);

      // 3. Launch arrow at full draw speed with per-arrow wind model
      arrowPhysics.launch(
        startX: 0.0,
        startY: ArcheryK.launchY,
        startZ: ArcheryK.launchZ,
        launchYaw: launchYaw,
        launchPitch: launchPitch,
        speed: ArcheryK.fullDrawSpeed,
        targetDist: targetDistance,
        windModel: windModel,
      );

      flyingArrow.resetTrail();
      cameraRig.fireShot();
      cameraRig.addShake(3.5);
      bowOverlay.onRelease();
      _notifyHud();
    };

    controller.onHoldStarted = () {
      ArcheryAudio.playDrawCreak();
      _notifyHud();
    };

    controller.onHoldCancelled = () {
      _notifyHud();
    };

    // Camera Rig phase transitions
    cameraRig.onCloseupStarted = () {
      _notifyHud();
    };

    cameraRig.onReturnedToLine = () {
      if (isSetComplete) {
        cameraRig.returnToLine(isSetComplete: true);
      } else {
        _setupCurrentArrow();
      }
      _notifyHud();
    };

    cameraRig.onSetEndStarted = () {
      _notifyHud();
    };
  }

  /// Advances to next set, clearing stuck arrows and generating new wind.
  void advanceNextSet() {
    // Award set point to winner of completed set
    final int currentSetTotal = setScores[currentSetIndex].fold(0, (sum, s) => sum + s.points);
    const int simulatedOpponentTotal = 26; // Simulated benchmark opponent

    if (currentSetTotal > simulatedOpponentTotal) {
      userSetPoints++;
    } else if (currentSetTotal < simulatedOpponentTotal) {
      opponentSetPoints++;
    } else {
      userSetPoints++;
      opponentSetPoints++;
    }

    if (userSetPoints >= 3 || opponentSetPoints >= 3) {
      isMatchComplete = true;
      _notifyHud();
      return;
    }

    currentSetIndex++;
    currentArrowIndex = 0;
    isSetComplete = false;
    stuckArrows.clear();
    lastShotScore = null;
    lastHitScreenPos = null;
    setScores.add([]);

    _setupCurrentArrow();
    cameraRig.phase = ShotPhase.atLine;
    cameraRig.phaseTime = 0.0;
    _notifyHud();
  }

  /// Restarts the match from Set 1.
  void restartMatch() {
    currentSetIndex = 0;
    currentArrowIndex = 0;
    userSetPoints = 0;
    opponentSetPoints = 0;
    isSetComplete = false;
    isMatchComplete = false;
    setScores.clear();
    setScores.add([]);
    stuckArrows.clear();
    lastShotScore = null;
    lastHitScreenPos = null;

    _setupCurrentArrow();
    cameraRig.phase = ShotPhase.atLine;
    cameraRig.phaseTime = 0.0;
    _notifyHud();
  }

  /// Dismisses active hit popup.
  void clearLastHitPopup() {
    lastShotScore = null;
    lastHitScreenPos = null;
    _notifyHud();
  }

  int get totalScore =>
      setScores.expand((r) => r).fold(0, (sum, s) => sum + s.points);

  int get totalXCount =>
      setScores.expand((r) => r).where((s) => s.isX).length;

  int get currentSetScore =>
      setScores[currentSetIndex].fold(0, (sum, s) => sum + s.points);

  // Backward-compatibility getters for HUD / testing
  int get currentRoundIndex => currentSetIndex;
  List<List<ShotScore>> get roundScores => setScores;
  bool get isRoundComplete => isSetComplete;

  void _notifyHud() {
    hudNotifier.value = hudNotifier.value + 1;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final double w = size.x;
    final double h = size.y;

    archeryCamera.screenW = w;
    archeryCamera.screenH = h;
    controller.screenW = w;
    controller.screenH = h;
    background.resize(w, h);
    bowOverlay.resize(w, h);

    archeryCamera.prepare();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final double clampedDt = dt.clamp(0.0, 0.05);

    // 1. Update Input & Crosshair
    controller.update(clampedDt);

    // 2. Update Camera Rig with arrow follow and phase transitions
    cameraRig.update(
      clampedDt,
      controller.draw,
      controller.isHolding,
      arrow: arrowPhysics,
    );

    // 3. Update Bow Overlay slide progress
    bowOverlay.update(
      clampedDt,
      controller.draw,
      controller.isHolding,
      slide: cameraRig.bowSlideProgress,
    );

    // 4. Update Environmental Visuals
    windFlag.update(clampedDt, windModel.baseWindMps);
    windParticles.update(clampedDt, windModel.baseWindMps);

    // 5. Update Arrow Physics
    final bool wasInFlight = arrowPhysics.inFlight;
    arrowPhysics.update(clampedDt);

    // Impact detection
    if (wasInFlight && !arrowPhysics.inFlight) {
      final ShotScore score = TargetScoring.calculate(
        localX: arrowPhysics.hitLocalX,
        localY: arrowPhysics.hitLocalY,
        hitBoss: arrowPhysics.hitBoss,
        distance: targetDistance,
      );

      // Distance-delayed impact audio
      ArcheryAudio.playImpact(
        distance: targetDistance,
        isX: score.isX,
        hitBoss: arrowPhysics.hitBoss,
        hitGround: arrowPhysics.hitGround,
      );

      // Record shot
      if (currentSetIndex < setScores.length && setScores[currentSetIndex].length < 3) {
        setScores[currentSetIndex].add(score);
        currentArrowIndex = setScores[currentSetIndex].length;
      }

      // Hit Popup screen coordinates
      if (archeryCamera.project(
        arrowPhysics.hitPoint.x,
        arrowPhysics.hitPoint.y,
        arrowPhysics.hitPoint.z,
      )) {
        lastHitScreenPos = Offset(archeryCamera.sx, archeryCamera.sy);
      } else {
        lastHitScreenPos = Offset(archeryCamera.screenW * 0.5, archeryCamera.screenH * 0.5);
      }
      lastShotScore = score;

      if (arrowPhysics.hitBoss) {
        cameraRig.addShake(score.isX ? 7.0 : 4.5);
        stuckArrows.add(StuckArrow(
          hitLocalX: arrowPhysics.hitLocalX,
          hitLocalY: arrowPhysics.hitLocalY,
          hitZ: arrowPhysics.targetDistance,
          pitch: arrowPhysics.pitch,
          yaw: arrowPhysics.yaw,
          penetrationDepth: arrowPhysics.penetrationDepth,
        ));
      } else if (arrowPhysics.hitGround) {
        cameraRig.addShake(1.5);
      }

      final bool isLastArrow = currentArrowIndex >= 3;
      if (isLastArrow) {
        isSetComplete = true;
      }

      // Trigger closeup inspection
      cameraRig.onImpact(isLastArrowOfSet: isLastArrow);
      _notifyHud();
    }

    // 6. Update Stuck Arrows
    for (final arrow in stuckArrows) {
      arrow.update(clampedDt);
    }

    // NOTE: Intentionally no _notifyHud() here to avoid 60 rebuilds/sec!
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Layer 0: Park Background
    background.render(canvas);

    // Layer 1: Wind Flag beside target
    windFlag.render(canvas);

    // Layer 2: White Target Board, Wooden Frame & WA Face
    targetBoard.render(canvas);

    // Layer 3: Stuck Arrows embedded in board
    for (final arrow in stuckArrows) {
      arrow.render(canvas, archeryCamera);
    }

    // Layer 4: Flying Arrow + Motion Trail
    flyingArrow.render(canvas);

    // Layer 5: Wind Particles
    windParticles.render(canvas);

    // Layer 6: World-Anchored Wind Pill
    windPill.render(canvas, windModel);

    // Layer 7: Foreground Recurve Bow Overlay
    bowOverlay.render(canvas);

    // Layer 8: Crosshair, Steady Ring & Shot Timer Arc
    controller.render(canvas);
  }

  @override
  Color backgroundColor() => const Color(0xFF6BA4E8);
}
