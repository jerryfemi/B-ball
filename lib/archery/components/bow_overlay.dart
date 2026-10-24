import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';
import '../camera/camera_rig.dart';
import '../util/image_loader.dart';

/// The bow and the nocked arrow at the shooting line, framed like GamePigeon
/// (measured from a GamePigeon recording; numbers below are in refW = the
/// camera's reference width, or in screen heights).
///
/// * Bow (`bow_view.webp`, from `tools/make_bow_view.py`): stands right of the
///   target, grip centre +0.25 refW from it, leather grip from 0.457 to 0.748
///   of the screen height. Above the grip the upper limb bends away to the
///   right as it rises; below, it runs straight off the bottom.
/// * Arrow (drawn here, separately): a real arrow pointing into the screen at
///   the target, so it is heavily foreshortened. Its front end sits just left
///   of the grip; you see the steel broadhead edge-on (a thin vertical blade)
///   with the shaft's round front end, and the shaft runs back toward you,
///   thickening, off the bottom-right corner. Fletching is behind the camera.
///
/// Both hang together with a slow hand sway, and slide away together when
/// you start aiming. Paths, rects and gradients are built in [resize]; a frame
/// is a few transforms, one image and five fills.
class BowOverlay {
  final ArcheryCamera camera;
  final CameraRig cameraRig;

  BowOverlay({required this.camera, required this.cameraRig});

  // ── Bow sprite (`sprites/bow_fp_atlas.png`) ─────────────────────────────
  // Rendered from the "Cool Bow" model (Incg5764, CC-BY 4.0) in glb2sprite:
  // upright and nearly edge-on. Measured in the 43x534 image: the rope grip
  // is centred at (13, 310). `bow_fp_wood.png` is the same render with the
  // baked string removed: the string is drawn here instead, from tip to tip
  // through the nocked arrow, on top of it.
  static const String _bowAsset = 'assets/archery/sprites/bow_fp_wood.png';
  static const double _tipTopImgX = 33.0, _tipTopImgY = 8.0;
  static const double _tipBotImgX = 34.0, _tipBotImgY = 526.0;
  static const double _gripImgX = 13.0;
  static const double _gripImgY = 310.0;

  /// Mirrored so the limbs curve away to the right, like GamePigeon's bow.
  static const bool _mirror = true;

  /// Whole bow length on screen, in screen heights (before [_scale]). Big
  /// enough that both tips run off the screen like GamePigeon's framing.
  static const double _bowLengthH = 1.45;

  /// Grip centre height on screen (screen heights), as before.
  static const double _gripCentreY = 0.6025;

  /// Overall size of the bow + arrow, scaled evenly about the grip.
  /// 1.0 = GamePigeon's measured size; 0.75 = 25% smaller.
  static const double _scale = 0.75;
  static const double _gripFromTarget = 0.25; // refW
  static const double _anchorY = 0.60; // pivot for the slide-out (screen h)

  // ── Arrow (refW units unless noted) ─────────────────────────────────────
  static const double _tipFromGrip = -0.102; // tip x, from the grip centre
  static const double _tipY = 0.623; // screen heights
  static const double _shaftAtTip = 0.045; // shaft width at the front end
  static const double _shaftGrowth = 0.053; // extra width per refW of length
  static const double _capRadius = 0.022;
  static const double _bladeHalfH = 0.085;
  static const double _bladeHalfW = 0.009;
  static const double _bladeShiftX = -0.008;

  // ── Idle hand sway ──────────────────────────────────────────────────────
  static const double _swayX = 0.010; // refW
  static const double _swayY = 0.004; // screen heights

  ui.Image? _bow;
  // High: the sprite is scaled up about 2x on phones.
  final Paint _bowPaint = Paint()..filterQuality = FilterQuality.high;
  Rect _src = Rect.zero;
  Rect _dst = Rect.zero; // relative to the anchor

  // String ends (limb tips), relative to the anchor, mirror applied.
  Offset _stringTop = Offset.zero;
  Offset _stringBot = Offset.zero;
  final Path _string = Path();
  final Paint _stringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Path _shaft = Path();
  final Path _bladeLight = Path();
  final Path _bladeDark = Path();
  final Paint _shaftPaint = Paint();
  final Paint _bladeLightPaint = Paint();
  final Paint _bladeDarkPaint = Paint();
  final Paint _capFill = Paint();
  final Paint _capRing = Paint()..style = PaintingStyle.stroke;
  double _capR = 0.0;
  double _vanishToTip = 0.0; // shaft frame: vanishing point → front end

  double _refW = 0.0;
  double _time = 0.0;
  double _lastAlpha = -1.0;

  /// Shaft angle on screen (tip → you), refreshed while standing at the line.
  double _shaftAngle = math.pi * 0.33;

  double screenW = 0.0;
  double screenH = 0.0;
  double slideProgress = 0.0; // 0 = held up at the line, 1 = slid away

  Future<void> load() async {
    _bow = await loadArcheryImage(_bowAsset);
    _layout();
  }

  void resize(double width, double height) {
    screenW = width;
    screenH = height;
    _layout();
  }

