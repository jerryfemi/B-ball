import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';

/// GamePigeon-style thumb-roll aim controller with steady ring and shot timer arc.
class DrawAimController {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  DrawAimController({required this.camera, required this.cameraRig});

  // Callbacks
  void Function(double crosshairX, double crosshairY)? onFireAt;
  void Function()? onHoldStarted;
  void Function()? onHoldCancelled;
  void Function()? onFullDraw; // Kept for backwards compatibility
  void Function(double drawRatio, double holdSeconds)? onFire; // Legacy hook

  // Touch Tracking
  int? _activePointerId;
  double _anchorX = 0.0;
  double _anchorY = 0.0;
  bool isHolding = false;
  double holdTime = 0.0;
  double draw = 0.0; // Legacy 0..1 ratio for HUD

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

  // Seeded Sway Parameters
  double _p1 = 0.0;
  double _p2 = 0.0;
  double _p3 = 0.0;
  double _p4 = 0.0;

  // Cached Paints for Crosshair, Steady Ring, and Timer Arc
  final Paint _crosshairOutlinePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _crosshairInnerPaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _steadyRingPaint = Paint()
    ..color = const Color(0xFFEF4444).withValues(alpha: 0.35)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _timerArcPaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void initSwaySeed(int seed) {
    final math.Random rng = math.Random(seed);
    _p1 = rng.nextDouble() * 2.0 * math.pi;
    _p2 = rng.nextDouble() * 2.0 * math.pi;
    _p3 = rng.nextDouble() * 2.0 * math.pi;
    _p4 = rng.nextDouble() * 2.0 * math.pi;
  }

  void onPointerDown(int pointerId, double x, double y) {
    if (_activePointerId != null) return; // Track first finger only
    if (cameraRig.phase != ShotPhase.atLine && cameraRig.phase != ShotPhase.returning) return;

    _activePointerId = pointerId;
    isHolding = true;
    holdTime = 0.0;
    _anchorX = x;
    _anchorY = y;

    // Center crosshair at target optical center
    final double centerX = screenW * 0.5;
    final double centerY = camera.opticalCenterY;
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

    // Anchor-relative thumb-roll movement
    final double deltaX = (x - _anchorX) * ArcheryK.aimGain;
    final double deltaY = (y - _anchorY) * ArcheryK.aimGain;

    final double centerX = screenW * 0.5;
    final double centerY = camera.opticalCenterY;

    // Clamp crosshair box to ±1.6 board width around target
    final double pxPerM = camera.pxPerMeterAt(ArcheryK.distanceM - ArcheryK.camAimZ);
    final double maxOffset = pxPerM * ArcheryK.boardWidth * 0.8;

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
      cameraRig.fireShot();
      onFireAt?.call(crosshairShownX, crosshairShownY);
      onFire?.call(1.0, holdTime);
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
      draw = (holdTime / 0.6).clamp(0.0, 1.0);

      // Low-pass exponential filter on crosshair (removes finger jitter)
      final double smoothFactor = 1.0 - math.exp(-ArcheryK.aimSmoothOmega * dt);
      crosshairSmoothX += (rawTargetX - crosshairSmoothX) * smoothFactor;
      crosshairSmoothY += (rawTargetY - crosshairSmoothY) * smoothFactor;

      // Deterministic visible sway: Settling -> Steady window -> Fatigue
      final double t = holdTime;
      final double smoothStepFatigue = t <= ArcheryK.fatigueStart
          ? 0.0
          : ((t - ArcheryK.fatigueStart) / (ArcheryK.shotTimerSeconds - ArcheryK.fatigueStart))
              .clamp(0.0, 1.0);

      final double amp = ArcheryK.swaySettle * math.exp(-t / ArcheryK.swaySettleTau) +
          ArcheryK.swayBase +
          ArcheryK.swayFatigue * smoothStepFatigue;

      final double swayYaw = amp *
          (math.sin(1.3 * t + _p1) + 0.5 * math.sin(2.9 * t + _p2)) / 1.5;
      final double swayPitch = amp *
          (math.sin(1.1 * t + _p3) + 0.5 * math.sin(3.7 * t + _p4)) / 1.5;

      final double f = camera.focalLengthPx;
      crosshairShownX = crosshairSmoothX + swayYaw * f;
      crosshairShownY = crosshairSmoothY - swayPitch * f;

      // Auto-fire when timer reaches 5.0 seconds
      if (holdTime >= ArcheryK.shotTimerSeconds && cameraRig.phase == ShotPhase.aiming) {
        isHolding = false;
        cameraRig.fireShot();
        onFireAt?.call(crosshairShownX, crosshairShownY);
        onFire?.call(1.0, holdTime);
      }
    }
  }

  void render(Canvas canvas) {
    if (cameraRig.phase != ShotPhase.aiming && cameraRig.phase != ShotPhase.raising) {
      return;
    }

    final double cx = crosshairShownX;
    final double cy = crosshairShownY;

    // 1. Steady Ring (shrinks from ringStartRadiusFrac down to ~28px over 1.8s)
    const double minRadius = 24.0;
    final double maxRadius = screenW * ArcheryK.ringStartRadiusFrac;
    final double settleT = (holdTime / ArcheryK.ringSettleSeconds).clamp(0.0, 1.0);
    final double ease = 1.0 - math.pow(1.0 - settleT, 3.0); // easeOutCubic
    final double ringRadius = maxRadius + (minRadius - maxRadius) * ease;

    canvas.drawCircle(Offset(cx, cy), ringRadius, _steadyRingPaint);

    // 2. Shot Timer Arc (clockwise fill from 12 o'clock outside steady ring)
    final double timerRatio = (holdTime / ArcheryK.shotTimerSeconds).clamp(0.0, 1.0);
    if (timerRatio > 0.0) {
      final double arcRadius = ringRadius + 4.0;
      final Rect arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: arcRadius);
      canvas.drawArc(
        arcRect,
        -math.pi * 0.5, // 12 o'clock
        2.0 * math.pi * timerRatio,
        false,
        _timerArcPaint,
      );
    }

    // 3. Precision Crosshair (4 dashes, white outline + red core, gap in middle)
    const double innerGap = 6.0;
    const double dashLen = 10.0;

    _drawCrossDash(canvas, cx - innerGap - dashLen, cy, cx - innerGap, cy);
    _drawCrossDash(canvas, cx + innerGap, cy, cx + innerGap + dashLen, cy);
    _drawCrossDash(canvas, cx, cy - innerGap - dashLen, cx, cy - innerGap);
    _drawCrossDash(canvas, cx, cy + innerGap, cx, cy + innerGap + dashLen);
  }

  void _drawCrossDash(Canvas canvas, double x1, double y1, double x2, double y2) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _crosshairOutlinePaint);
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _crosshairInnerPaint);
  }
}
