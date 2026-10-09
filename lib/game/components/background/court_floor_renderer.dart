import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the perspective hardwood court floor:
/// - Longitudinal maple floorboards radiating from the vanishing point
/// - Foreshortened transverse plank seams
/// - Terracotta/Crimson painted key trapezoid in deep 1-point perspective
/// - Regulation free-throw circle markings
/// - High-gloss floor varnish reflection sheen
class CourtFloorRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    final floorRect = geom.floorRect;
    final width = geom.screenWidth;
    final height = geom.screenHeight;
    final horizonY = geom.horizonY;
    final floorHeight = floorRect.height;
    final centerX = width / 2;

    // 1. Maple Hardwood Court Base
    final maplePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFB57A3D), // Slightly deeper maple at horizon
          Color(0xFFD69A5C), // Vibrant maple center
          Color(0xFFC78B4E), // Warm foreground maple
        ],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, maplePaint);

    // 2. Longitudinal Floorboards Radiating from Vanishing Point
    final plankPaint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 0.8;

    const plankSpacingAtBottom = 22.0;
    for (double bx = -width * 0.2; bx <= width * 1.2; bx += plankSpacingAtBottom) {
      // Find start point at horizon line where the ray from VP intersects horizonY
      final topPt = Offset(
        geom.vanishingPoint.dx + (bx - geom.vanishingPoint.dx) * 0.0,
        horizonY,
      );
      final botPt = Offset(bx, height);
      canvas.drawLine(topPt, botPt, plankPaint);
    }

    // 3. Transverse Logarithmic Plank Seams
    final transversePaint = Paint()
      ..color = const Color(0x10000000)
      ..strokeWidth = 0.8;

    // Quadratic distribution for realistic distance foreshortening
    for (double t = 0.08; t <= 1.0; t += 0.07) {
      final y = horizonY + (t * t) * floorHeight;
      canvas.drawLine(Offset(0, y), Offset(width, y), transversePaint);
    }

    // 4. Terracotta/Crimson Painted Key Trapezoid
    final topKeyWidth = width * 0.48;
    final bottomKeyWidth = width * 0.94;

    final keyPath = Path()
      ..moveTo(centerX - topKeyWidth / 2, horizonY)
      ..lineTo(centerX + topKeyWidth / 2, horizonY)
      ..lineTo(centerX + bottomKeyWidth / 2, height)
      ..lineTo(centerX - bottomKeyWidth / 2, height)
      ..close();

    final keyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF7A1416), // Deeper crimson near back wall
          Color(0xFF9E1B20), // Rich collegiate terracotta red
          Color(0xFF8B161B), // Warm foreground red
        ],
      ).createShader(floorRect);
    canvas.drawPath(keyPath, keyPaint);

    final keyBorderPaint = Paint()
      ..color = const Color(0xD8FFFFFF) // Clean regulation white court lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(keyPath, keyBorderPaint);

    // 5. Free-Throw Markings
    _renderCourtMarkings(canvas, geom);

    // 6. High-Gloss Floor Sheen Overlay
    final floorGlossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x28FFFFFF),
          Color(0x08FFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorGlossPaint);
  }

  void _renderCourtMarkings(Canvas canvas, RoomGeometry geom) {
    final centerX = geom.screenWidth / 2;
    final floorHeight = geom.floorRect.height;
    final horizonY = geom.horizonY;

    // Free-throw circle arc in deep perspective
    final circleCenterY = horizonY + floorHeight * 0.42;
    final radiusX = geom.screenWidth * 0.28;
    final radiusY = floorHeight * 0.18;

    final arcRect = Rect.fromCenter(
      center: Offset(centerX, circleCenterY),
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // Solid front arc (facing player)
    final solidArcPaint = Paint()
      ..color = const Color(0xC8FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(arcRect, 0, math.pi, false, solidArcPaint);

    // Dashed back arc (receding toward basket)
    final dashedArcPaint = Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (double a = math.pi; a < 2 * math.pi; a += 0.35) {
      canvas.drawArc(arcRect, a, 0.18, false, dashedArcPaint);
    }
  }
}
