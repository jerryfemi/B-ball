import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders volumetric arena floodlight and vignette shadows, creating
/// realistic light containment and pushing peripheral room corners into deep shadow.
class LightingRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    final width = geom.screenWidth;
    final height = geom.screenHeight;
    final fullRect = Rect.fromLTWH(0, 0, width, height);

    // 1. Volumetric Overhead Arena Floodlight
    // Centered above the hoop area (approx 22% down, center X)
    final spotlightCenter = Offset(width / 2, height * 0.22);
    final spotlightRadius = height * 0.75;

    final spotlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (spotlightCenter.dx / width) * 2 - 1,
          (spotlightCenter.dy / height) * 2 - 1,
        ),
        radius: spotlightRadius / width,
        colors: const [
          Color(0x00000000), // Pure brightness on hoop & key
          Color(0x10050A14), // Subtle ambient drop
          Color(0x40050A14), // Medium shadow
          Color(0x75050A14), // Deep arena shadow in outer corners
        ],
        stops: const [0.0, 0.40, 0.75, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, spotlightPaint);

    // 2. Corner Vignette Gradients (Darkens extreme left/right and ceiling corners)
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const [
          Colors.transparent,
          Color(0x20000000),
          Color(0x60000000),
        ],
        stops: const [0.65, 0.85, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, vignettePaint);
  }
}
