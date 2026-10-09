import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the overhead industrial gymnasium ceiling, receding steel trusses,
/// cross-beams, and high-bay arena floodlight fixtures.
class CeilingRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    final ceilingPath = Path()
      ..moveTo(0, 0)
      ..lineTo(geom.screenWidth, 0)
      ..lineTo(geom.backWallRect.right, geom.backWallRect.top)
      ..lineTo(geom.backWallRect.left, geom.backWallRect.top)
      ..close();

    // 1. Dark arena ceiling backdrop gradient
    final ceilingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A0F1D), // Pitch dark arena ceiling at top
          Color(0xFF131D31), // Deep navy/slate near back wall
          Color(0xFF1E293B), // Soft ambient rim at junction
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, geom.screenWidth, geom.backWallRect.top));

    canvas.drawPath(ceilingPath, ceilingPaint);

    // 2. Perspective Industrial Steel Girders / Rafters
    final trussPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final highlightPaint = Paint()
      ..color = const Color(0x3094A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Radiating longitudinal trusses from vanishing point through ceiling
    final trussXPositions = [
      0.0,
      geom.screenWidth * 0.18,
      geom.screenWidth * 0.36,
      geom.screenWidth * 0.50,
      geom.screenWidth * 0.64,
      geom.screenWidth * 0.82,
      geom.screenWidth,
    ];

    for (final topX in trussXPositions) {
      final topPt = Offset(topX, 0);
      // Find intersection with back wall top line
      // Parametric line from VP through topPt:
      final dx = topPt.dx - geom.vanishingPoint.dx;
      final dy = topPt.dy - geom.vanishingPoint.dy;
      if (dy.abs() > 0.001) {
        final t = (geom.backWallRect.top - geom.vanishingPoint.dy) / dy;
        final backPt = Offset(geom.vanishingPoint.dx + dx * t, geom.backWallRect.top);

        canvas.drawLine(topPt, backPt, trussPaint);
        canvas.drawLine(
          Offset(topPt.dx + 1.0, topPt.dy),
          Offset(backPt.dx + 1.0, backPt.dy),
          highlightPaint,
        );
      }
    }

    // Transverse cross-beams across ceiling (foreshortened perspective spacing)
    for (double f in [0.25, 0.55, 0.82]) {
      final y = geom.backWallRect.top * f;
      // Interpolate left and right boundaries of ceiling at this y
      final t = y / geom.backWallRect.top;
      final leftX = (1.0 - t) * 0.0 + t * geom.backWallRect.left;
      final rightX = (1.0 - t) * geom.screenWidth + t * geom.backWallRect.right;

      canvas.drawLine(
        Offset(leftX, y),
        Offset(rightX, y),
        Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 3.5,
      );
      canvas.drawLine(
        Offset(leftX, y - 1.0),
        Offset(rightX, y - 1.0),
        Paint()
          ..color = const Color(0x4064748B)
          ..strokeWidth = 1.0,
      );
    }

    // 3. Overhead High-Bay Arena Floodlight Fixtures
    _renderHighBayLights(canvas, geom);
  }

  void _renderHighBayLights(Canvas canvas, RoomGeometry geom) {
    final lightPositions = [
      Offset(geom.screenWidth * 0.28, geom.backWallRect.top * 0.45),
      Offset(geom.screenWidth * 0.72, geom.backWallRect.top * 0.45),
    ];

    for (final pos in lightPositions) {
      // Light housing bell
      final bellPath = Path()
        ..moveTo(pos.dx - 12, pos.dy)
        ..lineTo(pos.dx + 12, pos.dy)
        ..lineTo(pos.dx + 6, pos.dy - 8)
        ..lineTo(pos.dx - 6, pos.dy - 8)
        ..close();

      canvas.drawPath(
        bellPath,
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.fill,
      );

      // Hanging conduit wire
      canvas.drawLine(
        Offset(pos.dx, 0),
        Offset(pos.dx, pos.dy - 8),
        Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 1.2,
      );

      // Glowing lens
      canvas.drawOval(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy + 1), width: 22, height: 4),
        Paint()
          ..color = const Color(0xFFFFFBEB)
          ..style = PaintingStyle.fill,
      );

      // Soft ambient light corona / flare
      canvas.drawCircle(
        Offset(pos.dx, pos.dy + 4),
        18,
        Paint()
          ..color = const Color(0x18FDE047)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }
}
