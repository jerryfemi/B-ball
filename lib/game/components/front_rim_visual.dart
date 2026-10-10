import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'ball.dart';

/// Renders the front half of the metal rim, mounting bracket, and front net cords.
/// Configured with priority = 3 so it renders in front of the basketball (priority = 2),
/// completing the 2.5D immersion when the ball drops into the hoop.
class FrontRimVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  double _currentNetDepth = 0.9;
  double _currentBottomWidth = 0.55;
  double _netDepthVelocity = 0.0;
  double _netWidthVelocity = 0.0;
  double _currentSway = 0.0;
  double _swayVelocity = 0.0;

  FrontRimVisual({
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
    
    final balls = parent?.children.whereType<Basketball>() ?? [];
    bool ballInNet = false;
    double maxDepth = 0.9;
    double targetWidth = 0.55;

    for (final ball in balls) {
      // Only stretch when a ball that reached the rim is moving downwards through the hoop
      if (ball.passedThroughRim &&
          ball.body.position.y >= 4.9 &&
          ball.body.position.y <= 6.2 &&
          ball.body.linearVelocity.y > 0) {
        // Must be horizontally close to the center
        if (ball.body.position.x.abs() < hoopWidth * 0.45) {
          ballInNet = true;
          double stretchDepth = ball.body.position.y - 5.0 + ball.radius * 0.7;
          if (stretchDepth > maxDepth) maxDepth = stretchDepth;
          targetWidth = 0.85; // Widen bottom to let ball through

          // Impart lateral sway from ball horizontal speed
          _swayVelocity = (ball.body.linearVelocity.x * 0.35).clamp(-2.0, 2.0);
          _currentSway = (ball.body.position.x * 0.25).clamp(-0.20, 0.20);
        }
      }
    }

    if (ballInNet) {
      _currentNetDepth = maxDepth.clamp(0.85, 1.35);
      _currentBottomWidth = targetWidth.clamp(0.55, 0.85);
      _netDepthVelocity = 1.8; // Spring release momentum when ball leaves
      _netWidthVelocity = -1.2;
    } else {
      // Numerical stability: clamp timestep
      final clampedDt = dt.clamp(0.001, 0.02);
      // Under-damped spring values for a lively, wobbly, organic net
      const double kStiffness = 85.0;
      const double kDamping = 4.8;

      double depthForce =
          kStiffness * (0.9 - _currentNetDepth) - kDamping * _netDepthVelocity;
      _netDepthVelocity += depthForce * clampedDt;
      _currentNetDepth += _netDepthVelocity * clampedDt;
      _currentNetDepth = _currentNetDepth.clamp(0.70, 1.45);

      double widthForce =
          kStiffness * (0.55 - _currentBottomWidth) - kDamping * _netWidthVelocity;
      _netWidthVelocity += widthForce * clampedDt;
      _currentBottomWidth += _netWidthVelocity * clampedDt;
      _currentBottomWidth = _currentBottomWidth.clamp(0.38, 0.92);

      // Lateral harmonic sway jiggle
      double swayForce = 70.0 * (0.0 - _currentSway) - 4.2 * _swayVelocity;
      _swayVelocity += swayForce * clampedDt;
      _currentSway += _swayVelocity * clampedDt;
      _currentSway = _currentSway.clamp(-0.25, 0.25);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);

    _renderMountingBracket(canvas);
    _renderFrontNet(canvas);
    _renderFrontRim(canvas);

    canvas.restore();
  }

  void _renderMountingBracket(Canvas canvas) {
    final bracketPaint = Paint()
      ..color = const Color(0xFF7F1319) // Burnished iron crimson
      ..style = PaintingStyle.fill;

    // Small mounting flange connecting rim to backboard
    final bracketRect = Rect.fromCenter(
      center: const Offset(0, -0.10),
      width: 0.28,
      height: 0.16,
    );
    canvas.drawRect(bracketRect, bracketPaint);

    final boltPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-0.08, -0.10), 0.022, boltPaint);
    canvas.drawCircle(const Offset(0.08, -0.10), 0.022, boltPaint);
  }

  void _renderFrontRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // 1. Deep underside rim shadow for metallic depth
    final underRimPaint = Paint()
      ..color = const Color(0xFF6B1116)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.09;

    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 0.010), width: hoopWidth, height: hoopDepth),
      0,
      math.pi,
      false,
      underRimPaint,
    );

    // 2. Base burnished iron crimson rim arc (bottom half from 0 to pi)
    final frontRimPaint = Paint()
      ..color = const Color(0xFF9E1B22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

    canvas.drawArc(
      rimRect,
      0,
      math.pi,
      false,
      frontRimPaint,
    );

    // 3. Specular metallic highlight along the top crest
    final highlightPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.022;

    final highlightRect = Rect.fromCenter(
      center: const Offset(0, -0.008),
      width: hoopWidth - 0.06,
      height: hoopDepth,
    );

    canvas.drawArc(
      highlightRect,
      0.15,
      math.pi - 0.3,
      false,
      highlightPaint,
    );

    // 4. Circular rim tips at the left and right collision pivots
    final pivotPaint = Paint()
      ..color = const Color(0xFF9E1B22)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(-hoopWidth / 2, 0), 0.045, pivotPaint);
    canvas.drawCircle(Offset(hoopWidth / 2, 0), 0.045, pivotPaint);
  }

  void _renderFrontNet(Canvas canvas) {
    final netCordPaint = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035;

    final knotPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    const cordCount = 8;
    final netDepth = _currentNetDepth;
    final bottomWidthRatio = _currentBottomWidth;

    final topPoints = <Offset>[];
    final bottomPoints = <Offset>[];

    // Compute attachment loops along front rim arc (0 to pi)
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
      final angle = t * math.pi;
      final x = (hoopWidth / 2) * math.cos(angle);
      final y = (hoopDepth / 2) * math.sin(angle);
      topPoints.add(Offset(x, y));

      final bx = x * bottomWidthRatio + _currentSway;
      final by = netDepth;
      bottomPoints.add(Offset(bx, by));
    }

    // 1. Draw cross-hatched cord mesh
    for (int i = 0; i < cordCount; i++) {
      canvas.drawLine(topPoints[i], bottomPoints[i + 1], netCordPaint);
      canvas.drawLine(topPoints[i + 1], bottomPoints[i], netCordPaint);
    }

    // 2. Draw front horizontal loop ribs
    for (double yFrac = 0.25; yFrac <= 0.85; yFrac += 0.25) {
      final curY = netDepth * yFrac;
      final curWidth = hoopWidth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);
      final curDepth = hoopDepth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);

      final ribRect = Rect.fromCenter(
        center: Offset(_currentSway * yFrac, curY),
        width: curWidth,
        height: curDepth,
      );

      canvas.drawArc(
        ribRect,
        0,
        math.pi,
        false,
        netCordPaint,
      );

      // Knots along the horizontal rib
      for (int k = 1; k < cordCount; k++) {
        final t = k / cordCount;
        final angle = t * math.pi;
        final kx = _currentSway * yFrac + (curWidth / 2) * math.cos(angle);
        final ky = curY + (curDepth / 2) * math.sin(angle);
        canvas.drawCircle(Offset(kx, ky), 0.02, knotPaint);
      }
    }
  }
}
