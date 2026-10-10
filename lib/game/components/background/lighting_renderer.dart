import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders subtle arena floodlight and vignette shadows, creating
/// light focus on the hoop and court key while gently shading outer corners.
class LightingRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    final width = geom.screenWidth;
    final height = geom.screenHeight;
    final fullRect = Rect.fromLTWH(0, 0, width, height);

    // 1. Soft Overhead Floodlight centered at the hoop (X=center, Y=25% height)
    final spotlightCenter = Offset(width / 2.0, height * 0.25);
    final spotlightRadius = height * 0.80;

    final spotlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (spotlightCenter.dx / width) * 2 - 1,
          (spotlightCenter.dy / height) * 2 - 1,
        ),
        radius: spotlightRadius / width,
        colors: const [
          Color(0x00000000), // Pure crisp clarity on hoop & key
          Color(0x08000000), // Soft ambient drop
          Color(0x22000000), // Medium vignette
          Color(0x48000000), // Arena shadow in extreme corners
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, spotlightPaint);

    // 2. Corner Vignette Gradient
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const [
          Colors.transparent,
          Color(0x15000000),
          Color(0x35000000),
        ],
        stops: const [0.70, 0.88, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, vignettePaint);
  }
}
