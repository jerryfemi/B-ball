import 'dart:ui' as ui;

/// High-performance zero-allocation renderer for 3D dart sprites.
///
/// Follows DARTS_PLAN.md Step 10:
/// - Transforms and renders a pre-rendered dart sprite cell from the atlas.
/// - Anchor is centered at the dart's tip: `dstAtOrigin = Rect.fromLTWH(-w/2, 0, w, h)`.
/// - Single shared static `Paint` with `FilterQuality.medium`.
/// - Zero per-frame object allocations.
abstract final class DartRenderer {
  static final ui.Paint _defaultPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  /// Renders a dart sprite frame at `(cx, cy)` with rotation [angle] (radians)
  /// and uniform [scale] relative to cell dimensions.
  ///
  /// Guarantees zero heap allocations per call.
  static void draw(
    ui.Canvas c,
    ui.Image sheet,
    ui.Rect src,
    double cx,
    double cy,
    double scale,
    double angle,
    ui.Rect dstAtOrigin, [
    ui.Paint? paint,
  ]) {
    c.save();
    c.translate(cx, cy);
    if (angle != 0.0) {
      c.rotate(angle);
    }
    c.scale(scale);
    c.drawImageRect(sheet, src, dstAtOrigin, paint ?? _defaultPaint);
    c.restore();
  }
}
