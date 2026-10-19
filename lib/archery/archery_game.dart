import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'archery_constants.dart';
import 'camera/archery_camera.dart';
import 'camera/camera_rig.dart';
import 'components/bow_overlay.dart';
import 'components/range_background.dart';
import 'components/target_board.dart';
import 'input/draw_aim_controller.dart';

/// Flame game instance managing the 3D archery range, camera, and components.
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

  // --- Components ---
  late final RangeBackground background;
  late final TargetBoard targetBoard;
  late final BowOverlay bowOverlay;

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
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    cameraRig.setTargetDistance(targetDistance);
    background.activeDistance = targetDistance;

    // Connect controller callbacks
    controller.onFullDraw = () {
      // Light haptic feel via camera pulse
      cameraRig.addShake(1.5);
      _notifyHud();
    };

    controller.onFire = (double draw, double holdSeconds) {
      // String twang and release shake
      cameraRig.addShake(4.0);
      bowOverlay.onRelease();
      _notifyHud();
    };

    controller.onCancel = () {
      _notifyHud();
    };
  }

  /// Changes downrange target distance (20m, 40m, 60m).
  void setTargetDistance(double distance) {
    targetDistance = distance;
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

    // Layer 10: First-Person Bow Overlay, Bowstring & Precision Reticle
    bowOverlay.render(canvas);
  }

  @override
  Color backgroundColor() => const Color(0xFF060913);
}
