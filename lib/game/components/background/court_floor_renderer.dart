import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Renders the authentic GamePigeon hardwood court floor:
/// - Longitudinal maple floorboards radiating from the vanishing point
/// - Foreshortened transverse plank seams based on true 3D camera depth
/// - Terracotta/Crimson painted key trapezoid in unified 3D perspective
/// - Regulation restricted area arc centered directly under the hoop
/// - Regulation free-throw circle (solid front arc, dashed rear arc)
/// - 3-Point arc framing the perimeter court
/// - Signature vertical pole floor reflection streak
/// - Polished lacquer high-gloss floor varnish sheen
class CourtFloorRenderer {
  void render(Canvas canvas, RoomGeometry geom) {
    final floorRect = geom.floorRect;
    final width = geom.screenWidth;
    final height = geom.screenHeight;

    canvas.save();
    canvas.clipRect(floorRect);

    // 1. Maple Hardwood Court Base
    final maplePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFB57A3D), // Deeper maple at baseline
          Color(0xFFD89C5D), // Vibrant golden maple center
          Color(0xFFC98E50), // Warm foreground maple
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, maplePaint);

    // 2. Longitudinal Floorboards Radiating from Vanishing Point
    final plankPaint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 0.8;

    const plankSpacingAtBottom = 22.0;
    for (double bx = -width * 0.3; bx <= width * 1.3; bx += plankSpacingAtBottom) {
      final topPt = geom.vanishingPoint;
      final botPt = Offset(bx, height);
      canvas.drawLine(topPt, botPt, plankPaint);
    }

    // 3. Transverse Plank Seams (Exact 3D Camera Depth Steps)
    final transversePaint = Paint()
      ..color = const Color(0x10000000)
      ..strokeWidth = 0.8;

    for (double z = 0.4; z <= RoomGeometry.wallZ; z += 0.5) {
      final y = geom.projectFloor(0.0, z).dy;
      if (y >= geom.wallBaseY && y <= height) {
        canvas.drawLine(Offset(0, y), Offset(width, y), transversePaint);
      }
    }

    // 4. Terracotta/Crimson Painted Key Trapezoid
    _renderKeyTrapezoid(canvas, geom);

    // 5. Regulation Court Markings (Restricted Area, Free-Throw, 3-Point)
    _renderCourtMarkings(canvas, geom);

    // 6. Signature Vertical Pole Floor Reflection Streak
    _renderPoleFloorReflection(canvas, geom);

    // 7. Polished Lacquer Floor Sheen Overlay
    final floorGlossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x24FFFFFF),
          Color(0x0CFFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorGlossPaint);

    canvas.restore();
  }

  void _renderKeyTrapezoid(Canvas canvas, RoomGeometry geom) {
    // 3D coordinates for the painted key:
    // Baseline at wallZ (5.25m), width 3.6m (X in [-1.8, 1.8])
    // Free-throw line at 1.30m, width 4.8m (X in [-2.4, 2.4])
    const baselineZ = RoomGeometry.wallZ;
    const freethrowZ = 1.30;
    const baselineHalfWidth = 1.85;
    const freethrowHalfWidth = 2.40;

    final pTopLeft = geom.projectFloor(-baselineHalfWidth, baselineZ);
    final pTopRight = geom.projectFloor(baselineHalfWidth, baselineZ);
    final pBottomRight = geom.projectFloor(freethrowHalfWidth, freethrowZ);
    final pBottomLeft = geom.projectFloor(-freethrowHalfWidth, freethrowZ);

    // Trapezoid body
    final keyPath = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();

    // Semicircular front key extension covering the free throw area
    // Center at (0, 0, freethrowZ), radius 1.8m
    final frontArcPoints = <Offset>[];
    const arcRadius = 1.80;
    const steps = 32;
    for (int i = 0; i <= steps; i++) {
      final theta = math.pi * i / steps; // 0 to pi (facing player)
      final x = arcRadius * math.cos(theta);
      final z = freethrowZ - arcRadius * math.sin(theta);
      frontArcPoints.add(geom.projectFloor(x, z));
    }

    final fullKeyPath = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy);

    for (final pt in frontArcPoints) {
      fullKeyPath.lineTo(pt.dx, pt.dy);
    }

    fullKeyPath
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();

    final keyRect = fullKeyPath.getBounds();
    final keyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF8B1A1E), // Deep collegiate red at baseline
          Color(0xFFA8262C), // Rich vibrant terracotta red center
          Color(0xFF961D22), // Warm foreground red
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(keyRect);

    canvas.drawPath(fullKeyPath, keyPaint);

    // Clean regulation white court lines along key perimeter
    final keyBorderPaint = Paint()
      ..color = const Color(0xE0FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(keyPath, keyBorderPaint);
  }

  void _renderCourtMarkings(Canvas canvas, RoomGeometry geom) {
    final linePaint = Paint()
      ..color = const Color(0xE8FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final dashedPaint = Paint()
      ..color = const Color(0x95FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    // 1. Restricted Area Arc (Centered under hoop at Z=4.50m, Radius=1.15m)
    const hoopZ = 4.50;
    const baselineZ = RoomGeometry.wallZ;
    const restrictedRadius = 1.15;

    final restrictedPath = Path();
    // Straight left side from baseline to arc tangent
    final restLeftBase = geom.projectFloor(-restrictedRadius, baselineZ);
    final restLeftArc = geom.projectFloor(-restrictedRadius, hoopZ);
    restrictedPath.moveTo(restLeftBase.dx, restLeftBase.dy);
    restrictedPath.lineTo(restLeftArc.dx, restLeftArc.dy);

    // Front arc facing player (z decreases from 4.50 to 3.35m)
    const arcSteps = 24;
    for (int i = 0; i <= arcSteps; i++) {
      final theta = math.pi * i / arcSteps;
      final x = -restrictedRadius * math.cos(theta);
      final z = hoopZ - restrictedRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      restrictedPath.lineTo(pt.dx, pt.dy);
    }

    // Straight right side from arc tangent back to baseline
    final restRightBase = geom.projectFloor(restrictedRadius, baselineZ);
    restrictedPath.lineTo(restRightBase.dx, restRightBase.dy);

    canvas.drawPath(restrictedPath, linePaint);

    // 2. Free-Throw Line across the key at Z=1.30m
    const freethrowZ = 1.30;
    const freethrowHalfWidth = 2.40;
    final ftLeft = geom.projectFloor(-freethrowHalfWidth, freethrowZ);
    final ftRight = geom.projectFloor(freethrowHalfWidth, freethrowZ);
    canvas.drawLine(ftLeft, ftRight, linePaint);

    // 3. Free-Throw Circle (Centered at (0, 0, 1.30m), Radius=1.80m)
    const ftRadius = 1.80;

    // Solid front half (facing player, z < 1.30m)
    final frontCirclePath = Path();
    for (int i = 0; i <= arcSteps; i++) {
      final theta = math.pi * i / arcSteps;
      final x = ftRadius * math.cos(theta);
      final z = freethrowZ - ftRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      if (i == 0) {
        frontCirclePath.moveTo(pt.dx, pt.dy);
      } else {
        frontCirclePath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(frontCirclePath, linePaint);

    // Dashed rear half (receding toward hoop, z > 1.30m)
    for (int i = 0; i < 18; i += 2) {
      final t1 = math.pi * i / 18;
      final t2 = math.pi * (i + 1) / 18;
      final x1 = ftRadius * math.cos(t1);
      final z1 = freethrowZ + ftRadius * math.sin(t1);
      final x2 = ftRadius * math.cos(t2);
      final z2 = freethrowZ + ftRadius * math.sin(t2);

      final p1 = geom.projectFloor(x1, z1);
      final p2 = geom.projectFloor(x2, z2);
      canvas.drawLine(p1, p2, dashedPaint);
    }

    // 4. 3-Point Arc Framing the Court (Center at (0, 0, 4.50m), Radius=4.20m)
    final threePointPath = Path();
    const threePointRadius = 4.20;
    const threeSteps = 36;
    bool first = true;
    for (int i = 0; i <= threeSteps; i++) {
      final theta = 0.12 * math.pi + (0.76 * math.pi) * (i / threeSteps);
      final x = threePointRadius * math.cos(theta);
      final z = hoopZ - threePointRadius * math.sin(theta);
      final pt = geom.projectFloor(x, z);
      if (first) {
        threePointPath.moveTo(pt.dx, pt.dy);
        first = false;
      } else {
        threePointPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(threePointPath, linePaint);
  }

  void _renderPoleFloorReflection(Canvas canvas, RoomGeometry geom) {
    // GamePigeon signature glossy white reflection streak running straight down
    // from the base of the pole (X = 0, Z = 4.85m) across the court floor.
    final poleFloorPt = geom.projectFloor(0.0, 4.85);
    final startY = poleFloorPt.dy;
    final endY = geom.screenHeight;
    final centerX = geom.screenWidth / 2.0;

    // Single clean center specular reflection line directly beneath the pole
    const coreWidth = 6.0;
    final coreRect = Rect.fromLTRB(
      centerX - coreWidth / 2,
      startY,
      centerX + coreWidth / 2,
      endY,
    );
    final corePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x95FFFFFF), // Crisp specular white reflection core directly under pole
          Color(0x50FFFFFF), // Midtone fade along the key
          Color(0x15FFFFFF), // Soft fade into foreground
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.65, 1.0],
      ).createShader(coreRect);
    canvas.drawRect(coreRect, corePaint);
  }
}
