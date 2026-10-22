import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';
import '../physics/wind_model.dart';

/// GamePigeon-style wind gauge floating above the target board:
/// a translucent black pill reading "Wind 7 mph" and a white ring
/// holding a solid arrow that points the way the wind blows
/// (up = away from you, right = to the right).
///
/// The arrow is alive: it sways and pulses with the same gusts that push the
/// arrow in flight ([WindModel.getGust]), so what you see is what you get.
///
/// Geometry and text are rebuilt only when the wind value or UI scale change;
/// each frame just re-projects the anchor and draws cached shapes.
class WindPill {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  WindPill({required this.camera, required this.cameraRig});

  /// Caps the gauge on big screens (it scales with the screen otherwise).
  static const double _maxUiScale = 1.25;

  double _time = 0.0;

  void update(double dt) {
    _time += dt;
    if (_time > 1000.0) _time -= 1000.0; // keep sin() arguments small
  }

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
    final TextStyle label = TextStyle(
      color: const Color(0xE6FFFFFF),
      fontSize: 11.0 * ui,
      fontWeight: FontWeight.w600,
    );
    _text = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: 'Wind ', style: label),
          TextSpan(
            text: '${wind.mph}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.0 * ui,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(text: ' mph', style: label),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double padL = 10.0 * ui;
    final double padR = 5.0 * ui;
    final double gap = 6.0 * ui;
    _dialR = 8.5 * ui;
    _pillH = math.max(_text!.height, _dialR * 2.0) + 6.0 * ui;
    final double w = padL + _text!.width + gap + _dialR * 2.0 + padR;

    _pill = RRect.fromLTRBR(-w / 2, -_pillH / 2, w / 2, _pillH / 2, Radius.circular(_pillH / 2));
    _textOffset = Offset(-w / 2 + padL, -_text!.height / 2);
    _dialCenter = Offset(w / 2 - padR - _dialR, 0.0);
    _ringPaint.strokeWidth = 1.6 * ui;
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

    final double ui = math.min(camera.uiScale, _maxUiScale);
    if (_text == null || _lastDisplay != wind.display || _lastUi != ui) {
      _layout(wind, ui);
    }

    canvas.save();
    canvas.translate(camera.sx, camera.sy - _pillH * 0.5 - 10.0 * ui);

    canvas.drawRRect(_pill, _bgPaint);
    _text!.paint(canvas, _textOffset);
    canvas.drawCircle(_dialCenter, _dialR - _ringPaint.strokeWidth * 0.5, _ringPaint);

    // Arrow: angle 0 = blowing away from you (up on screen), π/2 = right.
    // Calm air barely moves it; strong wind sways and surges more.
    final double strength = (wind.display / ArcheryK.windMaxDisplay).clamp(0.0, 1.0);
    final double gust = wind.getGust(_time) - 1.0; // about −0.15..+0.15
    final double sway = (0.06 + 0.10 * strength) *
        math.sin(_time * 2.6 + wind.phi1);
    final double surge = gust * (0.5 + strength) * 0.6; // −0.13..+0.13
    canvas.translate(_dialCenter.dx, _dialCenter.dy);
    canvas.rotate(wind.angle - math.pi * 0.5 + sway);
    canvas.translate(_dialR * surge, 0.0); // nudges along the wind
    canvas.scale(_dialR * (1.15 + surge * 0.4));
    canvas.drawPath(_unitArrow, _arrowPaint);
    canvas.restore();
  }
}
