import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the left and right perspective gymnasium walls, complete with
/// architectural concrete pillars, receding acoustic panels, and lower gym padding.
class SideWallsRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    _renderLeftWall(canvas, geom);
    _renderRightWall(canvas, geom);
  }

  void _renderLeftWall(Canvas canvas, RoomGeometry geom) {
    final leftWallPath = Path()
      ..moveTo(0, 0)
      ..lineTo(geom.backWallRect.left, geom.backWallRect.top)
      ..lineTo(geom.backWallRect.left, geom.horizonY)
      ..lineTo(0, geom.horizonY)
      ..close();

    // 1. Perspective wall gradient (darker near camera corner, catching ambient light toward center)
    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF0F172A), // Deep corner shadow
          Color(0xFF1E293B), // Mid slate
          Color(0xFF283548), // Near back wall corner
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTRB(0, 0, geom.backWallRect.left, geom.horizonY));

    canvas.drawPath(leftWallPath, wallPaint);

    // 2. Converging horizontal acoustic panel lines (receding towards VP)
    final seamPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.0;

    for (double f = 0.2; f <= 0.8; f += 0.2) {
      final backY = geom.backWallRect.top + (geom.horizonY - geom.backWallRect.top) * f;
      // Project line to left screen edge
      final dy = backY - geom.vanishingPoint.dy;
      final dx = geom.backWallRect.left - geom.vanishingPoint.dx;
      final slope = dy / dx;
      final leftY = geom.vanishingPoint.dy + slope * (0.0 - geom.vanishingPoint.dx);

      canvas.drawLine(Offset(0, leftY), Offset(geom.backWallRect.left, backY), seamPaint);
    }

    // 3. Vertical Architectural Structural Pillars
    for (double t in [0.35, 0.70]) {
      final topX = geom.backWallRect.left * t;
      final topY = (1.0 - t) * 0.0 + t * geom.backWallRect.top;
      final botY = geom.horizonY;

      // Pillar body
      final pillarRect = Rect.fromLTRB(topX - 4, topY, topX + 4, botY);
      canvas.drawRect(
        pillarRect,
        Paint()..color = const Color(0xFF192333),
      );
      // Right edge highlight (facing arena center)
      canvas.drawLine(
        Offset(topX + 4, topY),
        Offset(topX + 4, botY),
        Paint()
          ..color = const Color(0x3064748B)
          ..strokeWidth = 1.0,
      );
    }

    // 4. Lower protective wall padding continuation
    final padTopBackY = geom.horizonY - (geom.backWallRect.height * 0.32);
    final padTopLeftY = geom.horizonY - (geom.backWallRect.height * 0.48);

    final padPath = Path()
      ..moveTo(0, padTopLeftY)
      ..lineTo(geom.backWallRect.left, padTopBackY)
      ..lineTo(geom.backWallRect.left, geom.horizonY - 3)
      ..lineTo(0, geom.horizonY - 3)
      ..close();

    canvas.drawPath(
      padPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ).createShader(Rect.fromLTRB(0, padTopLeftY, geom.backWallRect.left, geom.horizonY)),
    );

    // Subtle golden collegiate trim on padding top
    canvas.drawLine(
      Offset(0, padTopLeftY),
      Offset(geom.backWallRect.left, padTopBackY),
      Paint()
        ..color = const Color(0x60FACC15)
        ..strokeWidth = 1.5,
    );
  }

  void _renderRightWall(Canvas canvas, RoomGeometry geom) {
    final rightWallPath = Path()
      ..moveTo(geom.screenWidth, 0)
      ..lineTo(geom.backWallRect.right, geom.backWallRect.top)
      ..lineTo(geom.backWallRect.right, geom.horizonY)
      ..lineTo(geom.screenWidth, geom.horizonY)
      ..close();

    // 1. Perspective wall gradient
    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: const [
          Color(0xFF0F172A),
          Color(0xFF1E293B),
          Color(0xFF283548),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTRB(geom.backWallRect.right, 0, geom.screenWidth, geom.horizonY));

    canvas.drawPath(rightWallPath, wallPaint);

    // 2. Converging horizontal acoustic panel lines
    final seamPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.0;

    for (double f = 0.2; f <= 0.8; f += 0.2) {
      final backY = geom.backWallRect.top + (geom.horizonY - geom.backWallRect.top) * f;
      final dy = backY - geom.vanishingPoint.dy;
      final dx = geom.backWallRect.right - geom.vanishingPoint.dx;
      final slope = dy / dx;
      final rightY = geom.vanishingPoint.dy + slope * (geom.screenWidth - geom.vanishingPoint.dx);

      canvas.drawLine(Offset(geom.backWallRect.right, backY), Offset(geom.screenWidth, rightY), seamPaint);
    }

    // 3. Vertical Architectural Structural Pillars
    for (double t in [0.35, 0.70]) {
      final relX = (geom.screenWidth - geom.backWallRect.right) * t;
      final topX = geom.screenWidth - relX;
      final topY = (1.0 - t) * 0.0 + t * geom.backWallRect.top;
      final botY = geom.horizonY;

      final pillarRect = Rect.fromLTRB(topX - 4, topY, topX + 4, botY);
      canvas.drawRect(
        pillarRect,
        Paint()..color = const Color(0xFF192333),
      );
      // Left edge highlight (facing arena center)
      canvas.drawLine(
        Offset(topX - 4, topY),
        Offset(topX - 4, botY),
        Paint()
          ..color = const Color(0x3064748B)
          ..strokeWidth = 1.0,
      );
    }

    // 4. Lower protective wall padding continuation
    final padTopBackY = geom.horizonY - (geom.backWallRect.height * 0.32);
    final padTopRightY = geom.horizonY - (geom.backWallRect.height * 0.48);

    final padPath = Path()
      ..moveTo(geom.screenWidth, padTopRightY)
      ..lineTo(geom.backWallRect.right, padTopBackY)
      ..lineTo(geom.backWallRect.right, geom.horizonY - 3)
      ..lineTo(geom.screenWidth, geom.horizonY - 3)
      ..close();

    canvas.drawPath(
      padPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ).createShader(Rect.fromLTRB(geom.backWallRect.right, padTopRightY, geom.screenWidth, geom.horizonY)),
    );

    // Subtle golden collegiate trim on padding top
    canvas.drawLine(
      Offset(geom.screenWidth, padTopRightY),
      Offset(geom.backWallRect.right, padTopBackY),
      Paint()
        ..color = const Color(0x60FACC15)
        ..strokeWidth = 1.5,
    );
  }
}
