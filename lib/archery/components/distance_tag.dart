import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';

/// Red "50ft" tag lying on the shooting line, left of the lane (GamePigeon).
/// World-anchored, so it slides away naturally as the camera moves forward.
class DistanceTag {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  DistanceTag({required this.camera, required this.cameraRig});

  /// World anchor: on the painted shooting line, left of the centre line.
  /// (Must match the line position in shaders/archery_ground.frag.)
  static const double _x = -0.9;
  static const double _z = ArcheryK.shootingLineZ;

  final Paint _bgPaint = Paint()..color = const Color(0xFFDC2626);
  final Paint _shadowPaint = Paint()..color = const Color(0x55000000);

  TextPainter? _text;
  double _textScale = 0.0;
  RRect _box = RRect.zero;
  RRect _shadowBox = RRect.zero;
  Offset _textOffset = Offset.zero;
  double _w = 0.0;
  double _h = 0.0;

  void render(Canvas canvas) {
    final phase = cameraRig.phase;
    if (phase != ShotPhase.atLine && phase != ShotPhase.returning) return;
    if (!camera.project(_x, 0.0, _z)) return;
    if (camera.sy > camera.screenH + 40.0) return;

    final double ui = camera.uiScale;
    if (_text == null || _textScale != ui) {
      _textScale = ui;
      _text = TextPainter(
        text: TextSpan(
          text: ArcheryK.distanceLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.0 * ui,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Geometry depends only on the text and UI scale: build it once here.
      final double padH = 9.0 * ui;
      final double padV = 4.0 * ui;
      _w = _text!.width + padH * 2.0;
      _h = _text!.height + padV * 2.0;
      _box = RRect.fromLTRBR(0, 0, _w, _h, Radius.circular(3.0 * ui));
      _shadowBox = _box.shift(Offset(0, 2.0 * ui));
      _textOffset = Offset(padH, padV);
    }

    // Tag sits on the line: bottom edge at the projected ground point.
    canvas.save();
    canvas.translate(camera.sx - _w * 0.5, camera.sy - _h);
    canvas.drawRRect(_shadowBox, _shadowPaint);
    canvas.drawRRect(_box, _bgPaint);
    _text!.paint(canvas, _textOffset);
    canvas.restore();
  }
}
