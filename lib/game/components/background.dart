import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Authentic GamePigeon basketball court background:
/// - Weathered red clay brick wall with mortar joints and ambient lighting.
/// - Terracotta/crimson painted key court with maple flanks and regulation markings.
/// - Pole anchor baseplate collar.
/// - Glossy vertical white pole reflection streak down the center court.
class GameBackground extends Component with HasGameReference {
  // Deterministic brick color palette (clay, terracotta, burnt sienna)
  static const List<Color> _brickColors = [
    Color(0xFFA33B27),
    Color(0xFF8F2F1E),
    Color(0xFFB54631),
    Color(0xFF7C2617),
    Color(0xFF993724),
    Color(0xFFAB412D),
  ];

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final width = game.size.x;
    final height = game.size.y;
    final wallHeight = height * 0.50; // Expansive court horizon: 50% wall, 50% floor
    final floorHeight = height - wallHeight;

    _renderBrickWall(canvas, width, wallHeight);
    _renderCourtFloor(canvas, width, height, wallHeight, floorHeight);
  }

  void _renderBrickWall(Canvas canvas, double width, double wallHeight) {
    final wallRect = Rect.fromLTWH(0, 0, width, wallHeight);

    // 1. Sandy mortar base background
    final mortarPaint = Paint()..color = const Color(0xFF7A6858);
    canvas.drawRect(wallRect, mortarPaint);

    // 2. Running-bond clay bricks
    const brickWidth = 44.0;
    const brickHeight = 16.0;
    const mortarGap = 3.0;
    const stepX = brickWidth + mortarGap;
    const stepY = brickHeight + mortarGap;

    final brickPaint = Paint()..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.0;
    final shadowPaint = Paint()
      ..color = const Color(0x28000000)
      ..strokeWidth = 1.0;

    int row = 0;
    for (double y = 0; y < wallHeight; y += stepY) {
      final isOdd = row % 2 == 1;
      final startX = isOdd ? -brickWidth / 2 : 0.0;
      int col = 0;

      for (double x = startX; x < width + brickWidth; x += stepX) {
        // Deterministic brick color selection
        final colorIndex = ((row * 13) + (col * 7)) % _brickColors.length;
        brickPaint.color = _brickColors[colorIndex];

        final bRect = Rect.fromLTWH(
          x,
          y,
          brickWidth,
          math.min(brickHeight, wallHeight - y),
        );
        final rRect =
            RRect.fromRectAndRadius(bRect, const Radius.circular(1.5));
        canvas.drawRRect(rRect, brickPaint);

        // Subtle top bevel highlight and bottom bevel shadow for 3D brick depth
        canvas.drawLine(
          Offset(bRect.left + 1, bRect.top + 1),
          Offset(bRect.right - 1, bRect.top + 1),
          highlightPaint,
        );
        canvas.drawLine(
          Offset(bRect.left + 1, bRect.bottom - 1),
          Offset(bRect.right - 1, bRect.bottom - 1),
          shadowPaint,
        );

        col++;
      }
      row++;
    }

    // 3. Ambient atmospheric lighting & vignette
    final vignettePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x80000000), // Darker at ceiling
          Color(0x15000000), // Soft ambient in middle
          Color(0x40000000), // Shadow meeting the floor junction
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(wallRect);
    canvas.drawRect(wallRect, vignettePaint);

    // 4. Subtle wall base molding / junction trim
    final trimPaint = Paint()..color = const Color(0xFF1E140F);
    canvas.drawRect(
      Rect.fromLTWH(0, wallHeight - 4.0, width, 4.0),
      trimPaint,
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
    final centerX = width / 2;

    // 1. Maple hardwood outer flanks
    final maplePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFC78B4E),
          Color(0xFFD69A5C),
          Color(0xFFC98E50),
        ],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, maplePaint);

    // Subtle maple floor planks
    final plankLinePaint = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 0.8;
    for (double y = wallHeight; y < height; y += 18.0) {
      canvas.drawLine(Offset(0, y), Offset(width, y), plankLinePaint);
    }

    // 2. Terracotta/Crimson painted key court trapezoid in deep perspective
    final topKeyWidth = width * 0.40;
    final bottomKeyWidth = width * 0.88;

    final keyPath = Path()
      ..moveTo(centerX - topKeyWidth / 2, wallHeight)
      ..lineTo(centerX + topKeyWidth / 2, wallHeight)
      ..lineTo(centerX + bottomKeyWidth / 2, height)
      ..lineTo(centerX - bottomKeyWidth / 2, height)
      ..close();

    final keyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF8B1E1E), // Deeper crimson near back wall
          Color(0xFFA52A2A), // Vibrant terracotta red center
          Color(0xFF962323), // Foreground red
        ],
      ).createShader(floorRect);
    canvas.drawPath(keyPath, keyPaint);

    final keyBorderPaint = Paint()
      ..color = const Color(0xFFFACC15) // Yellow arcade border line instead of dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(keyPath, keyBorderPaint);

    // 3. Free-Throw Markings
    _renderCourtMarkings(canvas, width, height, wallHeight, floorHeight);

    // 4. Overall floor gloss sheen overlay
    final floorGlossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x30FFFFFF),
          const Color(0x05FFFFFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorGlossPaint);
  }

  void _renderCourtMarkings(
    Canvas canvas,
    double width,
    double height,
    double wallHeight,
    double floorHeight,
  ) {
    final centerX = width / 2;

    // Free-throw circle arc in deep perspective
    final circleCenterY = wallHeight + floorHeight * 0.38;
    final radiusX = width * 0.22;
    final radiusY = floorHeight * 0.12;

    final arcRect = Rect.fromCenter(
      center: Offset(centerX, circleCenterY),
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // Solid front arc (facing player)
    final solidArcPaint = Paint()
      ..color = const Color(0xFFFACC15) // Yellow arcade markings
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawArc(arcRect, 0, math.pi, false, solidArcPaint);

    // Dashed back arc (receding toward basket)
    final dashedArcPaint = Paint()
      ..color = const Color(0xCCFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (double a = math.pi; a < 2 * math.pi; a += 0.35) {
      canvas.drawArc(arcRect, a, 0.18, false, dashedArcPaint);
    }
  }
}
