import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the distant gymnasium back wall across the room:
/// - Fine-scale running-bond clay bricks (scaled to distant perspective)
/// - Lower protective gym wall padding in deep navy slate with collegiate accent stripe
/// - Wooden baseboard molding trim
/// - Atmospheric distance haze overlay (depth of field contrast softness)
class DistantWallRenderer {
  static const List<Color> _brickColors = [
    Color(0xFFA33B27),
    Color(0xFF8F2F1E),
    Color(0xFFB54631),
    Color(0xFF7C2617),
    Color(0xFF993724),
    Color(0xFFAB412D),
  ];

  void render(Canvas canvas, RoomGeometry geom) {
    final wallRect = geom.backWallRect;

    canvas.save();
    // Clip strictly within the distant back wall boundary
    canvas.clipRect(wallRect);

    // 1. Sandy mortar base
    final mortarPaint = Paint()..color = const Color(0xFF6B5A4D);
    canvas.drawRect(wallRect, mortarPaint);

    // 2. Fine-Scale Distant Clay Bricks (scaled down to convey 15m distance)
    const brickWidth = 22.0;
    const brickHeight = 9.0;
    const mortarGap = 1.8;
    const stepX = brickWidth + mortarGap;
    const stepY = brickHeight + mortarGap;

    final brickPaint = Paint()..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 0.6;
    final shadowPaint = Paint()
      ..color = const Color(0x28000000)
      ..strokeWidth = 0.6;

    int row = 0;
    for (double y = wallRect.top; y < wallRect.bottom; y += stepY) {
      final isOdd = row % 2 == 1;
      final startX = isOdd ? wallRect.left - brickWidth / 2 : wallRect.left;
      int col = 0;

      for (double x = startX; x < wallRect.right + brickWidth; x += stepX) {
        final colorIndex = ((row * 13) + (col * 7)) % _brickColors.length;
        brickPaint.color = _brickColors[colorIndex];

        final bRect = Rect.fromLTWH(
          x,
          y,
          brickWidth,
          math.min(brickHeight, wallRect.bottom - y),
        );
        final rRect = RRect.fromRectAndRadius(bRect, const Radius.circular(0.8));
        canvas.drawRRect(rRect, brickPaint);

        canvas.drawLine(
          Offset(bRect.left + 0.5, bRect.top + 0.5),
          Offset(bRect.right - 0.5, bRect.top + 0.5),
          highlightPaint,
        );
        canvas.drawLine(
          Offset(bRect.left + 0.5, bRect.bottom - 0.5),
          Offset(bRect.right - 0.5, bRect.bottom - 0.5),
          shadowPaint,
        );

        col++;
      }
      row++;
    }

    // 3. Lower Protective Gym Wall Padding
    _renderGymWallPads(canvas, geom);

    // 4. Wooden / Rubber Baseboard Trim
    final trimPaint = Paint()..color = const Color(0xFF140D07);
    canvas.drawRect(
      Rect.fromLTWH(wallRect.left, geom.horizonY - 3.5, wallRect.width, 3.5),
      trimPaint,
    );

    // 5. Atmospheric Distance Haze & Contrast Softening
    final hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x350F172A), // Soft dark haze at top
          Color(0x120F172A), // Clearer in center
          Color(0x400F172A), // Grounding shadow meeting floor
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, hazePaint);

    canvas.restore();
  }

  void _renderGymWallPads(Canvas canvas, RoomGeometry geom) {
    final wallRect = geom.backWallRect;
    final padHeight = wallRect.height * 0.32;
    final padTop = geom.horizonY - padHeight;
    final padBottom = geom.horizonY - 3.5;
    final padRect = Rect.fromLTRB(wallRect.left, padTop, wallRect.right, padBottom);

    // Navy slate vinyl base
    final padBasePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1E293B),
          Color(0xFF0F172A),
        ],
      ).createShader(padRect);
    canvas.drawRect(padRect, padBasePaint);

    // Vertical cushion segments
    const segmentWidth = 24.0;
    final creasePaint = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 1.2;
    final cushionHighlightPaint = Paint()
      ..color = const Color(0x15FFFFFF)
      ..strokeWidth = 1.0;

    for (double x = wallRect.left; x < wallRect.right; x += segmentWidth) {
      // Crease between cushions
      canvas.drawLine(Offset(x, padTop), Offset(x, padBottom), creasePaint);
      // Soft vertical highlight down the center of each cushion
      canvas.drawLine(
        Offset(x + segmentWidth / 2, padTop + 2),
        Offset(x + segmentWidth / 2, padBottom - 2),
        cushionHighlightPaint,
      );
    }

    // Top protective cap border with collegiate gold line
    canvas.drawLine(
      Offset(wallRect.left, padTop),
      Offset(wallRect.right, padTop),
      Paint()
        ..color = const Color(0xFFFACC15)
        ..strokeWidth = 2.0,
    );
  }
}
