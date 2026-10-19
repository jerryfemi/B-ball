import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'archery_constants.dart';
import 'camera/archery_camera.dart';
import 'camera/camera_rig.dart';
import 'components/bow_overlay.dart';
import 'components/flying_arrow.dart';
import 'components/range_background.dart';
import 'components/stuck_arrow.dart';
import 'components/target_board.dart';
import 'input/draw_aim_controller.dart';
import 'physics/arrow_physics.dart';
import 'physics/sight_solver.dart';
import 'physics/target_scoring.dart';

/// Flame game instance managing the 3D archery range, camera, physics, and round loop.
///
/// Adheres strictly to:
/// - Zero allocations per frame in [update] and [render].
/// - 60 FPS performance on mobile and web.
/// - Isolated local gameplay.
class ArcheryGame extends FlameGame {
  // --- Core Systems ---
  late final ArcheryCamera archeryCamera;
  late final CameraRig cameraRig;
  late final DrawAimController controller;

  // --- Physics & Flight ---
  final ArrowPhysics3D arrowPhysics = ArrowPhysics3D();
  double sightPitchOffset = 0.0;

  // --- Components ---
  late final RangeBackground background;
  late final TargetBoard targetBoard;
  late final BowOverlay bowOverlay;
  late final FlyingArrow flyingArrow;
  final List<StuckArrow> stuckArrows = [];

  // --- Round & Match Scoring State ---
  int currentRoundIndex = 0; // 0 = 20m, 1 = 40m, 2 = 60m
  int currentArrowIndex = 0; // 0, 1, 2
  final List<List<ShotScore>> roundScores = [[], [], []];
  bool isRoundComplete = false;
  bool isMatchComplete = false;

  // --- Hit Popup Trigger State ---
  ShotScore? lastShotScore;
  Offset? lastHitScreenPos;

  // --- State & HUD Link ---
  final ValueNotifier<int> hudNotifier = ValueNotifier<int>(0);
  double targetDistance = ArcheryK.distNear;

  ArcheryGame() {
    archeryCamera = ArcheryCamera();
    cameraRig = CameraRig(camera: archeryCamera);
    controller = DrawAimController(cameraRig: cameraRig);
    background = RangeBackground(camera: archeryCamera);
    targetBoard = TargetBoard(camera: archeryCamera, initialDistance: targetDistance);
    bowOverlay = BowOverlay();
    flyingArrow = FlyingArrow(camera: archeryCamera, physics: arrowPhysics);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    cameraRig.setTargetDistance(targetDistance);
    background.activeDistance = targetDistance;
    _calibrateSight();

    // Connect controller callbacks
    controller.onFullDraw = () {
      // Light haptic feel via camera pulse
      cameraRig.addShake(1.5);
      _notifyHud();
    };

    controller.onFire = (double draw, double holdSeconds) {
      if (isRoundComplete || arrowPhysics.inFlight) return;

      // Speed calculation with under-draw drop penalty
      final double dRatio = draw >= ArcheryK.fullDrawPlateau
          ? 1.0
          : (draw / ArcheryK.fullDrawPlateau).clamp(0.0, 1.0);
      final double speed = ArcheryK.fullDrawSpeed *
          (ArcheryK.minDrawSpeedRatio + (1.0 - ArcheryK.minDrawSpeedRatio) * dRatio);

      // Launch direction: Aim + Sight calibration offset + sway
      final double launchPitch = cameraRig.currentPitch + sightPitchOffset;
      final double launchYaw = cameraRig.currentYaw;

      arrowPhysics.launch(
        launchYaw: launchYaw,
        launchPitch: launchPitch,
        speed: speed,
        targetDist: targetDistance,
      );

      flyingArrow.resetTrail();
      cameraRig.addShake(3.5);
      bowOverlay.onRelease();
      _notifyHud();
    };

    controller.onCancel = () {
      _notifyHud();
    };
  }

  void _calibrateSight() {
    sightPitchOffset = SightSolver.getSightPitchOffset(targetDistance);
  }

