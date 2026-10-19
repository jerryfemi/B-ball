import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Foreground first-person recurve bow, dynamic string, and sight reticle.
///
/// Features:
/// - First-person recurve bow with carbon riser and flexible limbs.
/// - Dynamic string tension: two line segments from limb tips to nock point.
/// - String release oscillation: high-frequency damped sine wave.
/// - Idle lowering and smooth draw raise.
/// - Precision glowing sight reticle at screen center.
class BowOverlay {
  // --- Cached Paints ---
  final Paint _riserPaint = Paint()
    ..color = const Color(0xFF1E2638)
    ..style = PaintingStyle.fill;
  final Paint _riserHighlightPaint = Paint()
    ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _limbPaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..strokeWidth = 14.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _limbCorePaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _stringPaint = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _reticleRingPaint = Paint()
    ..color = const Color(0x8838BDF8)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  final Paint _reticleCrossPaint = Paint()
    ..color = const Color(0x6638BDF8)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  final Paint _reticleDotPaint = Paint()
    ..color = const Color(0xFF00FFCC)
    ..style = PaintingStyle.fill;
  final Paint _reticleDotGlowPaint = Paint()
    ..color = const Color(0x4400FFCC)
    ..style = PaintingStyle.fill;
  final Paint _arrowShaftPaint = Paint()
    ..color = const Color(0xFF334155)
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;
  final Paint _arrowVanePaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..style = PaintingStyle.fill;

  // Reusable paths
  final Path _riserPath = Path();
  final Path _upperLimbPath = Path();
  final Path _lowerLimbPath = Path();
  final Path _vanePath = Path();

  // Screen metrics
  double screenW = 0.0;
  double screenH = 0.0;

  // Bow animation state
  double raiseProgress = 0.0; // 0 = lowered/idle, 1 = raised
  double releaseTimer = 100.0; // For string twang vibration
  bool isHolding = false;
  double draw = 0.0;

  void resize(double width, double height) {
    screenW = width;
    screenH = height;
  }

  void onRelease() {
    releaseTimer = 0.0;
  }

  void update(double dt, double currentDraw, bool holding) {
    draw = currentDraw;
    isHolding = holding;

    // Smoothly raise bow on touch hold, lower when idle
    if (isHolding) {
      raiseProgress = (raiseProgress + dt * 4.5).clamp(0.0, 1.0);
    } else {
      raiseProgress = (raiseProgress - dt * 3.0).clamp(0.0, 1.0);
    }

    // Release string oscillation timer
    if (releaseTimer < 0.25) {
      releaseTimer += dt;
    }
  }

  void render(Canvas canvas) {
    if (screenW <= 0.0 || screenH <= 0.0) return;

    final double cx = screenW * 0.5;
    final double cy = screenH * 0.5;

    // 1. Render Center Sight Reticle
    _renderSightReticle(canvas, cx, cy);

    // 2. Render First-Person Bow
    _renderBow(canvas, cx, cy);
  }

  void _renderSightReticle(Canvas canvas, double cx, double cy) {
    const double radius = 18.0;
    const double gap = 5.0;
    const double crossLen = 10.0;

    // Precision outer ring
    canvas.drawCircle(Offset(cx, cy), radius, _reticleRingPaint);

    // Crosshairs with central gap
    canvas.drawLine(
      Offset(cx - radius - crossLen, cy),
      Offset(cx - gap, cy),
      _reticleCrossPaint,
    );
    canvas.drawLine(
      Offset(cx + gap, cy),
      Offset(cx + radius + crossLen, cy),
      _reticleCrossPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - radius - crossLen),
      Offset(cx, cy - gap),
      _reticleCrossPaint,
    );
    canvas.drawLine(
      Offset(cx, cy + gap),
      Offset(cx, cy + radius + crossLen),
      _reticleCrossPaint,
    );

