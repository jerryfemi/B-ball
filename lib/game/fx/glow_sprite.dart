import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared "fake bloom" helper: one cached soft radial sprite, tinted per
/// streak tier and blended additively, so glowing things (the burning ball,
/// sparks, the fire light on the floor) look like they emit light.
///
/// Real bloom needs extra full-screen blur passes every frame, which mobile
/// GPUs can't afford. A pre-blurred sprite gives the same read for the cost
/// of one small textured quad per glow.
///
/// Zero allocations per draw: the sprite is built once, every tint×alpha
/// combination is a precomputed [ColorFilter], and positioning uses canvas
/// translate/scale instead of new Rects.
class GlowSprite {
  GlowSprite._();

  static const int _size = 64;
  static const double _half = _size / 2.0;
  static const int alphaSteps = 32;

  /// Tint per streak tier index (none, lightning, fire, inferno).
  static const List<Color> tierColors = [
    Color(0xFFFFFFFF),
    Color(0xFF38BDF8), // electric sky blue
    Color(0xFFFF8A1E), // flame orange
    Color(0xFFFF4A1F), // inferno red-orange
  ];

  static ui.Image? _sprite;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.low
    ..blendMode = BlendMode.plus;

  /// [tier][alphaStep] → ColorFilter tinting the white sprite.
  static final List<List<ColorFilter>> _filters = List.generate(
    tierColors.length,
    (t) => List.generate(
      alphaSteps,
      (a) => ColorFilter.mode(
        tierColors[t].withValues(alpha: a / (alphaSteps - 1)),
        BlendMode.srcIn,
      ),
      growable: false,
    ),
    growable: false,
  );

  static void _ensureSprite() {
    if (_sprite != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Gaussian-like falloff: bright core, long soft tail (reads as light
    // scattering rather than a hard colored disc).
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_half, _half),
        _half,
        const [
          Color(0xFFFFFFFF),
          Color(0x8CFFFFFF),
          Color(0x2EFFFFFF),
          Color(0x00FFFFFF),
        ],
        const [0.0, 0.3, 0.62, 1.0],
      );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _size * 1.0, _size * 1.0),
      paint,
    );
    final picture = recorder.endRecording();
    _sprite = picture.toImageSync(_size, _size);
    picture.dispose();
  }

  /// Additively draws a glow centered at ([cx], [cy]) spanning [w]×[h]
  /// (canvas units), tinted by streak [tier] at [alpha] (0..1).
  static void draw(
    Canvas canvas,
    double cx,
    double cy,
    double w,
    double h,
    int tier,
    double alpha,
  ) {
    if (alpha <= 0.01) return;
    _ensureSprite();
    final sprite = _sprite;
    if (sprite == null) return;
    final t = tier.clamp(0, tierColors.length - 1).toInt();
    final step = (alpha.clamp(0.0, 1.0) * (alphaSteps - 1)).round();
    _paint.colorFilter = _filters[t][step];
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(w / _size, h / _size);
    canvas.drawImage(sprite, const Offset(-_half, -_half), _paint);
    canvas.restore();
  }
}
