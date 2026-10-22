import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

/// 80 cm World Archery face on a 1.0 m square white board with a wooden
/// A-frame stand.
///
/// Sharpness: the rings are drawn as real circles every frame, at the size
/// they appear on screen, so their edges stay crisp at any distance (an
/// image shrunk from 1024 px blurs the thin ring lines). Only the soft gloss
/// (sheen and highlight) is a cached picture, because it has no hard edges.
///
/// Cost: about 15 simple draws a frame. Everything is drawn in local units
/// through canvas transforms, so no Rect, Offset or Paint is created per
/// frame.
class TargetBoard {
  final ArcheryCamera camera;

  TargetBoard({required this.camera, double initialDistance = ArcheryK.distanceM})
      : distance = initialDistance;

  /// Current distance from archer in meters (e.g. 15.24m / 50ft).
  double distance;

  // --- Cached Paints ---
  final Paint _whiteBoardPaint = Paint()..color = const Color(0xFFF8FAFC);
  final Paint _boardFramePaint = Paint()..color = const Color(0xFF5C3D22);
  final Paint _screwPaint = Paint()..color = const Color(0xFF261D15);
  final Paint _screwHeadPaint = Paint()
    ..color = const Color(0xFF785538)
    ..style = PaintingStyle.stroke;
  final Paint _woodLegPaint = Paint()
    ..color = const Color(0xFF5C3D22)
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;
  final Paint _woodCrossPaint = Paint()
    ..color = const Color(0xFF432C18)
    ..style = PaintingStyle.stroke;
  final Paint _woodStrutPaint = Paint()
    ..color = const Color(0xFF3A2614)
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;
  // Ground contact shadow: three stacked ovals fake a soft edge without a blur.
  final Paint _shadowPaint = Paint()..color = const Color(0x1A000000);

  // Face (unit space: the face radius is 1.0)
  final Paint _ringFill = Paint()..style = PaintingStyle.fill;
  final Paint _ringLine = Paint()..style = PaintingStyle.stroke;
  final Paint _glossPaint = Paint()..filterQuality = FilterQuality.medium;

  /// Reused for every straight line of the stand.
  final Path _line = Path();

  // Ring colours, outside in (each colour covers two scoring rings).
  static const List<Color> _zoneColors = [
    Color(0xFFF5F5F0), // 1–2 white
    Color(0xFF1A1A1A), // 3–4 black
    Color(0xFF2E7DD7), // 5–6 blue
    Color(0xFFE0322B), // 7–8 red
    Color(0xFFF7D000), // 9–10 gold
  ];
  static const Color _lineDark = Color(0x66000000);
  static const Color _lineLight = Color(0x66FFFFFF);

  static const Rect _unitSquare = Rect.fromLTRB(-1, -1, 1, 1);
  static const Rect _boardOuter = Rect.fromLTRB(
    -ArcheryK.boardWidth * 0.5,
    -ArcheryK.boardHeight * 0.5,
    ArcheryK.boardWidth * 0.5,
    ArcheryK.boardHeight * 0.5,
  );
  static const Rect _boardInner = Rect.fromLTRB(
    -ArcheryK.boardWidth * 0.5 + ArcheryK.boardFrame,
    -ArcheryK.boardHeight * 0.5 + ArcheryK.boardFrame,
    ArcheryK.boardWidth * 0.5 - ArcheryK.boardFrame,
    ArcheryK.boardHeight * 0.5 - ArcheryK.boardFrame,
  );
  static const double _screwInset = ArcheryK.boardFrame * 0.5;
  static const List<Offset> _screws = [
    Offset(-ArcheryK.boardWidth * 0.5 + _screwInset, -ArcheryK.boardHeight * 0.5 + _screwInset),
    Offset(ArcheryK.boardWidth * 0.5 - _screwInset, -ArcheryK.boardHeight * 0.5 + _screwInset),
    Offset(-ArcheryK.boardWidth * 0.5 + _screwInset, ArcheryK.boardHeight * 0.5 - _screwInset),
    Offset(ArcheryK.boardWidth * 0.5 - _screwInset, ArcheryK.boardHeight * 0.5 - _screwInset),
  ];

