import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders the GamePigeon scooped-shield backboard, 3D cylindrical pole,
/// wall drop shadows, rear rim arc, and back net mesh.
/// Configured with priority = 1 so it renders behind the basketball (priority = 2).
class BackboardVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  BackboardVisual({
    required Vector2 position,
    this.hoopWidth = 1.4,
    this.hoopDepth = 0.35,
  }) : super(
          position: position,
          size: Vector2(6.0, 20.0),
          anchor: Anchor.center,
          priority: 1,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);

    _renderWallDropShadow(canvas);
    _renderCylindricalPole(canvas);
    _renderScoopedBackboard(canvas);
    _renderRearRim(canvas);
    _renderRearNet(canvas);

    canvas.restore();
  }

  void _renderWallDropShadow(Canvas canvas) {
    // Soft blurred ambient drop shadow cast onto the brick wall behind the backboard
    final shadowPaint = Paint()
      ..color = const Color(0x60000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final shadowPath = _buildBackboardPath(2.8, 1.9, const Offset(0.08, -0.92));
    canvas.drawPath(shadowPath, shadowPaint);

    // Pole drop shadow on wall
    final poleShadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(
      const Rect.fromLTWH(0.12, -1.8, 0.16, 16.0),
      poleShadowPaint,
    );
  }

  void _renderCylindricalPole(Canvas canvas) {
    const poleWidth = 0.20;
    const poleTopY = -1.8;
    const poleBottomY = 14.5; // Extends down to the court floor

    final poleRect = Rect.fromLTWH(
      -poleWidth / 2,
      poleTopY,
      poleWidth,
      poleBottomY - poleTopY,
    );

    // 3D cylindrical specular lighting across the pole
    final polePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF94A3B8), // Left shadow edge
          Color(0xFFE2E8F0),
          Color(0xFFFFFFFF), // Bright specular highlight along center
          Color(0xFFCBD5E1), // Right shadow edge
        ],
        stops: [0.0, 0.25, 0.55, 1.0],
      ).createShader(poleRect);

    canvas.drawRect(poleRect, polePaint);
  }

  void _renderScoopedBackboard(Canvas canvas) {
    const boardWidth = 2.8;
    const boardHeight = 1.9;
    const boardCenter = Offset(0, -1.02);

    final outerPath = _buildBackboardPath(boardWidth, boardHeight, boardCenter);
    final innerPath = _buildBackboardPath(boardWidth * 0.90, boardHeight * 0.90, boardCenter);

    // 1. Glossy white backboard face plate
    final facePaint = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerPath, facePaint);

    // Subtle gloss gradient sheen across backboard
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0x25FFFFFF),
          Colors.transparent,
          const Color(0x10000000),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: boardCenter,
          width: boardWidth,
          height: boardHeight,
        ),
      );
    canvas.drawPath(outerPath, sheenPaint);

    // 2. Outer bold red contour line
    final outerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.08;
    canvas.drawPath(outerPath, outerRedPaint);

    // 3. Inner parallel red accent line (signature GamePigeon double border)
    final innerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.035;
    canvas.drawPath(innerPath, innerRedPaint);

    // 4. Regulation target rectangle directly above the rim
    final targetRect = Rect.fromCenter(
      center: const Offset(0, -0.65),
      width: 1.0,
      height: 0.75,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    canvas.drawRect(targetRect, targetPaint);
  }

  Path _buildBackboardPath(double w, double h, Offset center) {
    final path = Path();
    final hw = w / 2;
    final hh = h / 2;

    // Symmetric scooped-shield fan contour
    path.moveTo(center.dx, center.dy - hh);
    // Top-right shoulder notch
    path.lineTo(center.dx + hw * 0.40, center.dy - hh);
    path.quadraticBezierTo(
      center.dx + hw * 0.65,
      center.dy - hh * 0.95,
      center.dx + hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.75,
      center.dy - hh * 0.60,
      center.dx + hw,
      center.dy - hh * 0.48,
    );
    // Right side curve down to lower corner
    path.quadraticBezierTo(
      center.dx + hw * 1.02,
      center.dy + hh * 0.05,
      center.dx + hw * 0.90,
      center.dy + hh * 0.65,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.82,
      center.dy + hh,
      center.dx + hw * 0.55,
      center.dy + hh,
    );
    // Bottom edge to bottom-left corner
    path.lineTo(center.dx - hw * 0.55, center.dy + hh);
    path.quadraticBezierTo(
      center.dx - hw * 0.82,
      center.dy + hh,
      center.dx - hw * 0.90,
      center.dy + hh * 0.65,
    );
    // Left side curve up to shoulder
    path.quadraticBezierTo(
      center.dx - hw * 1.02,
      center.dy + hh * 0.05,
      center.dx - hw,
      center.dy - hh * 0.48,
    );
    // Top-left shoulder notch
    path.quadraticBezierTo(
      center.dx - hw * 0.75,
      center.dy - hh * 0.60,
      center.dx - hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx - hw * 0.65,
      center.dy - hh * 0.95,
      center.dx - hw * 0.40,
      center.dy - hh,
    );
    path.close();

    return path;
  }

  void _renderRearRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // Top half of rim ellipse (from pi to 2*pi): curves upwards/away
    final rearRimPaint = Paint()
      ..color = const Color(0xFFC2410C) // Shaded burnt orange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

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
      ..color = const Color(0x5094A3B8) // Translucent rear cords
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025;

    const cordCount = 7;
    const netDepth = 0.9;
    const bottomWidthRatio = 0.55;

    // Draw rear vertical cords tapering downwards
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
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

    // Rear horizontal ribs
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
