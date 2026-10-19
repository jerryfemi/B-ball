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

/// Flame game instance managing the 3D archery range, camera, physics, and components.
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
      if (arrowPhysics.hitBoss) {
        cameraRig.addShake(5.0); // Impact thunk
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