    // Glowing fiber-optic center pin
    canvas.drawCircle(Offset(cx, cy), 5.5, _reticleDotGlowPaint);
    canvas.drawCircle(Offset(cx, cy), 2.2, _reticleDotPaint);
  }

  void _renderBow(Canvas canvas, double cx, double cy) {
    // Vertical slide offset: lowered by 160px when idle
    final double idleLowerY = (1.0 - raiseProgress) * 160.0;

    // Bow riser center anchor on screen (left of center)
    final double bowBaseX = cx - (screenW * 0.22).clamp(70.0, 140.0);
    final double bowBaseY = cy + 40.0 + idleLowerY;

    // Flex: limbs bend inward by up to 18px as draw approaches 1.0
    final double flexX = draw * 20.0;
    final double flexY = draw * 10.0;

    // Limb tips in screen space
    final double upperTipX = bowBaseX - 35.0 + flexX;
    final double upperTipY = bowBaseY - (screenH * 0.46) + flexY;

    final double lowerTipX = bowBaseX - 30.0 + flexX;
    final double lowerTipY = bowBaseY + (screenH * 0.42) - flexY;

    // String nock position:
    // Rest position: near bow riser center-left.
    // Full draw position: pulled back toward the bottom-center anchor.
    final double restNockX = bowBaseX - 15.0;
    final double restNockY = bowBaseY - 10.0;
    final double drawnNockX = cx + (screenW * 0.08);
    final double drawnNockY = cy + (screenH * 0.22);

    double nockX = restNockX + (drawnNockX - restNockX) * draw;
    double nockY = restNockY + (drawnNockY - restNockY) * draw;

    // String twang damped oscillation on release: sin(2π * 25t) * exp(-t / 0.08)
    if (releaseTimer < 0.25) {
      final double twang = math.sin(releaseTimer * 2.0 * math.pi * 25.0) *
          math.exp(-releaseTimer / 0.08) *
          16.0;
      nockX += twang;
    }

    // --- Render Upper & Lower Limbs ---
    _upperLimbPath.reset();
    _upperLimbPath.moveTo(bowBaseX - 10.0, bowBaseY - 50.0);
    _upperLimbPath.quadraticBezierTo(
      bowBaseX - 45.0 + flexX * 0.5,
      bowBaseY - (screenH * 0.25),
      upperTipX,
      upperTipY,
    );
    canvas.drawPath(_upperLimbPath, _limbPaint);
    canvas.drawPath(_upperLimbPath, _limbCorePaint);

    _lowerLimbPath.reset();
    _lowerLimbPath.moveTo(bowBaseX - 10.0, bowBaseY + 50.0);
    _lowerLimbPath.quadraticBezierTo(
      bowBaseX - 40.0 + flexX * 0.5,
      bowBaseY + (screenH * 0.22),
      lowerTipX,
      lowerTipY,
    );
    canvas.drawPath(_lowerLimbPath, _limbPaint);
    canvas.drawPath(_lowerLimbPath, _limbCorePaint);

    // --- Render Riser / Handle ---
    _riserPath.reset();
    _riserPath.moveTo(bowBaseX - 14.0, bowBaseY - 60.0);
    _riserPath.quadraticBezierTo(bowBaseX + 6.0, bowBaseY, bowBaseX - 14.0, bowBaseY + 60.0);
    _riserPath.lineTo(bowBaseX - 2.0, bowBaseY + 55.0);
    _riserPath.quadraticBezierTo(bowBaseX + 16.0, bowBaseY, bowBaseX - 2.0, bowBaseY - 55.0);
    _riserPath.close();

    canvas.drawPath(_riserPath, _riserPaint);
    canvas.drawPath(_riserPath, _riserHighlightPaint);

    // --- Render Bowstring (Upper & Lower segments meeting at nock) ---
    canvas.drawLine(Offset(upperTipX, upperTipY), Offset(nockX, nockY), _stringPaint);
    canvas.drawLine(Offset(nockX, nockY), Offset(lowerTipX, lowerTipY), _stringPaint);

    // --- Render Loaded Arrow on the Bow while drawn or raised ---
    if (raiseProgress > 0.05) {
      _renderLoadedArrow(canvas, nockX, nockY, cx, cy);
    }
  }

  void _renderLoadedArrow(
    Canvas canvas,
    double nockX,
    double nockY,
    double targetX,
    double targetY,
  ) {
    // Arrow shaft points from nock toward screen center
    final double dirX = targetX - nockX;
    final double dirY = targetY - nockY;
    final double len = math.sqrt(dirX * dirX + dirY * dirY);
    if (len < 1.0) return;

    final double uX = dirX / len;
    final double uY = dirY / len;
    final double tipX = nockX + uX * (len * 0.95);
    final double tipY = nockY + uY * (len * 0.95);

    // Shaft
    canvas.drawLine(Offset(nockX, nockY), Offset(tipX, tipY), _arrowShaftPaint);

    // Fletchings (vanes) near nock
    final double perpX = -uY * 7.0;
    final double perpY = uX * 7.0;

    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + uX * 24.0 + perpX, nockY + uY * 24.0 + perpY);
    _vanePath.lineTo(nockX + uX * 36.0, nockY + uY * 36.0);
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);

    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + uX * 24.0 - perpX, nockY + uY * 24.0 - perpY);
    _vanePath.lineTo(nockX + uX * 36.0, nockY + uY * 36.0);
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);
  }
}
