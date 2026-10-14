import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'backboard_visual.dart';

/// Renders the rear half of the metal rim, solid steel mounting bracket neck,
/// and rear net mesh at priority = 3.
///
/// In the 2.5D layering pipeline:
/// - Priority 1: BackboardVisual (wall shadows, pole, backboard glass, target square)
/// - Priority 2: Basketball when banking off backboard or on rear neck (Z >= 4.70m)
/// - Priority 3: RearRimVisual (rear rim arc, mounting bracket flange, rear net)
/// - Priority 4: Basketball inside hoop cylinder / net (4.23m <= Z < 4.70m)
/// - Priority 5: FrontRimVisual (front rim arc, highlight, front net)
/// - Priority 6: Basketball in foreground (Z < 4.23m)
///
/// This mathematically guarantees that balls hitting the bank zone bounce visibly
/// in front of the backboard faceplate while remaining solidly behind the rear rim
/// and mounting bracket — completely eliminating any visual "slip-through" glitch.
class RearRimVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  double _currentNetDepth = 0.9;
  double _currentBottomWidth = 0.55;
  double _currentSway = 0.0;

  BackboardVisual? _cachedBackboard;

  RearRimVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.15,
  }) : super(
          position: position,
          size: Vector2(4.0, 4.0),
          anchor: Anchor.center,
          priority: 3,
        );

  @override
  void update(double dt) {
    super.update(dt);

    _cachedBackboard ??=
        parent?.children.whereType<BackboardVisual>().firstOrNull;
    if (_cachedBackboard != null) {
      _currentNetDepth = _cachedBackboard!.currentNetDepth;
      _currentBottomWidth = _cachedBackboard!.currentBottomWidth;
      _currentSway = _cachedBackboard!.currentSway;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);

    _renderMountingBracket(canvas);
    _renderRearNet(canvas);
    _renderRearRim(canvas);

    canvas.restore();
  }

  void _renderMountingBracket(Canvas canvas) {
    final bracketPaint = Paint()
      ..color = const Color(0xFF7F1319) // Burnished iron crimson
      ..style = PaintingStyle.fill;

    // Solid mounting flange connecting rear rim to backboard faceplate
    // Spans from rear rim (Y = -0.075) to backboard collar (Y = -0.22)
    final bracketRect = Rect.fromCenter(
      center: const Offset(0, -0.10),
      width: 0.34,
      height: 0.18,
    );
    canvas.drawRect(bracketRect, bracketPaint);

    // Top crest metallic highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(
      const Offset(-0.16, -0.18),
      const Offset(0.16, -0.18),
      highlightPaint,
    );

    // Heavy mounting bolts
    final boltPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-0.10, -0.10), 0.024, boltPaint);
    canvas.drawCircle(const Offset(0.10, -0.10), 0.024, boltPaint);
  }

  void _renderRearRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // Top half of rim ellipse (from pi to 2*pi): curves upwards/away
    final rearRimPaint = Paint()
      ..color = const Color(0xFF751117) // Shaded deep iron crimson
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

    canvas.drawArc(rimRect, math.pi, math.pi, false, rearRimPaint);
  }

  void _renderRearNet(Canvas canvas) {
    final rearNetPaint = Paint()
      ..color = const Color(0x5094A3B8) // Translucent rear cords
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025;

    const cordCount = 7;
    final netDepth = _currentNetDepth;
    final bottomWidthRatio = _currentBottomWidth;

    // Draw rear vertical cords tapering downwards
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
      final angle = math.pi + t * math.pi;
      final topX = (hoopWidth / 2) * math.cos(angle);
      final topY = (hoopDepth / 2) * math.sin(angle);

      final bottomX = topX * bottomWidthRatio + _currentSway;
      final bottomY = netDepth;

      canvas.drawLine(
        Offset(topX, topY),
        Offset(bottomX, bottomY),
        rearNetPaint,
      );
    }

    // Rear horizontal ribs
    for (double yFrac = 0.25; yFrac <= 0.85; yFrac += 0.25) {
      final curY = netDepth * yFrac;
      final curWidth = hoopWidth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);
      final curDepth = hoopDepth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);

      final ribRect = Rect.fromCenter(
        center: Offset(_currentSway * yFrac, curY),
        width: curWidth,
        height: curDepth,
      );

      canvas.drawArc(ribRect, math.pi, math.pi, false, rearNetPaint);
    }
  }
}
