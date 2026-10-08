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
    this.hoopWidth = 6.0,
    this.hoopDepth = 1.6,
  }) : super(
          position: position,
          size: Vector2(20.0, 20.0),
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
      center: const Offset(0, -0.6),
      width: 1.2,
      height: 0.8,
    );
    canvas.drawRect(bracketRect, bracketPaint);

    final boltPaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-0.35, -0.6), 0.1, boltPaint);
    canvas.drawCircle(const Offset(0.35, -0.6), 0.1, boltPaint);
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
      ..strokeWidth = 0.38;

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
      ..strokeWidth = 0.14;

    final highlightRect = Rect.fromCenter(
      center: const Offset(0, -0.06),
      width: hoopWidth - 0.2,
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

    canvas.drawCircle(Offset(-hoopWidth / 2, 0), 0.2, pivotPaint);
    canvas.drawCircle(Offset(hoopWidth / 2, 0), 0.2, pivotPaint);
  }

  void _renderFrontNet(Canvas canvas) {
    final netCordPaint = Paint()
      ..color = const Color(0xF5FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15;

    final knotPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.fill;

    const cordCount = 8;
    const netDepth = 4.0;
    const bottomWidthRatio = 0.6;

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
      // Diagonal down-right
      canvas.drawLine(topPoints[i], bottomPoints[i + 1], netCordPaint);
      // Diagonal down-left
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
        canvas.drawCircle(Offset(kx, ky), 0.08, knotPaint);
      }
    }
  }
}
