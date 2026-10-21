import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';
import '../physics/wind_model.dart';

/// GamePigeon-style wind gauge floating above the target board:
/// a translucent black pill with bold white "WIND: 0.8" and a white ring
/// holding a solid arrow that points the way the wind blows
/// (up = away from you, right = to the right).
///
/// Geometry and text are rebuilt only when the wind value or UI scale change;
/// each frame just re-projects the anchor and draws cached shapes.
class WindPill {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  WindPill({required this.camera, required this.cameraRig});

  final Paint _bgPaint = Paint()..color = const Color(0x8C000000);
  final Paint _ringPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke;
  final Paint _arrowPaint = Paint()..color = Colors.white;

  /// Arrow drawn in a unit space (pointing +x) and scaled at draw time.
  static final Path _unitArrow = Path()
    ..moveTo(0.62, 0.0) // tip
    ..lineTo(0.08, -0.36)
    ..lineTo(0.08, -0.12)
    ..lineTo(-0.58, -0.12)
    ..lineTo(-0.58, 0.12)
    ..lineTo(0.08, 0.12)
    ..lineTo(0.08, 0.36)
    ..close();

  TextPainter? _text;
  double _lastDisplay = -1.0;
  double _lastUi = -1.0;

  // Cached layout (pill centred on the origin)
  RRect _pill = RRect.zero;
  Offset _textOffset = Offset.zero;
  Offset _dialCenter = Offset.zero;
  double _dialR = 0.0;
  double _pillH = 0.0;

  void _layout(WindModel wind, double ui) {
    _lastDisplay = wind.display;
    _lastUi = ui;
    _text = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'WIND: ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.0 * ui,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          TextSpan(
            text: wind.display.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.0 * ui,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double padL = 12.0 * ui;
    final double padR = 6.0 * ui;
    final double gap = 8.0 * ui;
    _dialR = 11.0 * ui;
    _pillH = math.max(_text!.height, _dialR * 2.0) + 8.0 * ui;
    final double w = padL + _text!.width + gap + _dialR * 2.0 + padR;

    _pill = RRect.fromLTRBR(-w / 2, -_pillH / 2, w / 2, _pillH / 2, Radius.circular(_pillH / 2));
    _textOffset = Offset(-w / 2 + padL, -_text!.height / 2);
    _dialCenter = Offset(w / 2 - padR - _dialR, 0.0);
    _ringPaint.strokeWidth = 2.0 * ui;
  }

  void render(Canvas canvas, WindModel wind) {
    final ShotPhase phase = cameraRig.phase;
    if (phase != ShotPhase.atLine &&
        phase != ShotPhase.raising &&
        phase != ShotPhase.aiming &&
        phase != ShotPhase.returning) {
      return;
    }

    // Anchor at the board's top edge, then lift by pixels so it never overlaps
    // the small far targets.
    final double boardTopY = ArcheryK.targetCenterY + ArcheryK.boardHeight * 0.5;
    if (!camera.project(0.0, boardTopY, cameraRig.targetDistance)) return;

    final double ui = camera.uiScale;
    if (_text == null || _lastDisplay != wind.display || _lastUi != ui) {
      _layout(wind, ui);
    }

    canvas.save();
    canvas.translate(camera.sx, camera.sy - _pillH * 0.5 - 12.0 * ui);

    canvas.drawRRect(_pill, _bgPaint);
    _text!.paint(canvas, _textOffset);
    canvas.drawCircle(_dialCenter, _dialR - _ringPaint.strokeWidth * 0.5, _ringPaint);

    // Arrow: angle 0 = blowing away from you (up on screen), π/2 = right.
    canvas.translate(_dialCenter.dx, _dialCenter.dy);
    canvas.rotate(wind.angle - math.pi * 0.5);
    canvas.scale(_dialR * 1.15);
    canvas.drawPath(_unitArrow, _arrowPaint);
    canvas.restore();
  }
}