  // --- Cached gloss overlay ---
  ui.Image? _gloss;
  Rect _glossSrc = Rect.zero;
  bool _glossStarted = false;

  void dispose() {
    _gloss?.dispose();
    _gloss = null;
  }

  void render(Canvas canvas) {
    // 1. Project target center
    if (!camera.project(0.0, ArcheryK.targetCenterY, distance)) return;
    final double cx = camera.sx;
    final double cy = camera.sy;
    final double depth = camera.depth;
    final double pxPerM = camera.pxPerMeterAt(depth);
    if (pxPerM <= 0.5) return;

    // Stand stroke widths scale with distance.
    _woodLegPaint.strokeWidth = pxPerM * 0.05;
    _woodCrossPaint.strokeWidth = pxPerM * 0.035;
    _woodStrutPaint.strokeWidth = pxPerM * 0.035;

    _renderGroundShadow(canvas);
    _renderStand(canvas);
    _renderBoard(canvas, cx, cy, pxPerM);
    _renderFace(canvas, cx, cy, pxPerM * ArcheryK.faceRadius);
  }

  void _renderGroundShadow(Canvas canvas) {
    // Front edge (toward the archer) and back edge (under the rear strut).
    if (!camera.project(-0.62, 0.0, distance - 0.12)) return;
    final double left = camera.sx;
    final double bottom = camera.sy;
    if (!camera.project(0.62, 0.0, distance - 0.12)) return;
    final double right = camera.sx;
    if (!camera.project(0.0, 0.0, distance + 0.80)) return;
    final double top = camera.sy;

    final double w = right - left;
    final double h = bottom - top;
    if (w < 2.0) return;
    // Outer, middle and inner ovals; overlaps darken toward the centre.
    for (int i = 0; i < 3; i++) {
      final double inset = i * 0.14;
      final double l = left + w * inset;
      final double r = right - w * inset;
      final double t = top + h * inset;
      final double b = bottom - h * inset * 0.6;
      canvas.save();
      canvas.translate((l + r) * 0.5, (t + b) * 0.5);
      canvas.scale((r - l) * 0.5, (b - t) * 0.5);
      canvas.drawOval(_unitSquare, _shadowPaint);
      canvas.restore();
    }
  }

  void _renderStand(Canvas canvas) {
    const double legTopY = ArcheryK.targetCenterY - ArcheryK.boardHeight * 0.4;
    const double halfLegX = ArcheryK.boardWidth * 0.38;

    // Rear support strut first (behind everything), thinner and darker so it
    // reads as depth instead of a third front leg.
    _drawLine3D(canvas, 0.0, legTopY, distance + 0.02, 0.0, 0.0, distance + 0.70, _woodStrutPaint);
    // Left and right legs extending down to the ground.
    _drawLine3D(canvas, -halfLegX, legTopY, distance, -halfLegX - 0.05, 0.0, distance - 0.05,
        _woodLegPaint);
    _drawLine3D(canvas, halfLegX, legTopY, distance, halfLegX + 0.05, 0.0, distance - 0.05,
        _woodLegPaint);
    // Cross-brace between the front legs.
    _drawLine3D(canvas, -halfLegX - 0.02, 0.38, distance - 0.03, halfLegX + 0.02, 0.38,
        distance - 0.03, _woodCrossPaint);
  }

  void _drawLine3D(
    Canvas canvas,
    double x1,
    double y1,
    double z1,
    double x2,
    double y2,
    double z2,
    Paint paint,
  ) {
    if (!camera.project(x1, y1, z1)) return;
    final double sx1 = camera.sx;
    final double sy1 = camera.sy;
    if (!camera.project(x2, y2, z2)) return;
    _line
      ..reset()
      ..moveTo(sx1, sy1)
      ..lineTo(camera.sx, camera.sy);
    canvas.drawPath(_line, paint);
  }

