import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../util/image_loader.dart';
import 'arrow_renderer.dart';

/// Foreground bow held at the right edge of the screen with a nocked 3D arrow
/// pointing at the target (GamePigeon framing).
///
/// The bow image is a side profile with its arrow shelf on the image's right.
/// It is mirrored so the shelf faces the target side of the screen, tilted so
/// the top limb leans toward the target, and anchored by its grip so the lower
/// limb runs off the bottom of the screen.
///
/// The nocked arrow is drawn with [ArrowRenderer3D] (same look as the arrow in
/// flight): its nock is lifted into 3D just in front of the camera on the line
/// target → shelf, so it rests on the shelf and points exactly at the target.
class BowOverlay {
  final ArcheryCamera camera;

  BowOverlay({required this.camera});

  // Anchor points in the cropped bow image (fractions of width / height).
  static const double _gripFx = 0.38;
  static const double _gripFy = 0.53;
  static const double _shelfFx = 0.62;
  static const double _shelfFy = 0.465;

  /// Tilt: negative = top limb leans toward the screen centre (the target).
  static const double _tiltRad = -11.0 * math.pi / 180.0;

  /// Where the nock sits on the target→shelf line, as a multiple of the
  /// target→shelf distance (>1 = beyond the shelf, lower right, near the camera).
  static const double _nockLineFactor = 1.35;

  /// Depth of the nock in front of the camera (m).
  static const double _nockDepth = 0.45;

  ui.Image? _bowImage;
  final Paint _bowPaint = Paint()..filterQuality = FilterQuality.medium;

  Rect _srcRect = Rect.zero;
  Rect _dstRect = Rect.zero;
  double _bowW = 0.0;
  double _bowH = 0.0;

  double screenW = 0.0;
  double screenH = 0.0;
  double slideProgress = 0.0; // 0 = visible at the line, 1 = slid out

  // Shelf position on screen (updated every render; used for the arrow).
  double _shelfSx = 0.0;
  double _shelfSy = 0.0;

  Future<void> load() async {
    _bowImage = await loadArcheryImage('assets/archery/bow_recurve.webp');
    _layout();
  }

  void resize(double width, double height) {
    screenW = width;
    screenH = height;
    _layout();
  }

  /// Rects only change with screen size, so build them here, not per frame.
  void _layout() {
    final img = _bowImage;
    if (img == null || screenH <= 0.0) return;
    final double imgW = img.width.toDouble();
    final double imgH = img.height.toDouble();
    _bowH = screenH * 1.05 * camera.uiScale.clamp(0.9, 1.2);
    _bowW = _bowH * imgW / imgH;
    _srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
    // Grip point sits at the local origin.
    _dstRect = Rect.fromLTWH(-_bowW * _gripFx, -_bowH * _gripFy, _bowW, _bowH);
  }

  void update(double dt, {double slide = 0.0}) {
    slideProgress = slide;
  }

  void render(Canvas canvas) {
    final img = _bowImage;
    if (img == null || screenW <= 0.0 || slideProgress >= 1.0) return;

    final double alpha = (1.0 - slideProgress).clamp(0.0, 1.0);
    final double scale = 1.0 + slideProgress * 0.15;
    final double anchorX = screenW * 0.86 + slideProgress * screenW * 0.35;
    final double anchorY = screenH * 0.70 + slideProgress * screenH * 0.45;

    // 1. Bow image: translate → rotate → mirror, grip at the anchor.
    _bowPaint.color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.save();
    canvas.translate(anchorX, anchorY);
    canvas.rotate(_tiltRad);
    canvas.scale(-scale, scale);
    canvas.drawImageRect(img, _srcRect, _dstRect, _bowPaint);
    canvas.restore();

    // 2. Shelf point through the same transform (S then R then T).
    final double lx = -scale * (_shelfFx - _gripFx) * _bowW; // mirrored
    final double ly = scale * (_shelfFy - _gripFy) * _bowH;
    final double c = math.cos(_tiltRad);
    final double s = math.sin(_tiltRad);
    _shelfSx = anchorX + c * lx - s * ly;
    _shelfSy = anchorY + s * lx + c * ly;

    // 3. Nocked arrow, drawn over the shelf.
    _renderNockedArrow(canvas, alpha);
  }

  void _renderNockedArrow(Canvas canvas, double alpha) {
    if (!camera.project(0.0, ArcheryK.targetCenterY, ArcheryK.distanceM)) return;
    final double tSx = camera.sx;
    final double tSy = camera.sy;

    // Nock on the target→shelf line, beyond the shelf.
    final double nSx = tSx + (_shelfSx - tSx) * _nockLineFactor;
    final double nSy = tSy + (_shelfSy - tSy) * _nockLineFactor;

    // Lift that screen point into 3D at _nockDepth in front of the camera.
    final double f = camera.focal;
    if (f <= 0.0) return;
    final double nx = camera.eyeX + (nSx - camera.opticalCenterX) * _nockDepth / f;
    final double ny = camera.eyeY - (nSy - camera.opticalCenterY) * _nockDepth / f;
    final double nz = camera.eyeZ + _nockDepth;

    // Unit direction toward the target centre.
    double fx = 0.0 - nx;
    double fy = ArcheryK.targetCenterY - ny;
    double fz = ArcheryK.distanceM - nz;
    final double len = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (len < 1e-6) return;
    fx /= len;
    fy /= len;
    fz /= len;

    const double l = ArcheryK.arrowLength;
    ArrowRenderer3D.render(
      canvas: canvas,
      camera: camera,
      tipX: nx + fx * l,
      tipY: ny + fy * l,
      tipZ: nz + fz * l,
      forwardX: fx,
      forwardY: fy,
      forwardZ: fz,
      // Index vane up, the other two below either side (how an arrow is nocked).
      roll: math.pi * 0.5,
      opacity: alpha,
    );
  }
}
