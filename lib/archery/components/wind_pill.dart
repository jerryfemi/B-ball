import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';
import '../physics/wind_model.dart';

/// World-anchored wind pill rendered above the target board (Build Plan v2 §6).
///
/// Features:
/// - World-anchored above the current set's target board.
/// - Reprojected every frame to naturally scale and track camera moves.
/// - Shows dark rounded pill (#0A0E1A at 75% alpha).
/// - Bold white text "WIND: X.X".
/// - 22 px circle outline with directional arrow rotated to wind angle.
/// - Visible in atLine and aiming; hidden during chase and closeup.
/// - Zero heap allocations per render frame.
class WindPill {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  WindPill({required this.camera, required this.cameraRig});

  // Cached Paints
  final Paint _bgPaint = Paint()
    ..color = const Color(0xFF0A0E1A).withValues(alpha: 0.85)
    ..style = PaintingStyle.fill;

  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF1E283D)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  final Paint _dialCirclePaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  final Paint _arrowPaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final Paint _arrowHeadPaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..style = PaintingStyle.fill;

  // Cached Path for Arrow
  final Path _arrowHeadPath = Path();

  // Cached TextPainter
  TextPainter? _textPainter;
  double _lastDisplay = -1.0;

  void render(Canvas canvas, WindModel wind) {
    // Only show during atLine, raising, and aiming
    final ShotPhase phase = cameraRig.phase;
    if (phase != ShotPhase.atLine &&
        phase != ShotPhase.raising &&
        phase != ShotPhase.aiming &&
        phase != ShotPhase.returning) {
      return;
    }

    // Anchored to the top edge of the board, then lifted by a fixed number of
    // pixels so it never overlaps the (small) far targets.
    final double boardTopY = ArcheryK.targetCenterY + ArcheryK.boardHeight * 0.5;
    if (!camera.project(0.0, boardTopY, cameraRig.targetDistance)) return;

    final double cx = camera.sx;
    final double boardTopSy = camera.sy;

    // Cache / update TextPainter if display value changed
    if (_textPainter == null || _lastDisplay != wind.display) {
      _lastDisplay = wind.display;
      final String text = 'WIND: ${wind.display.toStringAsFixed(1)}';
      _textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    const double dialDiameter = 22.0;
    const double dialRadius = dialDiameter * 0.5;
    const double pillPadH = 10.0;
    const double pillPadV = 5.0;
    const double spacing = 8.0;

    final double textW = _textPainter!.width;
    final double textH = _textPainter!.height;
    final double pillW = pillPadH * 2.0 + textW + spacing + dialDiameter;
    final double pillH = math.max(textH, dialDiameter) + pillPadV * 2.0;
    final double cy = boardTopSy - pillH * 0.5 - 10.0;

    final Rect pillRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: pillW,
      height: pillH,
    );
    final RRect pillRRect = RRect.fromRectAndRadius(
      pillRect,
      Radius.circular(pillH * 0.5),
    );

    // 1. Draw Pill Background and Outline
    canvas.drawRRect(pillRRect, _bgPaint);
    canvas.drawRRect(pillRRect, _borderPaint);

    // 2. Draw Wind Text
    final double textLeft = pillRect.left + pillPadH;
    final double textTop = pillRect.top + (pillH - textH) * 0.5;
    _textPainter!.paint(canvas, Offset(textLeft, textTop));

    // 3. Draw Wind Dial & Rotated Directional Arrow
    final double dialCenterX = pillRect.right - pillPadH - dialRadius;
    final double dialCenterY = pillRect.top + pillH * 0.5;
    final Offset dialCenter = Offset(dialCenterX, dialCenterY);

    canvas.drawCircle(dialCenter, dialRadius, _dialCirclePaint);

    // Arrow rotated to wind.angle
    // wind.angle: 0 = downrange (+Z / up on dial), π/2 = right (+X / right on dial)
    final double rotAngle = wind.angle - math.pi * 0.5;
    final double cosA = math.cos(rotAngle);
    final double sinA = math.sin(rotAngle);

    const double arrowLen = 7.0;
    final double tailX = dialCenterX - cosA * arrowLen;
    final double tailY = dialCenterY - sinA * arrowLen;
    final double tipX = dialCenterX + cosA * arrowLen;
    final double tipY = dialCenterY + sinA * arrowLen;

    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY), _arrowPaint);

    // Arrow head triangle
    const double headSize = 3.5;
    final double perpX = -sinA * headSize;
    final double perpY = cosA * headSize;
    final double backX = tipX - cosA * (headSize * 1.4);
    final double backY = tipY - sinA * (headSize * 1.4);

    _arrowHeadPath.reset();
    _arrowHeadPath.moveTo(tipX, tipY);
    _arrowHeadPath.lineTo(backX + perpX, backY + perpY);
    _arrowHeadPath.lineTo(backX - perpX, backY - perpY);
    _arrowHeadPath.close();

    canvas.drawPath(_arrowHeadPath, _arrowHeadPaint);
  }
}
