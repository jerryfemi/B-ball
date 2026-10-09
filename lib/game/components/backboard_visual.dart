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

  BackboardVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.45,
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
      if (ball.passedThroughRim && ball.body.position.y > 4.8 && ball.body.position.y < 6.8 && ball.body.linearVelocity.y > 0) {
        if (ball.body.position.x.abs() < hoopWidth / 2) {
          ballInNet = true;
          double stretchDepth = ball.body.position.y - 5.0 + ball.radius * 0.7;
          if (stretchDepth > maxDepth) maxDepth = stretchDepth;
          targetWidth = 0.85; 
        }
      }
    }

    if (ballInNet) {
      _currentNetDepth = maxDepth;
      _currentBottomWidth = targetWidth;
      _netDepthVelocity = 0.0;
      _netWidthVelocity = 0.0;
    } else {
      const double kStiffness = 200.0;
      const double kDamping = 12.0;

      double depthForce = kStiffness * (0.9 - _currentNetDepth) - kDamping * _netDepthVelocity;
      _netDepthVelocity += depthForce * dt;
      _currentNetDepth += _netDepthVelocity * dt;

      double widthForce = kStiffness * (0.55 - _currentBottomWidth) - kDamping * _netWidthVelocity;
      _netWidthVelocity += widthForce * dt;
      _currentBottomWidth += _netWidthVelocity * dt;
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
    // Soft blurred ambient drop shadow cast onto the brick wall behind the backboard
    final shadowPaint = Paint()
      ..color = const Color(0x60000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final shadowPath = _buildBackboardPath(3.6, 2.4, const Offset(0.08, -0.92));
    canvas.drawPath(shadowPath, shadowPaint);

    // Mount drop shadow on wall
    final mountShadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(
      const Rect.fromLTWH(-0.8, -1.1, 0.15, 2.5),
      mountShadowPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0.85, -1.1, 0.15, 2.5),
      mountShadowPaint,
    );
  }

  void _renderWallMounts(Canvas canvas) {
    // Renders heavy-duty steel wall mounts behind the backboard
    final mountPaint = Paint()
      ..color = const Color(0xFF475569) // Dark slate metal
      ..style = PaintingStyle.fill;
      
    final highlightPaint = Paint()
      ..color = const Color(0xFF64748B) // Highlight edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    // Left and right mounting struts
    final leftStrut = Rect.fromLTWH(-0.9, -1.2, 0.15, 2.5);
    final rightStrut = Rect.fromLTWH(0.75, -1.2, 0.15, 2.5);
    
    canvas.drawRect(leftStrut, mountPaint);
    canvas.drawRect(leftStrut, highlightPaint);
    canvas.drawRect(rightStrut, mountPaint);
    canvas.drawRect(rightStrut, highlightPaint);
    
    // Crossbeam
    final crossbeam = Rect.fromCenter(center: const Offset(0, -0.2), width: 2.0, height: 0.2);
    canvas.drawRect(crossbeam, mountPaint);
    canvas.drawRect(crossbeam, highlightPaint);
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
      ..color = const Color(0xFFC2410C) // Shaded burnt orange
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

      final bottomX = topX * bottomWidthRatio;
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
        center: Offset(0, curY),
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
