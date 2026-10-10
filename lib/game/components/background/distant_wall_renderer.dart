import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the authentic GamePigeon exposed red clay brick gym back wall:
/// - Full-height running-bond clay brickwork with sandy charcoal mortar recesses
/// - Rich terracotta, burnt sienna, rust, and crimson color modulation
/// - Distinct micro-bevel highlights and shadow edges on every brick
/// - Sleek dark hardwood baseboard trim meeting the court floor
/// - Atmospheric distance lighting & depth gradient
class DistantWallRenderer {
  // Rich exposed clay brick palette sampled from GamePigeon
  static const List<Color> _brickColors = [
    Color(0xFFA63C27), // Classic terracotta
    Color(0xFF8F2F1E), // Burnt sienna
    Color(0xFFBD4A32), // Vibrant rust
    Color(0xFF7A2517), // Deep aged crimson
    Color(0xFF9D3925), // Rich warm clay
    Color(0xFFB1432D), // Amber brick
    Color(0xFF882C1B), // Dark roast terracotta
    Color(0xFFC05239), // Soft sunlit rust
  ];

  void render(Canvas canvas, RoomGeometry geom) {
    final wallRect = geom.backWallRect;

    canvas.save();
    canvas.clipRect(wallRect);

    // 1. Sandy dark charcoal mortar bed
    final mortarPaint = Paint()..color = const Color(0xFF3B322B);
    canvas.drawRect(wallRect, mortarPaint);

    // 2. Running-Bond Exposed Clay Bricks (Calibrated to GamePigeon visual scale)
    const brickWidth = 38.0;
    const brickHeight = 15.0;
    const mortarGap = 2.2;
    const stepX = brickWidth + mortarGap;
    const stepY = brickHeight + mortarGap;

    final brickPaint = Paint()..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.8;
    final shadowPaint = Paint()
      ..color = const Color(0x3E000000)
      ..strokeWidth = 0.8;

    int row = 0;
    for (double y = wallRect.top - (brickHeight * 0.5); y < wallRect.bottom; y += stepY) {
      final isOdd = row % 2 == 1;
      final startX = isOdd ? wallRect.left - brickWidth / 2 : wallRect.left;
      int col = 0;

      for (double x = startX; x < wallRect.right + brickWidth; x += stepX) {
        // High-entropy pseudo-random hash to prevent repeating diagonal patterns
        final hash = ((row * 37) ^ (col * 19) ^ 0x5A) % _brickColors.length;
        brickPaint.color = _brickColors[hash];

        final bRect = Rect.fromLTWH(
          x,
          y,
          brickWidth,
          math.min(brickHeight, wallRect.bottom - y),
        );

        if (bRect.bottom > wallRect.top && bRect.top < wallRect.bottom) {
          final rRect = RRect.fromRectAndRadius(bRect, const Radius.circular(1.2));
          canvas.drawRRect(rRect, brickPaint);

          // Top & Left subtle catch-light highlight
          canvas.drawLine(
            Offset(bRect.left + 0.8, bRect.top + 0.8),
            Offset(bRect.right - 0.8, bRect.top + 0.8),
            highlightPaint,
          );
          canvas.drawLine(
            Offset(bRect.left + 0.8, bRect.top + 0.8),
            Offset(bRect.left + 0.8, bRect.bottom - 0.8),
            highlightPaint,
          );

          // Bottom & Right drop shadow into mortar
          canvas.drawLine(
            Offset(bRect.left + 0.8, bRect.bottom - 0.8),
            Offset(bRect.right - 0.8, bRect.bottom - 0.8),
            shadowPaint,
          );
          canvas.drawLine(
            Offset(bRect.right - 0.8, bRect.top + 0.8),
            Offset(bRect.right - 0.8, bRect.bottom - 0.8),
            shadowPaint,
          );
        }

        col++;
      }
      row++;
    }

    // 3. Dark Hardwood / Rubber Baseboard Trim at Baseline Joint
    const baseboardHeight = 5.0;
    final baseboardRect = Rect.fromLTWH(
      wallRect.left,
      wallRect.bottom - baseboardHeight,
      wallRect.width,
      baseboardHeight,
    );
    final baseboardPaint = Paint()..color = const Color(0xFF18120C);
    canvas.drawRect(baseboardRect, baseboardPaint);

    // Crisp highlight bevel along top edge of baseboard
    canvas.drawLine(
      Offset(wallRect.left, wallRect.bottom - baseboardHeight),
      Offset(wallRect.right, wallRect.bottom - baseboardHeight),
      Paint()
        ..color = const Color(0x35FFFFFF)
        ..strokeWidth = 1.0,
    );

    // 4. Atmospheric Gym Lighting Vignette on Wall
    // Centers warmth around hoop, subtly shading top and corners
    final wallLightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 1.1,
        colors: const [
          Color(0x00000000), // Pure crisp brick in center
          Color(0x12000000), // Gentle shading
          Color(0x38000000), // Rich moody vignette near borders
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, wallLightPaint);

    canvas.restore();
  }
}
