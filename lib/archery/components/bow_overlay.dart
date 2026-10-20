import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Foreground first-person wooden recurve bow with nocked arrow (Build Plan v2 §8.1).
///
/// Features:
/// - atLine: Wooden recurve bow rests on right edge (x ≈ 0.82W), vertical, rotated -6°.
/// - Arrow rests on the grip, pointing diagonally toward the target with red vanes.
/// - raising: Over 0.5s slides down and right, scales up 1.15x and fades out.
/// - aiming / chase / closeup: Fully hidden (zero draw cost).
/// - returning: Slides back in with fresh arrow nocked.
/// - Zero runtime heap allocations.
class BowOverlay {
  // --- Cached Paints ---
  final Paint _woodRiserPaint = Paint()
    ..color = const Color(0xFF6B4226)
    ..style = PaintingStyle.fill;
  final Paint _woodRiserHighlightPaint = Paint()
    ..color = const Color(0xFF9E6840)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _woodLimbPaint = Paint()
    ..color = const Color(0xFF4A2E1B)
    ..strokeWidth = 14.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _woodLimbCorePaint = Paint()
    ..color = const Color(0xFF5C3A21)
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _stringPaint = Paint()
    ..color = const Color(0xFFF1F5F9)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;
  final Paint _arrowShaftPaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;
  final Paint _arrowTipPaint = Paint()
    ..color = const Color(0xFF94A3B8)
    ..strokeWidth = 5.0
    ..style = PaintingStyle.stroke;
  final Paint _arrowVanePaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..style = PaintingStyle.fill;
  final Paint _alphaPaint = Paint();

  // Reusable Paths
  final Path _riserPath = Path();
  final Path _upperLimbPath = Path();
  final Path _lowerLimbPath = Path();
  final Path _vanePath = Path();

  // Screen metrics & state
  double screenW = 0.0;
  double screenH = 0.0;
  double slideProgress = 0.0; // 0.0 = visible at line, 1.0 = slid out

  void resize(double width, double height) {
    screenW = width;
    screenH = height;
  }

  void onRelease() {}

  void update(double dt, double currentDraw, bool holding, {double slide = 0.0}) {
    slideProgress = slide;
  }

  void render(Canvas canvas) {
    if (screenW <= 0.0 || screenH <= 0.0 || slideProgress >= 1.0) return;

    final double alpha = (1.0 - slideProgress).clamp(0.0, 1.0);
    final double slideOffsetX = slideProgress * screenW * 0.35;
    final double slideOffsetY = slideProgress * screenH * 0.45;
    final double scale = 1.0 + slideProgress * 0.15;

    canvas.save();
    if (alpha < 0.99) {
      _alphaPaint.color = Color.fromRGBO(0, 0, 0, alpha);
      canvas.saveLayer(Rect.fromLTWH(0, 0, screenW, screenH), _alphaPaint);
    }

    // Anchor: right side of the screen
    final double bowBaseX = screenW * 0.82 + slideOffsetX;
    final double bowBaseY = screenH * 0.65 + slideOffsetY;

    canvas.translate(bowBaseX, bowBaseY);
    canvas.scale(scale);
    canvas.rotate(-6.0 * math.pi / 180.0); // -6 degrees tilt

    // Draw Bow (relative to bow base)
    _renderRecurveBow(canvas);

    // Draw Loaded Arrow resting on grip
    _renderNockedArrow(canvas);

    if (alpha < 0.99) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _renderRecurveBow(Canvas canvas) {
    final double halfSpan = screenH * 0.35;
    const double upperTipX = -15.0;
    final double upperTipY = -halfSpan;
    const double lowerTipX = -12.0;
    final double lowerTipY = halfSpan;

    // 1. Upper Limb
    _upperLimbPath.reset();
    _upperLimbPath.moveTo(-6.0, -50.0);
    _upperLimbPath.quadraticBezierTo(-35.0, -halfSpan * 0.55, upperTipX, upperTipY);
    canvas.drawPath(_upperLimbPath, _woodLimbPaint);
    canvas.drawPath(_upperLimbPath, _woodLimbCorePaint);

    // 2. Lower Limb
    _lowerLimbPath.reset();
    _lowerLimbPath.moveTo(-6.0, 50.0);
    _lowerLimbPath.quadraticBezierTo(-32.0, halfSpan * 0.55, lowerTipX, lowerTipY);
    canvas.drawPath(_lowerLimbPath, _woodLimbPaint);
    canvas.drawPath(_lowerLimbPath, _woodLimbCorePaint);

    // 3. Wooden Riser
    _riserPath.reset();
    _riserPath.moveTo(-10.0, -60.0);
    _riserPath.quadraticBezierTo(4.0, 0.0, -10.0, 60.0);
    _riserPath.lineTo(-2.0, 55.0);
    _riserPath.quadraticBezierTo(12.0, 0.0, -2.0, -55.0);
    _riserPath.close();

    canvas.drawPath(_riserPath, _woodRiserPaint);
    canvas.drawPath(_riserPath, _woodRiserHighlightPaint);

    // 4. Bowstring (two straight segments meeting at nock)
    const Offset nock = Offset(-18.0, 0.0);
    canvas.drawLine(Offset(upperTipX, upperTipY), nock, _stringPaint);
    canvas.drawLine(nock, Offset(lowerTipX, lowerTipY), _stringPaint);
  }

  void _renderNockedArrow(Canvas canvas) {
    // Arrow shaft rests on grip and points diagonally forward/downrange
    const double nockX = -18.0;
    const double nockY = 0.0;
    const double tipX = -260.0;
    const double tipY = -120.0;

    // Shaft
    canvas.drawLine(const Offset(nockX, nockY), const Offset(tipX, tipY), _arrowShaftPaint);
    // Silver pile/point tip
    canvas.drawLine(const Offset(tipX + 15.0, tipY + 7.0), const Offset(tipX, tipY), _arrowTipPaint);

    // Direction vector for vanes
    final double dx = tipX - nockX;
    final double dy = tipY - nockY;
    final double len = math.sqrt(dx * dx + dy * dy);
    final double ux = dx / len;
    final double uy = dy / len;
    final double perpX = -uy * 8.0;
    final double perpY = ux * 8.0;

    // Upper red vane
    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + ux * 28.0 + perpX, nockY + uy * 28.0 + perpY);
    _vanePath.lineTo(nockX + ux * 42.0, nockY + uy * 42.0);
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);

    // Lower red vane
    _vanePath.reset();
    _vanePath.moveTo(nockX, nockY);
    _vanePath.lineTo(nockX + ux * 28.0 - perpX, nockY + uy * 28.0 - perpY);
    _vanePath.lineTo(nockX + ux * 42.0, nockY + uy * 42.0);
    _vanePath.close();
    canvas.drawPath(_vanePath, _arrowVanePaint);
  }
}
