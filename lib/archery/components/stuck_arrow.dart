import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

/// Renders an arrow embedded in the target boss with damped tail quiver.
class StuckArrow {
  final double hitLocalX;
  final double hitLocalY;
  final double hitZ;
  final double pitch;
  final double yaw;
  final double penetrationDepth;

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

  // --- Cached Paints ---
  static final Paint _shaftPaint = Paint()
    ..color = const Color(0xFF2E384D)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  static final Paint _entryHolePaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  static final Paint _vanePaint = Paint()
    ..color = const Color(0xFFEF4444)
    ..style = PaintingStyle.fill;
  static final Paint _indexVanePaint = Paint()
    ..color = const Color(0xFF00FFCC)
    ..style = PaintingStyle.fill;

  static final Path _vanePath = Path();

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
    // 3D coordinates on target face
    final double entryX = hitLocalX;
    final double entryY = ArcheryK.targetCenterY + hitLocalY;
    final double entryZ = hitZ;

    // Project entry point
    if (!camera.project(entryX, entryY, entryZ)) return;
    final double sxEntry = camera.sx;
    final double syEntry = camera.sy;
    final double pxPerM = camera.pxPerMeterAt(camera.depth);

    // Calculate exposed tail position (sticking out toward archer, -Z direction)
    final double exposedLength = (ArcheryK.arrowLength - penetrationDepth).clamp(0.2, 0.75);
    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);
    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);

    final double nockX = entryX - (sinY * cosP * exposedLength) + quiverOffset;
    final double nockY = entryY - (sinP * exposedLength);
    final double nockZ = entryZ - (cosY * cosP * exposedLength);

    if (!camera.project(nockX, nockY, nockZ)) return;
    final double sxNock = camera.sx;
    final double syNock = camera.sy;

    // Small dark entry mark on boss
    canvas.drawCircle(Offset(sxEntry, syEntry), (pxPerM * 0.006).clamp(1.5, 4.0), _entryHolePaint);

    // Draw exposed carbon shaft
    final double shaftWidth = (pxPerM * ArcheryK.arrowShaftRadius * 2.0).clamp(1.5, 4.5);
    _shaftPaint.strokeWidth = shaftWidth;
    canvas.drawLine(Offset(sxEntry, syEntry), Offset(sxNock, syNock), _shaftPaint);

    // Draw fletchings near nock
    final double dx = sxEntry - sxNock;
    final double dy = syEntry - syNock;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 3.0) return;

    final double ux = dx / len;
    final double uy = dy / len;
    final double perpX = -uy;
    final double perpY = ux;

    final double vaneLen = (pxPerM * 0.07).clamp(4.0, 18.0);
    final double vaneHeight = (pxPerM * 0.015).clamp(2.0, 7.0);

    // Upper vane
    _vanePath.reset();
    _vanePath.moveTo(sxNock, syNock);
    _vanePath.lineTo(
      sxNock + ux * (vaneLen * 0.7) + perpX * vaneHeight,
      syNock + uy * (vaneLen * 0.7) + perpY * vaneHeight,
    );
    _vanePath.lineTo(sxNock + ux * vaneLen, syNock + uy * vaneLen);
    _vanePath.close();
    canvas.drawPath(_vanePath, _vanePaint);

    // Lower vane
    _vanePath.reset();
    _vanePath.moveTo(sxNock, syNock);
    _vanePath.lineTo(
      sxNock + ux * (vaneLen * 0.7) - perpX * vaneHeight,
      syNock + uy * (vaneLen * 0.7) - perpY * vaneHeight,
    );
    _vanePath.lineTo(sxNock + ux * vaneLen, syNock + uy * vaneLen);
    _vanePath.close();
    canvas.drawPath(_vanePath, _indexVanePaint);
  }
}
