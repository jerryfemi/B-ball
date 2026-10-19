import '../archery_constants.dart';
import '../camera/camera_rig.dart';

/// Single-finger draw, aim, and release controller.
class DrawAimController {
  final CameraRig cameraRig;

  DrawAimController({required this.cameraRig});

  // --- Callbacks ---
  void Function()? onFullDraw;
  void Function(double drawRatio, double holdSeconds)? onFire;
  void Function()? onCancel;

  // --- State ---
  bool isHolding = false;
  double draw = 0.0;
  double holdTime = 0.0;
  bool isCancelZone = false;
  bool _hasTriggeredFullDraw = false;

  // Screen height for cancel zone detection (bottom 12%)
  double screenH = 0.0;

  void onPointerDown(double x, double y) {
    isHolding = true;
    holdTime = 0.0;
    draw = 0.0;
    _hasTriggeredFullDraw = false;
    _checkCancelZone(y);
  }

  void onPointerMove(double x, double y, double dx, double dy) {
    if (!isHolding) return;
    _checkCancelZone(y);

    // Normalized aim rotation based on focal length
    final double f = cameraRig.camera.focalLengthPx;
    if (f > 0.0) {
      final double deltaYaw = -dx * ArcheryK.aimSensitivity / f;
      final double deltaPitch = dy * ArcheryK.aimSensitivity / f;
      cameraRig.addAimDelta(deltaYaw, deltaPitch);
    }
  }

  void onPointerUp(double x, double y) {
    if (!isHolding) return;
    _checkCancelZone(y);

    if (isCancelZone) {
      onCancel?.call();
    } else {
      // Fire shot with current draw and hold duration
      onFire?.call(draw, holdTime);
    }

    _endHold();
  }

  void onPointerCancel() {
    if (!isHolding) return;
    onCancel?.call();
    _endHold();
  }

  void _endHold() {
    isHolding = false;
    isCancelZone = false;
    _hasTriggeredFullDraw = false;
  }

  void _checkCancelZone(double y) {
    if (screenH > 0.0) {
      // Bottom 12% is cancel zone
      isCancelZone = y >= screenH * 0.88;
    }
  }

  void update(double dt) {
    if (isHolding) {
      holdTime += dt;
      // Auto-draw ease-out curve from 0 to 1 over autoDrawSeconds
      final double progress = (holdTime / ArcheryK.autoDrawSeconds).clamp(0.0, 1.0);
      final double inv = 1.0 - progress;
      draw = 1.0 - (inv * inv * inv);

      if (!_hasTriggeredFullDraw && draw >= ArcheryK.fullDrawPlateau) {
        _hasTriggeredFullDraw = true;
        onFullDraw?.call();
      }
    } else {
      // Smoothly return bow to rest when not drawn
      if (draw > 0.0) {
        draw -= dt * 6.0;
        if (draw < 0.0) draw = 0.0;
      }
      holdTime = 0.0;
    }
  }
}
