import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

/// 122 cm World Archery regulation target with wooden A-frame stand and straw boss.
///
/// Performance:
/// - Target face is procedurally generated and cached as a [ui.Image].
/// - Only re-rasterized when screen pixel radius changes by > 15% (e.g. during zoom).
/// - 0 heap allocations per render frame.
class TargetBoard {
  final ArcheryCamera camera;

  TargetBoard({required this.camera, double initialDistance = ArcheryK.distanceM})
      : distance = initialDistance;

  /// Current distance from archer in meters (e.g. 20, 40, 60).
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
    ..strokeWidth = 8.0
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;
  final Paint _woodCrossPaint = Paint()
    ..color = const Color(0xFF432C18)
    ..strokeWidth = 5.0
    ..style = PaintingStyle.stroke;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  // --- Target Face ui.Image Cache ---
  ui.Image? _cachedFaceImage;
  double _cachedRadiusPx = 0.0;
  bool _isRasterizing = false;

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

    // 2. Render Wooden A-Frame Stand behind the boss
    _renderStand(canvas, depth);

    // 3. Render 1.30m x 1.30m Straw Boss
    _renderBoss(canvas, cx, cy, pxPerM);

    // 4. Render Procedural 122cm Target Face (Cached)
    _renderTargetFace(canvas, cx, cy, pxPerM);
  }

  void _renderStand(Canvas canvas, double depth) {
    const double legTopY = ArcheryK.targetCenterY - ArcheryK.boardHeight * 0.4;
    const double halfLegX = ArcheryK.boardWidth * 0.38;

    // Left and right legs extending down to ground (Y = 0)
    _draw3DLeg(canvas, -halfLegX, legTopY, distance, -halfLegX - 0.05, 0.0, distance - 0.05);
    _draw3DLeg(canvas, halfLegX, legTopY, distance, halfLegX + 0.05, 0.0, distance - 0.05);
    // Rear tripod support strut angled backward
    _draw3DLeg(canvas, 0.0, ArcheryK.targetCenterY, distance, 0.0, 0.0, distance + 0.70);

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
    double z2,
  ) {
    if (!camera.project(x1, y1, z1)) return;
    final double sx1 = camera.sx;
    final double sy1 = camera.sy;

    if (!camera.project(x2, y2, z2)) return;
    final double sx2 = camera.sx;
    final double sy2 = camera.sy;

    canvas.drawLine(Offset(sx1, sy1), Offset(sx2, sy2), _woodLegPaint);
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

    // Check if cached image needs re-rasterization (>15% size change)
    final bool needsRasterize = _cachedFaceImage == null ||
        (_cachedRadiusPx - faceRadiusPx).abs() / _cachedRadiusPx > 0.15;

    if (needsRasterize && !_isRasterizing) {
      _rasterizeFace(faceRadiusPx);
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

  /// Procedurally rasterizes the 10 World Archery rings into a crisp [ui.Image].
  void _rasterizeFace(double radiusPx) {
    _isRasterizing = true;
    _cachedRadiusPx = radiusPx;

    // Oversample slightly (clamped between 128 and 1024 px) for razor-sharp rings
    final int imgSize = (radiusPx * 2.0).clamp(128.0, 1024.0).toInt();
    final double r = imgSize * 0.5;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder, Rect.fromLTWH(0, 0, imgSize.toDouble(), imgSize.toDouble()));
    final Offset center = Offset(r, r);

    // Ring pair colors from outside to inside (10 rings, 10% radius each)
    // 1-2: White (#F5F5F0)
    // 3-4: Black (#1A1A1A)
    // 5-6: Blue (#2E7DD7)
    // 7-8: Red (#E0322B)
    // 9-10: Gold (#F7D000)
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
      // Rings 3 & 4 (black) use white lines; all others use thin dark lines
      final bool isBlackZone = ringIndex == 2 || ringIndex == 3;
      linePaint.color = isBlackZone ? const Color(0x66FFFFFF) : const Color(0x66000000);
      c.drawCircle(center, ringRadius, linePaint);
    }

    // Inner X-ring (radius = 5% of face radius = 0.0305 / 0.61)
    final double xRadius = r * (ArcheryK.xRingRadius / ArcheryK.faceRadius);
    linePaint.color = const Color(0x88000000);
    c.drawCircle(center, xRadius, linePaint);

    // Central '+' crosshair (1 cm in real life)
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

    final ui.Picture picture = recorder.endRecording();
    picture.toImage(imgSize, imgSize).then((ui.Image img) {
      _cachedFaceImage?.dispose();
      _cachedFaceImage = img;
      _isRasterizing = false;
    });
  }
}