  void _layout() {
    final img = _bow;
    if (img == null || screenH <= 0.0) return;
    final double r = math.min(screenW, screenH * ArcheryK.refAspect);
    _refW = r;

    // Anchor = grip centre line at _anchorY. The sprite keeps its own
    // proportions (uniform scale) with its grip on the anchor line.
    _src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final double px = _bowLengthH * screenH / img.height; // screen px per image px
    _dst = Rect.fromLTWH(
      -_gripImgX * px,
      (_gripCentreY - _anchorY) * screenH - _gripImgY * px,
      img.width * px,
      img.height * px,
    );
    final double sx = _mirror ? -1.0 : 1.0;
    _stringTop = Offset(sx * (_dst.left + _tipTopImgX * px), _dst.top + _tipTopImgY * px);
    _stringBot = Offset(sx * (_dst.left + _tipBotImgX * px), _dst.top + _tipBotImgY * px);
    _stringPaint.strokeWidth = math.max(1.2, 0.0045 * r);

    // Shaft frame: origin at the vanishing point of its two edges, shaft
    // along +y. Half width = k·y, so a sweep gradient around the origin wraps
    // exactly across the shaft at every thickness (a round wooden shaft).
    final double k = _shaftGrowth * 0.5;
    _vanishToTip = _shaftAtTip * r / _shaftGrowth;
    final double y0 = _vanishToTip;
    final double y1 = y0 + screenH * 3.0;
    _shaft
      ..reset()
      ..moveTo(-k * y0, y0)
      ..lineTo(k * y0, y0)
      ..lineTo(k * y1, y1)
      ..lineTo(-k * y1, y1)
      ..close();
    final double a = math.atan(k);
    // +x side faces up on screen (the lit side).
    _shaftPaint.shader = ui.Gradient.sweep(
      Offset.zero,
      const [
        Color(0xFF9A5530),
        Color(0xFFDCA078),
        Color(0xFFBE7048),
        Color(0xFF94502C),
        Color(0xFF5E2C14),
      ],
      const [0.0, 0.22, 0.48, 0.78, 1.0],
      TileMode.clamp,
      math.pi * 0.5 - a,
      math.pi * 0.5 + a,
    );

    // Broadhead seen edge-on: a thin vertical blade, lit left, shaded right.
    final double bh = _bladeHalfH * r;
    final double bw = _bladeHalfW * r;
    _bladeLight
      ..reset()
      ..moveTo(0, -bh)
      ..lineTo(-bw, 0)
      ..lineTo(0, bh)
      ..close();
    _bladeDark
      ..reset()
      ..moveTo(0, -bh)
      ..lineTo(bw, 0)
      ..lineTo(0, bh)
      ..close();

    _capR = _capRadius * r;
    _capRing.strokeWidth = 0.0075 * r;
  }

  void update(double dt, {double slide = 0.0}) {
    slideProgress = slide;
    _time += dt;
    if (_time > 1000.0) _time -= 1000.0;
  }

  void _applyAlpha(double a) {
    if (a == _lastAlpha) return;
    _lastAlpha = a;
    _bowPaint.color = Color.fromRGBO(255, 255, 255, a);
    _shaftPaint.color = Color.fromRGBO(0, 0, 0, a); // fades the gradient
    _bladeLightPaint.color = Color.fromRGBO(0xE6, 0xE9, 0xEF, a);
    _bladeDarkPaint.color = Color.fromRGBO(0x93, 0x9A, 0xA6, a);
    _capFill.color = Color.fromRGBO(0xC8, 0x86, 0x5C, a);
    _stringPaint.color = Color.fromRGBO(0x2B, 0x22, 0x1A, a * 0.9);
    _capRing.color = Color.fromRGBO(0xFA, 0xFA, 0xFA, a);
  }

  void render(Canvas canvas) {
    final img = _bow;
    if (img == null || screenW <= 0.0 || slideProgress >= 1.0) return;
    final double r = _refW;

    final double t = slideProgress;
    _applyAlpha((1.0 - t).clamp(0.0, 1.0));

    // Grip centre (anchor) with a slow hand sway.
    final double gx = screenW * 0.5 + _gripFromTarget * r +
        _swayX * r * math.sin(_time * 1.1);
    final double gy = screenH * _anchorY +
        _swayY * screenH * math.sin(_time * 1.7 + 1.0);

    // Arrow front end, relative to the anchor.
    final double tipX = _tipFromGrip * r;
    final double tipY = (_tipY - _anchorY) * screenH;

    // Point the shaft at the target (only re-measured while at the line, so
    // it doesn't swing while the camera dollies).
    if (cameraRig.phase == ShotPhase.atLine &&
        camera.project(0.0, ArcheryK.targetCenterY, cameraRig.targetDistance)) {
      _shaftAngle = math.atan2(
        gy + tipY * _scale - camera.sy,
        gx + tipX * _scale - camera.sx,
      );
    }

    canvas.save();
    canvas.translate(gx + t * screenW * 0.35, gy + t * screenH * 0.45);
    final double scale = (1.0 + t * 0.15) * _scale;
    canvas.scale(scale, scale);

    // 1. Bow (mirrored about the grip line, see [_mirror])
    if (_mirror) {
      canvas.save();
      canvas.scale(-1.0, 1.0);
      canvas.drawImageRect(img, _src, _dst, _bowPaint);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, _src, _dst, _bowPaint);
    }

    // 2. Arrow: blade (behind), shaft, then the shaft's round front end.
    canvas.save();
    canvas.translate(tipX + _bladeShiftX * r, tipY);
    canvas.drawPath(_bladeLight, _bladeLightPaint);
    canvas.drawPath(_bladeDark, _bladeDarkPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(tipX, tipY);
    canvas.rotate(_shaftAngle - math.pi * 0.5);
    canvas.translate(0.0, -_vanishToTip);
    canvas.drawPath(_shaft, _shaftPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(tipX, tipY);
    canvas.drawCircle(Offset.zero, _capR, _capFill);
    canvas.drawCircle(Offset.zero, _capR, _capRing);
    canvas.restore();

    // 3. String: tip → arrow → tip, over the arrow, so it reads as nocked.
    _string
      ..reset()
      ..moveTo(_stringTop.dx, _stringTop.dy)
      ..lineTo(tipX, tipY)
      ..lineTo(_stringBot.dx, _stringBot.dy);
    canvas.drawPath(_string, _stringPaint);

    canvas.restore();
  }
}
