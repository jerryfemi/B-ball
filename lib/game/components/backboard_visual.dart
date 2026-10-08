import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders the backboard, mounting pole, rear rim arc, and back net mesh.
/// Configured with priority = 1 so it renders behind the basketball (priority = 2).
class BackboardVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  BackboardVisual({
    required Vector2 position,
    this.hoopWidth = 6.0,
    this.hoopDepth = 1.6,
  }) : super(
          position: position,
          size: Vector2(20.0, 20.0),
          anchor: Anchor.center,
          priority: 1,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);

    _renderMountingPole(canvas);
    _renderBackboard(canvas);
    _renderRearRim(canvas);
    _renderRearNet(canvas);

    canvas.restore();
  }

  void _renderMountingPole(Canvas canvas) {
    final polePaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    // Heavy-duty steel arm behind the backboard
    final poleRect = Rect.fromLTWH(-0.5, -9.0, 1.0, 6.0);
    canvas.drawRect(poleRect, polePaint);
  }

  void _renderBackboard(Canvas canvas) {
    const boardWidth = 13.0;
    const boardHeight = 8.0;
    final boardCenter = const Offset(0, -4.2);

    final boardRect = Rect.fromCenter(
      center: boardCenter,
      width: boardWidth,
      height: boardHeight,
    );
    final boardRRect = RRect.fromRectAndRadius(boardRect, const Radius.circular(0.4));

    // 1. Backboard glass/acrylic background
    final glassPaint = Paint()
      ..color = const Color(0xF5FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boardRRect, glassPaint);

    // 2. Outer dark border
    final borderPaint = Paint()
      ..color = const Color(0xFF102027)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25;
    canvas.drawRRect(boardRRect, borderPaint);

    // 3. Outer red perimeter line
    final outerRedRect = Rect.fromCenter(
      center: boardCenter,
      width: boardWidth - 0.6,
      height: boardHeight - 0.6,
    );
    final outerRedRRect = RRect.fromRectAndRadius(outerRedRect, const Radius.circular(0.3));
    final outerRedPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25;
    canvas.drawRRect(outerRedRRect, outerRedPaint);

    // 4. Inner target square (regulation red box above rim)
    final targetRect = Rect.fromCenter(
      center: const Offset(0, -2.6),
      width: 4.8,
      height: 3.6,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;
    canvas.drawRect(targetRect, targetPaint);
  }

  void _renderRearRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // Top half of rim ellipse (from pi to 2*pi): curves upwards/away
    final rearRimPaint = Paint()
      ..color = const Color(0xFFBF360C) // Shaded burnt orange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.35;

    canvas.drawArc(
      rimRect,
      math.pi,
      math.pi,
      false,
      rearRimPaint,
    );
  }

  void _renderRearNet(Canvas canvas) {
    final rearNetPaint = Paint()
      ..color = const Color(0x4490A4AE) // Translucent rear cords
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;

    const cordCount = 7;
    const netDepth = 4.0;
    const bottomWidthRatio = 0.6;

    // Draw rear vertical cords tapering downwards
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
      // Elliptical top points along back rim
      final angle = math.pi + t * math.pi;
      final topX = (hoopWidth / 2) * math.cos(angle);
      final topY = (hoopDepth / 2) * math.sin(angle);

      final bottomX = topX * bottomWidthRatio;
      final bottomY = netDepth;

      canvas.drawLine(
        Offset(topX, topY),
        Offset(bottomX, bottomY),
        rearNetPaint,
      );
    }

    // Rear horizontal loop ribs
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
        math.pi,
        math.pi,
        false,
        rearNetPaint,
      );
    }
  }
}
