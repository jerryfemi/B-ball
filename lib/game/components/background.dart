import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Procedural sports arena background with:
/// - Sleek dark stadium wall with ambient overhead arena floodlight.
/// - Polished hardwood parquet court floor with wood plank grain, gloss sheen,
///   and regulation free-throw paint/key markings.
/// Zero external stock images needed.
class GameBackground extends Component with HasGameReference {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final width = game.size.x;
    final height = game.size.y;
    final wallHeight = height * 0.62;
    final floorHeight = height - wallHeight;

    _renderArenaWall(canvas, width, wallHeight);
    _renderCourtFloor(canvas, width, height, wallHeight, floorHeight);
  }

  void _renderArenaWall(Canvas canvas, double width, double wallHeight) {
    final wallRect = Rect.fromLTWH(0, 0, width, wallHeight);

    // 1. Deep midnight stadium gradient
    final wallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF090D16), // Dark midnight arena ceiling
          Color(0xFF131B2E), // Mid stadium wall
          Color(0xFF1E293B), // Lower arena wall
        ],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, wallPaint);

    // 2. Overhead arena floodlight cone (soft ambient spotlight focused on hoop)
    final spotlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.9),
        radius: 0.9,
        colors: [
          const Color(0x35FFE082), // Warm arena beam
          const Color(0x12FFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, spotlightPaint);

    // 3. Subtle architectural vertical stadium wall slats
    final slatPaint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1.0;
    const slatSpacing = 36.0;
    for (double x = 0; x <= width; x += slatSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, wallHeight), slatPaint);
    }

    // 4. Stadium baseboard / wall trim
    final baseboardPaint = Paint()..color = const Color(0xFF0B1120);
    canvas.drawRect(
      Rect.fromLTWH(0, wallHeight - 8.0, width, 8.0),
      baseboardPaint,
    );

    final trimLinePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, wallHeight - 8.0),
      Offset(width, wallHeight - 8.0),
      trimLinePaint,
    );
  }

  void _renderCourtFloor(
    Canvas canvas,
    double width,
    double height,
    double wallHeight,
    double floorHeight,
  ) {
    final floorRect = Rect.fromLTWH(0, wallHeight, width, floorHeight);

    // 1. Rich polished maple hardwood base gradient
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFB5702F), // Darker edge near back wall
          Color(0xFFCA823B), // Golden maple court
          Color(0xFFBD742E), // Warm foreground tone
        ],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorPaint);

    // 2. Realistic hardwood parquet planks
    const plankHeight = 22.0;
    final plankSeamPaint = Paint()
      ..color = const Color(0x25000000)
      ..strokeWidth = 0.8;

    final plankToneLight = Paint()..color = const Color(0x0FFFFFFF);
    final plankToneDark = Paint()..color = const Color(0x0D000000);

    int row = 0;
    for (double y = wallHeight; y < height; y += plankHeight) {
      final curHeight = math.min(plankHeight, height - y);
      final pRect = Rect.fromLTWH(0, y, width, curHeight);

      // Alternating plank wood tones
      if (row % 2 == 0) {
        canvas.drawRect(pRect, plankToneLight);
      } else {
        canvas.drawRect(pRect, plankToneDark);
      }

      // Horizontal plank seams
      canvas.drawLine(Offset(0, y), Offset(width, y), plankSeamPaint);
      row++;
    }

    // 3. Regulation Court Markings (crisp semi-opaque ivory lines)
    _renderCourtMarkings(canvas, width, height, wallHeight);

    // 4. Semi-gloss hardwood surface reflection (subtle ambient glare)
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x25FFFFFF),
          const Color(0x08FFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, reflectionPaint);
  }

  void _renderCourtMarkings(
    Canvas canvas,
    double width,
    double height,
    double wallHeight,
  ) {
    final courtLinePaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final centerX = width / 2;
    final floorDepth = height - wallHeight;

    // Free-throw lane (key) trapezoid perspective
    final topKeyWidth = width * 0.45;
    final bottomKeyWidth = width * 0.65;
    final keyTopY = wallHeight + 10.0;
    final keyBottomY = height - 15.0;

    final keyPath = Path()
      ..moveTo(centerX - topKeyWidth / 2, keyTopY)
      ..lineTo(centerX + topKeyWidth / 2, keyTopY)
      ..lineTo(centerX + bottomKeyWidth / 2, keyBottomY)
      ..lineTo(centerX - bottomKeyWidth / 2, keyBottomY)
      ..close();

    canvas.drawPath(keyPath, courtLinePaint);

    // Free-throw circle / arc
    final circleCenterY = wallHeight + floorDepth * 0.42;
    final circleRadiusX = width * 0.22;
    final circleRadiusY = floorDepth * 0.16;

    final arcRect = Rect.fromCenter(
      center: Offset(centerX, circleCenterY),
      width: circleRadiusX * 2,
      height: circleRadiusY * 2,
    );

    // Solid front half of circle
    canvas.drawArc(arcRect, 0, math.pi, false, courtLinePaint);

    // Dashed back half of circle
    final dashedPaint = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double a = math.pi; a < 2 * math.pi; a += 0.35) {
      canvas.drawArc(arcRect, a, 0.18, false, dashedPaint);
    }
  }
}
