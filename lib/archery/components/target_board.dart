import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

/// 80 cm World Archery regulation target on 1.0m square white board with wooden A-frame stand.
///
/// Performance:
/// - Target face is procedurally rasterized once at 1024x1024 and cached as a [ui.Image].
/// - Legs and cross-brace scale dynamically with pxPerM for realistic thickness.
/// - 0 heap allocations per render frame.
class TargetBoard {
  final ArcheryCamera camera;

  TargetBoard({required this.camera, double initialDistance = ArcheryK.distanceM})
      : distance = initialDistance;

  /// Current distance from archer in meters (e.g. 15.24m / 50ft).
  double distance;

  // --- Cached Paints ---
  final Paint _whiteBoardPaint = Paint()..color = const Color(0xFFF8FAFC);
  final Paint _boardFramePaint = Paint()
    ..color = const Color(0xFF5C3D22)
    ..style = PaintingStyle.fill;
  final Paint _screwPaint = Paint()
    ..color = const Color(0xFF261D15)
    ..style = PaintingStyle.fill;
  final Paint _screwHeadPaint = Paint()
    ..color = const Color(0xFF785538)
    ..strokeWidth = 1.0
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
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  // Ground contact shadow: three stacked ovals fake a soft edge without a blur.
  final Paint _shadowPaint = Paint()..color = const Color(0x1A000000);

  // --- Target Face ui.Image Cache ---
  ui.Image? _cachedFaceImage;
  bool _hasRasterized = false;

  void dispose() {
    _cachedFaceImage?.dispose();
    _cachedFaceImage = null;
  }

