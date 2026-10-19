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

  TargetBoard({required this.camera, double initialDistance = ArcheryK.distNear})
      : distance = initialDistance;

  /// Current distance from archer in meters (e.g. 20, 40, 60).
  double distance;

  // --- Cached Paints ---
  final Paint _bossPaint = Paint()..color = const Color(0xFF261D15);
  final Paint _bossBorderPaint = Paint()
    ..color = const Color(0xFF3B2E21)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _strawTexturePaint = Paint()
    ..color = const Color(0xFF1E1711)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  final Paint _woodLegPaint = Paint()
    ..color = const Color(0xFF4A3728)
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _woodCrossPaint = Paint()
    ..color = const Color(0xFF38291E)
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  // --- Target Face ui.Image Cache ---
  ui.Image? _cachedFaceImage;
  double _cachedRadiusPx = 0.0;
  bool _isRasterizing = false;

  void updateDistance(double newDistance) {
    if (distance != newDistance) {
      distance = newDistance;
      _invalidateCache();
    }
  }

  void _invalidateCache() {
    _cachedFaceImage?.dispose();
    _cachedFaceImage = null;
    _cachedRadiusPx = 0.0;
  }

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
    const double topY = ArcheryK.targetCenterY + 0.35;
    const double halfW = 0.55;

    // Left leg: (halfW, topY, distance) -> (halfW + 0.15, 0.0, distance - 0.25)
    _draw3DLeg(canvas, -halfW, topY, distance, -halfW - 0.15, 0.0, distance - 0.25);
    // Right leg:
    _draw3DLeg(canvas, halfW, topY, distance, halfW + 0.15, 0.0, distance - 0.25);
    // Rear support strut angled backward:
    _draw3DLeg(canvas, 0.0, topY - 0.1, distance, 0.0, 0.0, distance + 0.85);

    // Horizontal cross brace at Y = 0.5m
    if (camera.project(-halfW - 0.08, 0.5, distance - 0.12)) {
      final double x1 = camera.sx;
      final double y1 = camera.sy;
      if (camera.project(halfW + 0.08, 0.5, distance - 0.12)) {
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
    final double halfBossPx = pxPerM * (ArcheryK.bossWidth * 0.5);

    final Rect bossRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: halfBossPx * 2.0,
      height: halfBossPx * 2.0,
    );

    // Draw straw boss base
    canvas.drawRect(bossRect, _bossPaint);
    canvas.drawRect(bossRect, _bossBorderPaint);

    // Subtle straw fiber lines for depth
    final double step = (halfBossPx * 0.35).clamp(8.0, 32.0);
    for (double off = -halfBossPx + step; off < halfBossPx; off += step) {
      canvas.drawLine(
        Offset(bossRect.left, cy + off),
        Offset(bossRect.right, cy + off),
        _strawTexturePaint,
      );
    }
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
