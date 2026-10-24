import 'dart:math' as math;
import 'dart:ui' as ui;

import '../darts_constants.dart';
import '../scene/board_projection.dart';
import 'dart_sprites.dart';

/// Draws a dart in 3D from the angle-sweep sprite sheet.
///
/// A dart is described by its tip position (physics metres, see
/// [BoardProjection]) and a unit axis pointing from tail to tip. From that:
/// 1. the angle between the line of sight and the axis picks the sheet row
///    (tail-on X → side view),
/// 2. the on-screen direction from tail to tip sets the rotation (the sheet's
///    tip always points up),
/// 3. the distance from the eye sets the size,
/// 4. the frame is pinned by its tip, so a stuck dart's tip sits exactly on
///    the spot it hit.
///
/// Shadows use the side-view frame drawn in black, laid along the dart's
/// shadow on the board plane.
///
/// Shared static paints; no allocations per call.
abstract final class DartRenderer {
  static final ui.Paint _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  static final ui.Paint _shadowPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.low
    ..isAntiAlias = true
    ..colorFilter = const ui.ColorFilter.mode(
      ui.Color(0xFF000000),
      ui.BlendMode.srcIn,
    );

  static const double _radToDeg = 180.0 / math.pi;

  /// Alpha currently set on each paint (-1 = not set yet).
  static int _paintAlpha = -1;
  static int _shadowAlpha = -1;

  /// Draws the dart with its tip at (`tx`, `ty`, `tz`) and unit axis
  /// (`ax`, `ay`, `az`) pointing from tail to tip. [column] is the spin frame.
  /// [extraRotation] (radians) rotates about the tip (impact wobble).
  static void draw3D(
    ui.Canvas c,
    DartSprites s,
    BoardProjection p,
    double tx,
    double ty,
    double tz,
    double ax,
    double ay,
    double az,
    int column, {
    double extraRotation = 0.0,
    double opacity = 1.0,
    double scaleMultiplier = 1.0,
    int? fixedRow,
  }) {
    final double len = DartsK.dartLengthM * scaleMultiplier;

    p.project(tx, ty, tz);
    final double stx = p.outX;
    final double sty = p.outY;
    p.project(tx - ax * len, ty - ay * len, tz - az * len);
    final double slx = p.outX;
    final double sly = p.outY;

    final double mz = tz - az * len * 0.5;

    final int row;
    if (fixedRow != null) {
      row = fixedRow.clamp(0, s.angles.length - 1);
    } else {
      // Line of sight from the eye to the middle of the dart.
      final double mx = tx - ax * len * 0.5;
      final double my = ty - ay * len * 0.5;
      final double vx = mx;
      final double vy = my - p.eyeHeightM;
      final double vz = mz - p.eyeZ;
      final double vl = math.sqrt(vx * vx + vy * vy + vz * vz);
      double cosT = vl > 1e-9 ? (vx * ax + vy * ay + vz * az) / vl : 1.0;
      if (cosT > 1.0) cosT = 1.0;
      if (cosT < -1.0) cosT = -1.0;
      row = s.rowFor(math.acos(cosT) * _radToDeg);
    }

    final double dx = stx - slx;
    final double dy = sty - sly;
    final double rot = (dx * dx + dy * dy) > 1e-6 ? math.atan2(dx, -dy) : 0.0;

    double depth = p.eyeZ - mz;
    if (depth < 0.05) depth = 0.05;
    final double scale = len * p.focalPx / depth / s.fullLengthPx;

    // Only build a new Color when the opacity actually changes (stuck darts
    // fading out); the normal case reuses the paint as it is.
    final int a = (opacity.clamp(0.0, 1.0) * 255.0).round();
    if (a != _paintAlpha) {
      _paintAlpha = a;
      _paint.color = ui.Color.fromARGB(a, 255, 255, 255);
    }
    c.save();
    c.translate(stx, sty);
    c.rotate(rot + extraRotation);
    c.scale(scale);
    c.drawImageRect(
      s.atlasImage,
      s.src[row][column % s.spinColumns],
      s.dstAtTip[row],
      _paint,
    );
    c.restore();
  }

  /// Draws the dart's shadow on the board plane (z = 0), cast along the
  /// light ([DartsK.shadowLightX], [DartsK.shadowLightY], -1). [alpha] is
  /// the shadow's darkness (0..1).
  static void drawShadow(
    ui.Canvas c,
    DartSprites s,
    BoardProjection p,
    double tx,
    double ty,
    double tz,
    double ax,
    double ay,
    double az,
    int column,
    double alpha, {
    double extraRotation = 0.0,
    double scaleMultiplier = 1.0,
  }) {
    if (alpha <= 0.0) return;
    final double len = DartsK.dartLengthM * scaleMultiplier;
    const double lx = DartsK.shadowLightX;
    const double ly = DartsK.shadowLightY;
    final double k = p.mmToPx * 1000.0;

    // Shadow of the tip and of the tail on the board plane (metres).
    final double tz0 = tz < 0.0 ? 0.0 : tz;
    final double sTipX = tx + lx * tz0;
    final double sTipY = ty + ly * tz0;
    final double lz = tz - az * len;
    final double sTailX = (tx - ax * len) + lx * lz;
    final double sTailY = (ty - ay * len) + ly * lz;

    final double px = p.boardCenterX + sTipX * k;
    final double py = p.boardCenterY - sTipY * k;
    final double dx = (sTipX - sTailX) * k;
    final double dy = -(sTipY - sTailY) * k;
    final double l = math.sqrt(dx * dx + dy * dy);
    if (l < 0.5) return;
    // A dart pointing at the wall casts a short shadow; keep at least half
    // a dart's length so it still reads as a dart.
    final double drawLen = math.max(l, len * k * 0.55);

    final int row = s.sideRow;
    final int sa = (alpha.clamp(0.0, 1.0) * 255.0).round();
    if (sa != _shadowAlpha) {
      _shadowAlpha = sa;
      _shadowPaint.color = ui.Color.fromARGB(sa, 0, 0, 0);
    }
    c.save();
    c.translate(px, py);
    c.rotate(math.atan2(dx, -dy) + extraRotation);
    c.scale(drawLen / s.fullLengthPx);
    c.drawImageRect(
      s.atlasImage,
      s.src[row][column % s.spinColumns],
      s.dstAtTip[row],
      _shadowPaint,
    );
    c.restore();
  }
}