  void render(Canvas canvas) {
    // 1. Project target center
    if (!camera.project(0.0, ArcheryK.targetCenterY, distance)) return;
    final double cx = camera.sx;
    final double cy = camera.sy;
    final double depth = camera.depth;
    final double pxPerM = camera.pxPerMeterAt(depth);
    if (pxPerM <= 0.5) return;

    // Dynamically scale stand stroke widths with distance (§2 #9)
    _woodLegPaint.strokeWidth = pxPerM * 0.05;
    _woodCrossPaint.strokeWidth = pxPerM * 0.035;
    _woodStrutPaint.strokeWidth = pxPerM * 0.035;

    // 2. Soft shadow where the stand meets the grass
    _renderGroundShadow(canvas);

    // 3. Render Wooden A-Frame Stand behind the board
    _renderStand(canvas, depth);

    // 4. Render 1.0m x 1.0m White Board & Wooden Frame
    _renderBoss(canvas, cx, cy, pxPerM);

    // 5. Render 80cm WA Target Face (Cached)
    _renderTargetFace(canvas, cx, cy, pxPerM);
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
      canvas.drawOval(
        Rect.fromLTRB(
          left + w * inset,
          top + h * inset,
          right - w * inset,
          bottom - h * inset * 0.6,
        ),
        _shadowPaint,
      );
    }
  }

  void _renderStand(Canvas canvas, double depth) {
    const double legTopY = ArcheryK.targetCenterY - ArcheryK.boardHeight * 0.4;
    const double halfLegX = ArcheryK.boardWidth * 0.38;

    // Rear support strut first (behind everything), thinner and darker so it
    // reads as depth instead of a third front leg.
    _draw3DLeg(canvas, 0.0, legTopY, distance + 0.02, 0.0, 0.0, distance + 0.70,
        paint: _woodStrutPaint);
    // Left and right legs extending down to ground (Y = 0)
    _draw3DLeg(canvas, -halfLegX, legTopY, distance, -halfLegX - 0.05, 0.0, distance - 0.05);
    _draw3DLeg(canvas, halfLegX, legTopY, distance, halfLegX + 0.05, 0.0, distance - 0.05);

    // Cross-brace between front legs at Y = 0.38m
    if (camera.project(-halfLegX - 0.02, 0.38, distance - 0.03)) {
      final double x1 = camera.sx;
      final double y1 = camera.sy;
      if (camera.project(halfLegX + 0.02, 0.38, distance - 0.03)) {
        final double x2 = camera.sx;
        final double y2 = camera.sy;
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _woodCrossPaint);
      }
    }
  }

  void _draw3DLeg(
    Canvas canvas,
    double x1,
    double y1,
    double z1,
    double x2,
    double y2,
    double z2, {
    Paint? paint,
  }) {
    if (!camera.project(x1, y1, z1)) return;
    final double sx1 = camera.sx;
    final double sy1 = camera.sy;

    if (!camera.project(x2, y2, z2)) return;
    final double sx2 = camera.sx;
    final double sy2 = camera.sy;

    canvas.drawLine(Offset(sx1, sy1), Offset(sx2, sy2), paint ?? _woodLegPaint);
  }

  void _renderBoss(Canvas canvas, double cx, double cy, double pxPerM) {
    final double halfW = pxPerM * (ArcheryK.boardWidth * 0.5);
    final double halfH = pxPerM * (ArcheryK.boardHeight * 0.5);
    final double framePx = pxPerM * ArcheryK.boardFrame;

    final Rect outerRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: halfW * 2.0,
      height: halfH * 2.0,
    );

    // 1. Draw outer brown wooden frame
    canvas.drawRect(outerRect, _boardFramePaint);

    // 2. Draw inner square white board
    final Rect innerRect = Rect.fromLTRB(
      outerRect.left + framePx,
      outerRect.top + framePx,
      outerRect.right - framePx,
      outerRect.bottom - framePx,
    );
    canvas.drawRect(innerRect, _whiteBoardPaint);

    // 3. Draw dark screws in the 4 corners of the wooden frame
    final double screwInset = framePx * 0.5;
    final double screwRadius = (framePx * 0.30).clamp(1.5, 6.0);

    final double xLeft = outerRect.left + screwInset;
    final double xRight = outerRect.right - screwInset;
    final double yTop = outerRect.top + screwInset;
    final double yBottom = outerRect.bottom - screwInset;

    _drawScrew(canvas, xLeft, yTop, screwRadius);
    _drawScrew(canvas, xRight, yTop, screwRadius);
    _drawScrew(canvas, xLeft, yBottom, screwRadius);
    _drawScrew(canvas, xRight, yBottom, screwRadius);
  }

  void _drawScrew(Canvas canvas, double x, double y, double radius) {
    canvas.drawCircle(Offset(x, y), radius, _screwPaint);
    canvas.drawLine(
      Offset(x - radius * 0.6, y),
      Offset(x + radius * 0.6, y),
      _screwHeadPaint,
    );
  }

  void _renderTargetFace(Canvas canvas, double cx, double cy, double pxPerM) {
    final double faceRadiusPx = pxPerM * ArcheryK.faceRadius;
    if (faceRadiusPx < 2.0) return;

    if (_cachedFaceImage == null && !_hasRasterized) {
      _rasterizeFace();
    }

    if (_cachedFaceImage != null) {
      final Rect dst = Rect.fromCenter(
        center: Offset(cx, cy),
        width: faceRadiusPx * 2.0,
        height: faceRadiusPx * 2.0,
      );
      final Rect src = Rect.fromLTWH(
        0,
        0,
        _cachedFaceImage!.width.toDouble(),
        _cachedFaceImage!.height.toDouble(),
      );
      canvas.drawImageRect(_cachedFaceImage!, src, dst, _imagePaint);
    }
  }

  /// Procedurally rasterizes the 10 World Archery rings once at 1024x1024 (Bug #10 fix).
  void _rasterizeFace() {
    _hasRasterized = true;
    const int imgSize = 1024;
    const double r = imgSize * 0.5;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder, const Rect.fromLTWH(0, 0, 1024.0, 1024.0));
    const Offset center = Offset(r, r);

    // Ring pair colors from outside to inside (10 rings, 10% radius each)
    const List<Color> ringColors = [
      Color(0xFFF5F5F0), // Ring 1
      Color(0xFFF5F5F0), // Ring 2
      Color(0xFF1A1A1A), // Ring 3
      Color(0xFF1A1A1A), // Ring 4
      Color(0xFF2E7DD7), // Ring 5
      Color(0xFF2E7DD7), // Ring 6
      Color(0xFFE0322B), // Ring 7
      Color(0xFFE0322B), // Ring 8
      Color(0xFFF7D000), // Ring 9
      Color(0xFFF7D000), // Ring 10
    ];

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.008).clamp(0.75, 2.0);

    // Draw from outside in
    for (int ringIndex = 0; ringIndex < 10; ringIndex++) {
      final double ringRadius = r * (1.0 - ringIndex * 0.10);
      fillPaint.color = ringColors[ringIndex];
      c.drawCircle(center, ringRadius, fillPaint);

      // Dividing lines
      final bool isBlackZone = ringIndex == 2 || ringIndex == 3;
      linePaint.color = isBlackZone ? const Color(0x66FFFFFF) : const Color(0x66000000);
      c.drawCircle(center, ringRadius, linePaint);
    }

    // Inner X-ring
    final double xRadius = r * (ArcheryK.xRingRadius / ArcheryK.faceRadius);
    linePaint.color = const Color(0x88000000);
    c.drawCircle(center, xRadius, linePaint);

    // Central '+' crosshair
    final double crossSize = r * (0.01 / ArcheryK.faceRadius);
    c.drawLine(
      Offset(r - crossSize, r),
      Offset(r + crossSize, r),
      linePaint,
    );
    c.drawLine(
      Offset(r, r - crossSize),
      Offset(r, r + crossSize),
      linePaint,
    );

    _paintGloss(c, r);

    final ui.Picture picture = recorder.endRecording();
    picture.toImage(imgSize, imgSize).then((ui.Image img) {
      picture.dispose();
      _cachedFaceImage?.dispose();
      _cachedFaceImage = img;
    });
  }

  /// Glossy laminated finish (GamePigeon): light from the upper left.
  /// Runs once, inside the cached face image, so it costs nothing per frame.
  void _paintGloss(Canvas c, double r) {
    final Offset center = Offset(r, r);
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // 1. Bevel on every ring edge: a thin light line just inside each
    //    boundary on the lit side, a faint dark one on the shaded side.
    final Paint bevelLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.006
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(r * 2, r * 2),
        const [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.6],
      );
    final Paint bevelDark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.006
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(r * 2, r * 2),
        const [Color(0x00000000), Color(0x40000000)],
        const [0.4, 1.0],
      );
    for (int i = 0; i < 10; i++) {
      final double ringR = r * (1.0 - i * 0.10);
      c.drawCircle(center, ringR - r * 0.008, bevelLight);
      c.drawCircle(center, ringR - r * 0.004, bevelDark);
    }

    // 2. Broad sheen: lighter top-left, slightly darker bottom-right.
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(r * 2, r * 2),
          const [Color(0x30FFFFFF), Color(0x00FFFFFF), Color(0x1E000000)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 3. Soft specular hotspot, like light on a laminated face.
    final Offset hot = Offset(r * 0.62, r * 0.55);
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

    // 4. Thin rim shadow so the face sits on the board.
    c.drawCircle(
      center,
      r * 0.995,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012
        ..color = const Color(0x33000000),
    );
    c.restore();
  }
}
