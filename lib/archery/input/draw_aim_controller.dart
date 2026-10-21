import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';
import '../physics/sway_model.dart';

/// GamePigeon-style thumb-roll aim controller with steady ring and shot timer arc.
class DrawAimController {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  DrawAimController({required this.camera, required this.cameraRig});

  // Callbacks
  void Function(double crosshairX, double crosshairY)? onFireAt;
  void Function()? onHoldStarted;
  void Function()? onHoldCancelled;

  // Touch Tracking
  int? _activePointerId;
  double _anchorX = 0.0;
  double _anchorY = 0.0;
  bool isHolding = false;
  double holdTime = 0.0;

  // Screen metrics & target center
  double screenW = 0.0;
  double screenH = 0.0;
  bool isCancelZone = false;

  // Crosshair Positions (Screen Pixels)
  double rawTargetX = 0.0;
  double rawTargetY = 0.0;
  double crosshairSmoothX = 0.0;
  double crosshairSmoothY = 0.0;
  double crosshairShownX = 0.0;
  double crosshairShownY = 0.0;

  // Seeded Sway Model
  SwayModel? _swayModel;

  // Unit rect for zero-allocation arc scaling
  static const Rect _unitRect = Rect.fromLTRB(-1.0, -1.0, 1.0, 1.0);

  // Cached Paints for Crosshair, Steady Ring, and Timer Arc
  final Paint _crosshairOutlinePaint = Paint()
    ..color = Colors.white
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _crosshairInnerPaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _steadyRingPaint = Paint()
    ..color = const Color(0xFFEF4444).withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke;
  final Paint _timerArcPaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void initSwaySeed(int seed) {
    _swayModel = SwayModel(seed: seed);
  }

  /// Target center X on screen in aiming pose (centered).
  double get aimingTargetCenterX => screenW * 0.5;

  /// Target face radius in screen pixels in the aiming pose at [distance].
  double _faceRadiusPxAt(double distance) {
    final double depth = distance - ArcheryK.camAimZ;
    return camera.baseFocal * cameraRig.aimZoom / depth * ArcheryK.faceRadius;
  }

  /// Face radius of the current set's target while aiming.
  double get _aimFaceRadiusPx => _faceRadiusPxAt(cameraRig.targetDistance);

  /// Target center Y on screen computed in the aiming pose.
  double get aimingTargetCenterY {
    final double depth = cameraRig.targetDistance - ArcheryK.camAimZ;
    final double focal = camera.baseFocal * cameraRig.aimZoom;
    return camera.opticalCenterY - focal * (ArcheryK.targetCenterY - ArcheryK.eyeY) / depth;
  }

  void onPointerDown(int pointerId, double x, double y) {
    if (_activePointerId != null) return; // Track first finger only
    if (cameraRig.phase != ShotPhase.atLine && cameraRig.phase != ShotPhase.returning) return;

    _activePointerId = pointerId;
    isHolding = true;
    holdTime = 0.0;
    _anchorX = x;
    _anchorY = y;

    // Center crosshair at target center in aiming pose (Bug #1 fix)
    final double centerX = aimingTargetCenterX;
    final double centerY = aimingTargetCenterY;
    rawTargetX = centerX;
    rawTargetY = centerY;
    crosshairSmoothX = centerX;
    crosshairSmoothY = centerY;
    crosshairShownX = centerX;
    crosshairShownY = centerY;

    cameraRig.startRaising();
    onHoldStarted?.call();
  }

  void onPointerMove(int pointerId, double x, double y) {
    if (_activePointerId != pointerId || !isHolding) return;

    // Aim gain is calibrated on the 50 ft face and NOT rescaled for farther
    // sets: the same thumb roll covers more rings at 100/150 ft (harder).
    const double thumbPxToFaceEdge = 22.0; // at 50 ft; tune 16-30
    final double depth = cameraRig.targetDistance - ArcheryK.camAimZ;
    final double focal = camera.baseFocal * cameraRig.aimZoom;
    final double gain = _faceRadiusPxAt(ArcheryK.distanceM) / thumbPxToFaceEdge;

    // Anchor-relative thumb-roll movement
    final double deltaX = (x - _anchorX) * gain;
    final double deltaY = (y - _anchorY) * gain;

    final double centerX = aimingTargetCenterX;
    final double centerY = aimingTargetCenterY;

    // Clamp crosshair box to ±1.6 board width around target center
    final double maxOffset = (focal / depth) * ArcheryK.boardWidth * 0.8;

    rawTargetX = (centerX + deltaX).clamp(centerX - maxOffset, centerX + maxOffset);
    rawTargetY = (centerY + deltaY).clamp(centerY - maxOffset, centerY + maxOffset);
  }