  /// Advances to the next distance round (or restarts match if complete).
  void advanceNextRound() {
    if (isMatchComplete) {
      restartMatch();
      return;
    }

    currentRoundIndex++;
    currentArrowIndex = 0;
    isRoundComplete = false;
    stuckArrows.clear();
    setTargetDistance(ArcheryK.roundDistances[currentRoundIndex]);
  }

  /// Restarts from Round 1 (20m).
  void restartMatch() {
    currentRoundIndex = 0;
    currentArrowIndex = 0;
    isRoundComplete = false;
    isMatchComplete = false;
    roundScores[0].clear();
    roundScores[1].clear();
    roundScores[2].clear();
    lastShotScore = null;
    lastHitScreenPos = null;
    stuckArrows.clear();
    setTargetDistance(ArcheryK.roundDistances[0]);
  }

  /// Dismisses the active hit popup.
  void clearLastHitPopup() {
    lastShotScore = null;
    lastHitScreenPos = null;
    _notifyHud();
  }

  int get totalScore =>
      roundScores.expand((r) => r).fold(0, (sum, s) => sum + s.points);

  int get totalXCount =>
      roundScores.expand((r) => r).where((s) => s.isX).length;

  /// Changes downrange target distance (20m, 40m, 60m).
  void setTargetDistance(double distance) {
    targetDistance = distance;
    stuckArrows.clear();
    _calibrateSight();
    cameraRig.setTargetDistance(distance);
    targetBoard.updateDistance(distance);
    background.activeDistance = distance;
    _notifyHud();
  }

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
    controller.screenH = h;
    background.resize(w, h);
    bowOverlay.resize(w, h);

    archeryCamera.prepare();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Clamp frame dt to avoid physics and spring spikes
    final double clampedDt = dt.clamp(0.0, 0.05);

    // 1. Update Input & Draw Mechanics
    controller.update(clampedDt);

    // 2. Update Camera Rig (Spring Zoom, Aim, Shake)
    cameraRig.update(clampedDt, controller.draw, controller.isHolding);

    // 3. Update Foreground Bow Overlay
    bowOverlay.update(clampedDt, controller.draw, controller.isHolding);

    // 4. Update Arrow Physics Simulation
    final bool wasInFlight = arrowPhysics.inFlight;
    arrowPhysics.update(clampedDt);

    // Detect impact
    if (wasInFlight && !arrowPhysics.inFlight) {
      // Calculate ring score
      final ShotScore score = TargetScoring.calculate(
        localX: arrowPhysics.hitLocalX,
        localY: arrowPhysics.hitLocalY,
        hitBoss: arrowPhysics.hitBoss,
        distance: targetDistance,
      );

      // Record shot in round score history
      if (currentRoundIndex < roundScores.length &&
          roundScores[currentRoundIndex].length < 3) {
        roundScores[currentRoundIndex].add(score);
        currentArrowIndex = roundScores[currentRoundIndex].length;
      }

      // Hit Popup position in screen space
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
        cameraRig.addShake(score.isX ? 7.0 : 4.5); // Bigger impact thunk for X
        if (stuckArrows.length >= 3) {
          stuckArrows.removeAt(0);
        }
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

      // Check for round completion (3 arrows shot)
      if (roundScores[currentRoundIndex].length >= 3) {
        isRoundComplete = true;
        if (currentRoundIndex >= 2) {
          isMatchComplete = true;
        }
      }
    }

    // 5. Update Stuck Arrows Quiver
    for (final arrow in stuckArrows) {
      arrow.update(clampedDt);
    }

    // Notify Flutter HUD of state changes
    _notifyHud();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Strict priority layer rendering (Zero allocation):
    // Layer 0-2: Range background (Sky, Treeline, 3D Lanes, Floodlights)
    background.render(canvas);

    // Layer 3-4: Target Stand, Straw Boss & Procedural WA Face
    targetBoard.render(canvas);

    // Layer 5: Stuck Arrows
    for (final arrow in stuckArrows) {
      arrow.render(canvas, archeryCamera);
    }

    // Layer 6: Flying Arrow + Motion Trail
    flyingArrow.render(canvas);

    // Layer 10: First-Person Bow Overlay, Bowstring & Precision Reticle
    bowOverlay.render(canvas);
  }

  @override
  Color backgroundColor() => const Color(0xFF060913);
}