  /// White board, wooden frame and corner screws, drawn in metres around
  /// the board centre.
  void _renderBoard(Canvas canvas, double cx, double cy, double pxPerM) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(pxPerM);
    canvas.drawRect(_boardOuter, _boardFramePaint);
    canvas.drawRect(_boardInner, _whiteBoardPaint);

    final double screwR = (ArcheryK.boardFrame * pxPerM * 0.30).clamp(1.5, 6.0) / pxPerM;
    _screwHeadPaint.strokeWidth = 1.0 / pxPerM;
    for (final Offset s in _screws) {
      canvas.drawCircle(s, screwR, _screwPaint);
      _line
        ..reset()
        ..moveTo(s.dx - screwR * 0.6, s.dy)
        ..lineTo(s.dx + screwR * 0.6, s.dy);
      canvas.drawPath(_line, _screwHeadPaint);
    }
    canvas.restore();
  }

  /// The face: five colour zones, the ring lines, the X ring and the centre
  /// cross, in unit space (radius 1.0 = the face edge).
  void _renderFace(Canvas canvas, double cx, double cy, double faceR) {
    if (faceR < 2.0) return;
    if (!_glossStarted) _buildGloss();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(faceR);

    for (int i = 0; i < 5; i++) {
      _ringFill.color = _zoneColors[i];
      canvas.drawCircle(Offset.zero, 1.0 - i * 0.2, _ringFill);
    }

    // Ring lines only where they are at least about a pixel apart.
    if (faceR >= 14.0) {
      _ringLine.strokeWidth = (faceR * 0.006).clamp(0.6, 2.0) / faceR;
      for (int i = 0; i < 10; i++) {
        // Lines inside the black zone are light; the rest dark.
        _ringLine.color = (i == 2 || i == 3) ? _lineLight : _lineDark;
        canvas.drawCircle(Offset.zero, 1.0 - i * 0.1, _ringLine);
      }
      _ringLine.color = const Color(0x88000000);
      canvas.drawCircle(
          Offset.zero, ArcheryK.xRingRadius / ArcheryK.faceRadius, _ringLine);
      if (faceR >= 40.0) {
        const double c = 0.01 / ArcheryK.faceRadius;
        _line
          ..reset()
          ..moveTo(-c, 0)
          ..lineTo(c, 0)
          ..moveTo(0, -c)
          ..lineTo(0, c);
        canvas.drawPath(_line, _ringLine);
      }
    }

    // Soft gloss over the top (no hard edges, so the cached picture is fine).
    final ui.Image? gloss = _gloss;
    if (gloss != null) {
      canvas.drawImageRect(gloss, _glossSrc, _unitSquare, _glossPaint);
    }
    canvas.restore();
  }

  /// Glossy laminated finish (GamePigeon): light from the upper left. Drawn
  /// once into a small picture; it is all soft gradients.
  void _buildGloss() {
    _glossStarted = true;
    const int size = 256;
    const double r = size * 0.5;
    const Offset center = Offset(r, r);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder, const Rect.fromLTWH(0, 0, 256.0, 256.0));
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // Broad sheen: lighter top-left, slightly darker bottom-right.
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(r * 2, r * 2),
          const [Color(0x30FFFFFF), Color(0x00FFFFFF), Color(0x1E000000)],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Soft specular hotspot.
    const Offset hot = Offset(r * 0.62, r * 0.55);
    c.drawCircle(
      hot,
      r * 0.62,
      Paint()
        ..shader = ui.Gradient.radial(
          hot,
          r * 0.62,
          const [Color(0x47FFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)],
          const [0.0, 0.45, 1.0],
        ),
    );
    // Thin rim shadow so the face sits on the board.
    c.drawCircle(
      center,
      r * 0.995,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012
        ..color = const Color(0x33000000),
    );

    final ui.Picture picture = recorder.endRecording();
    picture.toImage(size, size).then((ui.Image img) {
      picture.dispose();
      _gloss?.dispose();
      _gloss = img;
      _glossSrc = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    });
  }
}