  void onPointerUp(int pointerId) {
    if (_activePointerId != pointerId) return;
    _activePointerId = null;

    if (!isHolding) return;
    isHolding = false;

    if (cameraRig.phase == ShotPhase.aiming) {
      // Fire shot at current visible crosshair point
      onFireAt?.call(crosshairShownX, crosshairShownY);
    } else {
      // Cancelled before full aim
      cameraRig.cancelAim();
      onHoldCancelled?.call();
    }
  }

  void onPointerCancel() {
    _activePointerId = null;
    if (isHolding) {
      isHolding = false;
      cameraRig.cancelAim();
      onHoldCancelled?.call();
    }
  }

  void update(double dt) {
    if (isHolding) {
      holdTime += dt;

      // Low-pass exponential filter on crosshair (removes finger jitter)
      final double smoothFactor = 1.0 - math.exp(-ArcheryK.aimSmoothOmega * dt);
      crosshairSmoothX += (rawTargetX - crosshairSmoothX) * smoothFactor;
      crosshairSmoothY += (rawTargetY - crosshairSmoothY) * smoothFactor;

      // Deterministic visible sway via SwayModel
      _swayModel?.update(holdTime, isHolding);
      final double swayYaw = _swayModel?.swayYaw ?? 0.0;
      final double swayPitch = _swayModel?.swayPitch ?? 0.0;

      final double f = camera.focalLengthPx;
      crosshairShownX = crosshairSmoothX + swayYaw * f;
      crosshairShownY = crosshairSmoothY - swayPitch * f;

      // Auto-fire when timer reaches 5.0 seconds
      if (holdTime >= ArcheryK.shotTimerSeconds && cameraRig.phase == ShotPhase.aiming) {
        isHolding = false;
        onFireAt?.call(crosshairShownX, crosshairShownY);
      }
    }
  }

  void render(Canvas canvas) {
    if (cameraRig.phase != ShotPhase.aiming && cameraRig.phase != ShotPhase.raising) {
      return;
    }

    final double cx = crosshairShownX;
    final double cy = crosshairShownY;
    final double uiScale = camera.uiScale;

    canvas.save();
    canvas.translate(cx, cy);

    // 1. Steady Ring (shrinks from ringStartRadiusFrac down to just outside the face over 1.8s)
    // Settle just outside the target face (GamePigeon), never over the rings.
    final double minRadius = math.max(24.0 * uiScale, _aimFaceRadiusPx * 1.18);
    final double maxRadius = math.max(screenW * ArcheryK.ringStartRadiusFrac, minRadius * 1.6);
    final double settleT = (holdTime / ArcheryK.ringSettleSeconds).clamp(0.0, 1.0);
    final double ease = 1.0 - math.pow(1.0 - settleT, 3.0); // easeOutCubic
    final double ringRadius = maxRadius + (minRadius - maxRadius) * ease;

    _steadyRingPaint.strokeWidth = 2.0 * uiScale;
    canvas.drawCircle(Offset.zero, ringRadius, _steadyRingPaint);

    // 2. Shot Timer Arc (clockwise fill from 12 o'clock outside steady ring)
    final double timerRatio = (holdTime / ArcheryK.shotTimerSeconds).clamp(0.0, 1.0);
    if (timerRatio > 0.0) {
      final double arcRadius = ringRadius + 5.0 * uiScale;
      canvas.save();
      canvas.scale(arcRadius);
      _timerArcPaint.strokeWidth = (4.0 * uiScale) / arcRadius;
      canvas.drawArc(
        _unitRect,
        -math.pi * 0.5, // 12 o'clock
        2.0 * math.pi * timerRatio,
        false,
        _timerArcPaint,
      );
      canvas.restore();
    }

    // 3. Precision Crosshair (4 dashes, white outline + red core, gap in middle)
    final double innerGap = 6.0 * uiScale;
    final double dashLen = 10.0 * uiScale;

    _crosshairOutlinePaint.strokeWidth = 3.5 * uiScale;
    _crosshairInnerPaint.strokeWidth = 2.0 * uiScale;

    _drawCrossDash(canvas, -innerGap - dashLen, 0.0, -innerGap, 0.0);
    _drawCrossDash(canvas, innerGap, 0.0, innerGap + dashLen, 0.0);
    _drawCrossDash(canvas, 0.0, -innerGap - dashLen, 0.0, -innerGap);
    _drawCrossDash(canvas, 0.0, innerGap, 0.0, innerGap + dashLen);

    canvas.restore();
  }

  void _drawCrossDash(Canvas canvas, double x1, double y1, double x2, double y2) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _crosshairOutlinePaint);
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _crosshairInnerPaint);
  }
}
