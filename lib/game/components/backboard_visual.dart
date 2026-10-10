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
      // Under-damped spring values for a fast, loose, non-viscous wobbly net
      const double kStiffness = 120.0;
      const double kDamping = 3.5;

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

      // Lateral harmonic sway jiggle (fast and loose)
      double swayForce = 90.0 * (0.0 - _currentSway) - 2.8 * _swayVelocity;
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
    _renderPole(canvas);
    _renderScoopedBackboard(canvas);
    _renderRearRim(canvas);
    _renderRearNet(canvas);

    canvas.restore();
  }

  void _renderWallDropShadow(Canvas canvas) {
    // Soft, realistic ambient drop shadow cast onto the back wall directly behind backboard
    final shadowPaint = Paint()
      ..color = const Color(0x3B000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.22);

    final shadowPath =
        _buildBackboardPath(3.6, 2.4, const Offset(0.08, -0.94));
    canvas.drawPath(shadowPath, shadowPaint);

    // Subtle drop shadow cast by the vertical pole onto the back wall
    final poleShadowPaint = Paint()
      ..color = const Color(0x28000000)
      ..strokeWidth = 0.22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.16);

    canvas.drawLine(
      const Offset(0.08, -0.15),
      const Offset(0.08, 7.8),
      poleShadowPaint,
    );
  }

  void _renderPole(Canvas canvas) {
    const poleWidth = 0.22;
    const topY = -0.30;
    const bottomY = 7.80; // Hardwood floor entry depth under hoop

    final poleRect = Rect.fromLTRB(
      -poleWidth / 2,
      topY,
      poleWidth / 2,
      bottomY,
    );

    // 1. Pole floor contact shadow on the hardwood
    final floorShadowPaint = Paint()
      ..color = const Color(0x60000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.08);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, bottomY + 0.03),
        width: poleWidth * 2.2,
        height: 0.12,
      ),
      floorShadowPaint,
    );

    // 2. 3D Cylindrical lighting gradient for metallic post
    final polePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.0, 0.22, 0.50, 0.82, 1.0],
        colors: [
          Color(0xFFCBD5E1), // Left rim shadow
          Color(0xFFFFFFFF), // Left-center specular reflection crest
          Color(0xFFF1F5F9), // Center body
          Color(0xFFE2E8F0), // Right midtone
          Color(0xFF94A3B8), // Right shadow edge
        ],
      ).createShader(poleRect);

    canvas.drawRect(poleRect, polePaint);

    // 3. Subtle longitudinal edge outline for crisp definition
    final poleEdgePaint = Paint()
      ..color = const Color(0x3064748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(
      const Offset(-poleWidth / 2, topY),
      const Offset(-poleWidth / 2, bottomY),
      poleEdgePaint,
    );
    canvas.drawLine(
      const Offset(poleWidth / 2, topY),
      const Offset(poleWidth / 2, bottomY),
      poleEdgePaint,
    );

    // 4. Ground base collar flange where pole anchors into the court floor
    final collarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, bottomY),
        width: poleWidth * 1.65,
        height: 0.16,
      ),
      const Radius.circular(0.04),
    );

    final collarPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF94A3B8),
          Color(0xFFF1F5F9),
          Color(0xFF64748B),
        ],
      ).createShader(collarRect.outerRect);

    canvas.drawRRect(collarRect, collarPaint);
    canvas.drawRRect(
      collarRect,
      Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025,
    );

    // 5. Backboard mounting collar & gusset directly behind the hoop
    final mountCollar = Rect.fromCenter(
      center: const Offset(0, -0.22),
      width: poleWidth * 1.45,
      height: 0.22,
    );
    canvas.drawRect(
      mountCollar,
      Paint()..color = const Color(0xFF64748B),
    );
    canvas.drawRect(
      mountCollar,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025,
    );
  }

  void _renderScoopedBackboard(Canvas canvas) {
    const boardWidth = 3.6;
    const boardHeight = 2.4;
    const boardCenter = Offset(0, -1.02);

    final outerPath = _buildBackboardPath(boardWidth, boardHeight, boardCenter);
    final innerPath = _buildBackboardPath(boardWidth * 0.90, boardHeight * 0.90, boardCenter);

    // 1. 3D Acrylic edge bevel (subtle thickness rim)
    final bevelPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outerPath, bevelPaint);

    // 2. Glossy white backboard face plate
    final facePaint = Paint()
      ..color = const Color(0xFFFAFAFA)
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerPath, facePaint);

    // 3. Subtle gloss sheen gradient
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0x20FFFFFF),
          Colors.transparent,
          Color(0x0C000000),
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

    // 4. Diagonal glass specular streak (GamePigeon signature acrylic reflection)
    canvas.save();
    canvas.clipPath(outerPath);

    final streakPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.85, -1.0),
        end: const Alignment(0.85, 1.0),
        stops: const [0.0, 0.30, 0.38, 0.46, 0.54, 1.0],
        colors: const [
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x28FFFFFF),
          Color(0x42FFFFFF),
          Color(0x10FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(
        Rect.fromCenter(
          center: boardCenter,
          width: boardWidth * 1.4,
          height: boardHeight * 1.4,
        ),
      );
    canvas.drawRect(
      Rect.fromCenter(
        center: boardCenter,
        width: boardWidth * 1.5,
        height: boardHeight * 1.5,
      ),
      streakPaint,
    );
    canvas.restore();

    // 5. Outer bold red contour line
    final outerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.08;
    canvas.drawPath(outerPath, outerRedPaint);

    // 6. Inner parallel red accent line (signature GamePigeon double border)
    final innerRedPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.035;
    canvas.drawPath(innerPath, innerRedPaint);

    // 7. Regulation target rectangle directly above the rim
    final targetRect = Rect.fromCenter(
      center: const Offset(0, -0.66),
      width: 0.98,
      height: 0.72,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.065;
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
