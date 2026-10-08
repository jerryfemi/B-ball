import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders the front half of the metal rim, mounting bracket, and front net cords.
/// Configured with priority = 3 so it renders in front of the basketball (priority = 2),
/// completing the 2.5D immersion when the ball drops into the hoop.
class FrontRimVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  FrontRimVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.45,
  }) : super(
          position: position,
          size: Vector2(4.0, 4.0),
          anchor: Anchor.center,
          priority: 3,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);

    _renderMountingBracket(canvas);
    _renderFrontNet(canvas);
    _renderFrontRim(canvas);

    canvas.restore();
  }

  void _renderMountingBracket(Canvas canvas) {
    final bracketPaint = Paint()
      ..color = const Color(0xFFD84315)
      ..style = PaintingStyle.fill;

    // Small mounting flange connecting rim to backboard
    final bracketRect = Rect.fromCenter(
      center: const Offset(0, -0.15),
      width: 0.3,
      height: 0.2,
    );
    canvas.drawRect(bracketRect, bracketPaint);

    final boltPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-0.08, -0.15), 0.025, boltPaint);
    canvas.drawCircle(const Offset(0.08, -0.15), 0.025, boltPaint);
  }

  void _renderFrontRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // 1. Base vibrant orange rim arc (bottom half from 0 to pi)
    final frontRimPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

    canvas.drawArc(
      rimRect,
      0,
      math.pi,
      false,
      frontRimPaint,
    );

    // 2. Specular metallic highlight along the top crest
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFAB91)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.03;

    final highlightRect = Rect.fromCenter(
      center: const Offset(0, -0.015),
      width: hoopWidth - 0.06,
      height: hoopDepth,
    );

    canvas.drawArc(
      highlightRect,
      0.15,
      math.pi - 0.3,
      false,
      highlightPaint,
    );

    // 3. Circular rim tips at the left and right collision pivots
    final pivotPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(-hoopWidth / 2, 0), 0.045, pivotPaint);
    canvas.drawCircle(Offset(hoopWidth / 2, 0), 0.045, pivotPaint);
  }

  void _renderFrontNet(Canvas canvas) {
    final netCordPaint = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035;

    final knotPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    const cordCount = 8;
    const netDepth = 0.9;
    const bottomWidthRatio = 0.55;

    final topPoints = <Offset>[];
    final bottomPoints = <Offset>[];

    // Compute attachment loops along front rim arc (0 to pi)
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
      final angle = t * math.pi;
      final x = (hoopWidth / 2) * math.cos(angle);
      final y = (hoopDepth / 2) * math.sin(angle);
      topPoints.add(Offset(x, y));

      final bx = x * bottomWidthRatio;
      final by = netDepth;
      bottomPoints.add(Offset(bx, by));
    }

    // 1. Draw cross-hatched cord mesh
    for (int i = 0; i < cordCount; i++) {
      canvas.drawLine(topPoints[i], bottomPoints[i + 1], netCordPaint);
      canvas.drawLine(topPoints[i + 1], bottomPoints[i], netCordPaint);
    }

    // 2. Draw front horizontal loop ribs
    for (double yFrac = 0.25; yFrac <= 0.85; yFrac += 0.25) {
      final curY = netDepth * yFrac;
      final curWidth = hoopWidth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);
      final curDepth = hoopDepth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);

      final ribRect = Rect.fromCenter(
        center: Offset(0, curY),
        width: curWidth,
        height: curDepth,
      );

      canvas.drawArc(
        ribRect,
        0,
        math.pi,
        false,
        netCordPaint,
      );

      // Knots along the horizontal rib
      for (int k = 1; k < cordCount; k++) {
        final t = k / cordCount;
        final angle = t * math.pi;
        final kx = (curWidth / 2) * math.cos(angle);
        final ky = curY + (curDepth / 2) * math.sin(angle);
        canvas.drawCircle(Offset(kx, ky), 0.02, knotPaint);
      }
    }
  }
}
