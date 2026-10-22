import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import 'arrow_renderer.dart';

/// Renders an arrow embedded in the target boss with damped tail quiver using the unified 3D arrow renderer.
class StuckArrow {
  final double hitLocalX;
  final double hitLocalY;
  final double hitZ;
  final double pitch;
  final double yaw;
  final double penetrationDepth;

  /// 1 = solid. Used to fade the opponent's replay arrows away.
  double opacity = 1.0;

  double timeSinceImpact = 0.0;
  double quiverOffset = 0.0;

  StuckArrow({
    required this.hitLocalX,
    required this.hitLocalY,
    required this.hitZ,
    required this.pitch,
    required this.yaw,
    required this.penetrationDepth,
  });

  void update(double dt) {
    if (timeSinceImpact < 0.8) {
      timeSinceImpact += dt;
      // Tail quiver damped oscillation: B * exp(-t / 0.25) * sin(2π * 18t), B = 1.5 cm
      const double b = 0.015;
      quiverOffset = b *
          math.exp(-timeSinceImpact / 0.25) *
          math.sin(2.0 * math.pi * 18.0 * timeSinceImpact);
    } else {
      quiverOffset = 0.0;
    }
  }

  void render(Canvas canvas, ArcheryCamera camera) {
    if (opacity <= 0.0) return;
    // 3D coordinates on target face
    final double entryX = hitLocalX;
    final double entryY = ArcheryK.targetCenterY + hitLocalY;
    final double entryZ = hitZ;

    // Calculate forward unit vector of the embedded arrow (+Z into the target)
    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);
    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);

    final double forwardX = sinY * cosP;
    final double forwardY = sinP;
    final double forwardZ = cosY * cosP;

    // Exposed shaft length (sticking out towards archer)
    final double exposedLength = (ArcheryK.arrowLength - penetrationDepth).clamp(0.2, ArcheryK.arrowLength);

    ArrowRenderer3D.render(
      canvas: canvas,
      camera: camera,
      tipX: entryX,
      tipY: entryY,
      tipZ: entryZ,
      forwardX: forwardX,
      forwardY: forwardY,
      forwardZ: forwardZ,
      length: exposedLength,
      roll: 0.0,
      quiverOffsetX: quiverOffset,
      drawEntryHole: true,
      opacity: opacity,
    );
  }
}
