import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'ball.dart';

/// Renders the GamePigeon scooped-shield backboard, 3D cylindrical pole,
/// wall drop shadows, rear rim arc, and back net mesh.
/// Configured with priority = 1 so it renders behind the basketball (priority = 2).
class BackboardVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  double _currentNetDepth = 0.9;
  double _currentBottomWidth = 0.55;
  double _netDepthVelocity = 0.0;
  double _netWidthVelocity = 0.0;
  double _currentSway = 0.0;
  double _swayVelocity = 0.0;

  BackboardVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.15,
  }) : super(
          position: position,
          size: Vector2(6.0, 20.0),
          anchor: Anchor.center,
          priority: 1,
        );

  @override
  void update(double dt) {
    super.update(dt);
    
    final balls = parent?.children.whereType<Basketball>() ?? [];
    bool ballInNet = false;
    double maxDepth = 0.9;
    double targetWidth = 0.55;

    for (final ball in balls) {
      if (ball.passedThroughRim &&
          ball.body.position.y >= 4.9 &&
          ball.body.position.y <= 6.2 &&
          ball.body.linearVelocity.y > 0) {
        if (ball.body.position.x.abs() < hoopWidth * 0.45) {
          ballInNet = true;
          double stretchDepth = ball.body.position.y - 5.0 + ball.radius * 0.7;
          if (stretchDepth > maxDepth) maxDepth = stretchDepth;
          targetWidth = 0.85; 

          // Impart lateral sway from ball horizontal speed
          _swayVelocity = (ball.body.linearVelocity.x * 0.35).clamp(-2.0, 2.0);
          _currentSway = (ball.body.position.x * 0.25).clamp(-0.20, 0.20);
        }
      }
    }

    if (ballInNet) {
      _currentNetDepth = maxDepth.clamp(0.85, 1.35);
      _currentBottomWidth = targetWidth.clamp(0.55, 0.85);
      _netDepthVelocity = 1.8;
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

    _renderWallDropShadow(canvas);
    _renderWallMounts(canvas);
    _renderScoopedBackboard(canvas);
    _renderRearRim(canvas);
    _renderRearNet(canvas);

    canvas.restore();
  }

  void _renderWallDropShadow(Canvas canvas) {
    // Soft, deep diffuse shadow projected onto the distant back wall
    // Reflects that the hoop is suspended forward in the 3D room volume
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final shadowPath =
        _buildBackboardPath(3.7, 2.5, const Offset(0.10, -0.82));
    canvas.drawPath(shadowPath, shadowPaint);

    // Boom arm diffuse shadow projected back onto the wall
    final boomShadowPaint = Paint()
      ..color = const Color(0x35000000)
      ..strokeWidth = 0.25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(const Offset(-0.85, -1.6), const Offset(-0.55, -2.4), boomShadowPaint);
    canvas.drawLine(const Offset(0.85, -1.6), const Offset(0.55, -2.4), boomShadowPaint);
    canvas.drawLine(const Offset(-0.85, -0.4), const Offset(-0.55, -1.1), boomShadowPaint);
    canvas.drawLine(const Offset(0.85, -0.4), const Offset(0.55, -1.1), boomShadowPaint);
  }

  void _renderWallMounts(Canvas canvas) {
    // Industrial 3D cantilever steel truss boom extending forward from the distant wall
    final steelPaint = Paint()
      ..color = const Color(0xFF334155) // Dark slate structural steel
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = const Color(0x5094A3B8) // Steel top edge highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04;

    final darkShadowPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    // 1. Distant wall mounting anchor plate
    final anchorPlate = Rect.fromCenter(
      center: const Offset(0, -1.8),
      width: 1.6,
      height: 1.8,
    );
    canvas.drawRect(anchorPlate, darkShadowPaint);
    canvas.drawRect(
      anchorPlate,
      Paint()
        ..color = const Color(0x3064748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04,
    );

    // Anchor bolt studs on the distant wall plate
    final boltPaint = Paint()..color = const Color(0xFF64748B);
    for (final boltOffset in const [
      Offset(-0.7, -2.5),
      Offset(0.7, -2.5),
      Offset(-0.7, -1.1),
      Offset(0.7, -1.1),
    ]) {
      canvas.drawCircle(boltOffset, 0.04, boltPaint);
    }

    // 2. Cantilever Diagonal Steel Truss Boom Arms (reaching forward to backboard)
    final boomPath = Path();

    // Upper Left Boom Arm
    boomPath.moveTo(-0.95, -1.8);
    boomPath.lineTo(-0.60, -2.55);
    boomPath.lineTo(-0.50, -2.55);
    boomPath.lineTo(-0.85, -1.8);
    boomPath.close();

    // Upper Right Boom Arm
    boomPath.moveTo(0.85, -1.8);
    boomPath.lineTo(0.50, -2.55);
    boomPath.lineTo(0.60, -2.55);
    boomPath.lineTo(0.95, -1.8);
    boomPath.close();

    // Lower Left Diagonal Compression Strut
    boomPath.moveTo(-0.95, -0.35);
    boomPath.lineTo(-0.60, -1.15);
    boomPath.lineTo(-0.50, -1.15);
    boomPath.lineTo(-0.85, -0.35);
    boomPath.close();

    // Lower Right Diagonal Compression Strut
    boomPath.moveTo(0.85, -0.35);
    boomPath.lineTo(0.50, -1.15);
    boomPath.lineTo(0.60, -1.15);
    boomPath.lineTo(0.95, -0.35);
    boomPath.close();

    canvas.drawPath(boomPath, steelPaint);
    canvas.drawPath(boomPath, highlightPaint);

    // 3. Steel X-Bracing across the boom
    final bracePaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 0.06;

    canvas.drawLine(const Offset(-0.85, -1.7), const Offset(0.85, -0.45), bracePaint);
    canvas.drawLine(const Offset(0.85, -1.7), const Offset(-0.85, -0.45), bracePaint);

    // 4. Heavy horizontal crossbeams directly behind the backboard
    final topBeam = Rect.fromCenter(center: const Offset(0, -1.75), width: 2.1, height: 0.16);
    final botBeam = Rect.fromCenter(center: const Offset(0, -0.40), width: 2.1, height: 0.16);

    canvas.drawRect(topBeam, steelPaint);
    canvas.drawRect(topBeam, highlightPaint);
    canvas.drawRect(botBeam, steelPaint);
    canvas.drawRect(botBeam, highlightPaint);
  }

  void _renderScoopedBackboard(Canvas canvas) {
    const boardWidth = 3.6;
    const boardHeight = 2.4;
    const boardCenter = Offset(0, -1.02);

    final outerPath = _buildBackboardPath(boardWidth, boardHeight, boardCenter);
    final innerPath = _buildBackboardPath(boardWidth * 0.90, boardHeight * 0.90, boardCenter);

    // 1. Glossy white backboard face plate
    final facePaint = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerPath, facePaint);

    // Subtle gloss gradient sheen across backboard
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0x25FFFFFF),
          Colors.transparent,
          const Color(0x10000000),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: boardCenter,
          width: boardWidth,
          height: boardHeight,
        ),
      );
    canvas.drawPath(outerPath, sheenPaint);

    // 2. Outer bold red contour line
    final outerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.08;
    canvas.drawPath(outerPath, outerRedPaint);

    // 3. Inner parallel red accent line (signature GamePigeon double border)
    final innerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.035;
    canvas.drawPath(innerPath, innerRedPaint);

    // 4. Regulation target rectangle directly above the rim
    final targetRect = Rect.fromCenter(
      center: const Offset(0, -0.65),
      width: 1.0,
      height: 0.75,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    canvas.drawRect(targetRect, targetPaint);
  }

  Path _buildBackboardPath(double w, double h, Offset center) {
    final path = Path();
    final hw = w / 2;
    final hh = h / 2;

    // Symmetric scooped-shield fan contour
    path.moveTo(center.dx, center.dy - hh);
    // Top-right shoulder notch
    path.lineTo(center.dx + hw * 0.40, center.dy - hh);
    path.quadraticBezierTo(
      center.dx + hw * 0.65,
      center.dy - hh * 0.95,
      center.dx + hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.75,
      center.dy - hh * 0.60,
      center.dx + hw,
      center.dy - hh * 0.48,
    );
    // Right side curve down to lower corner
    path.quadraticBezierTo(
      center.dx + hw * 1.02,
      center.dy + hh * 0.05,
      center.dx + hw * 0.90,
      center.dy + hh * 0.65,
    );
    path.quadraticBezierTo(
      center.dx + hw * 0.82,
      center.dy + hh,
      center.dx + hw * 0.55,
      center.dy + hh,
    );
    // Bottom edge to bottom-left corner
    path.lineTo(center.dx - hw * 0.55, center.dy + hh);
    path.quadraticBezierTo(
      center.dx - hw * 0.82,
      center.dy + hh,
      center.dx - hw * 0.90,
      center.dy + hh * 0.65,
    );
    // Left side curve up to shoulder
    path.quadraticBezierTo(
      center.dx - hw * 1.02,
      center.dy + hh * 0.05,
      center.dx - hw,
      center.dy - hh * 0.48,
    );
    // Top-left shoulder notch
    path.quadraticBezierTo(
      center.dx - hw * 0.75,
      center.dy - hh * 0.60,
      center.dx - hw * 0.70,
      center.dy - hh * 0.75,
    );
    path.quadraticBezierTo(
      center.dx - hw * 0.65,
      center.dy - hh * 0.95,
      center.dx - hw * 0.40,
      center.dy - hh,
    );
    path.close();

    return path;
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

    canvas.drawArc(
      rimRect,
      math.pi,
      math.pi,
      false,
      rearRimPaint,
    );
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

      canvas.drawArc(
        ribRect,
        math.pi,
        math.pi,
        false,
        rearNetPaint,
      );
    }
  }
}
