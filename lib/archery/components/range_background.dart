import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../archery_constants.dart';
import '../camera/archery_camera.dart';

/// Renders the outdoor archery range at night under stadium floodlights.
///
/// Features:
/// - Parallax sky and dark treeline silhouettes at infinity.
/// - 3D projected ground lanes and distance marker lines (10m - 70m).
/// - 3D floodlight towers on either side casting atmospheric glow.
/// - Strict zero-allocation rendering loop.
class RangeBackground {
  final ArcheryCamera camera;

  RangeBackground({required this.camera});

  // --- Cached Paints (Zero runtime allocation) ---
  final Paint _skyPaint = Paint()..isAntiAlias = false;
  final Paint _treelinePaint = Paint()
    ..color = const Color(0xFF070B16)
    ..style = PaintingStyle.fill;
  final Paint _groundPaint = Paint()
    ..color = const Color(0xFF080E1C)
    ..style = PaintingStyle.fill;
  final Paint _laneLinePaint = Paint()
    ..color = const Color(0xFF1E283D)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  final Paint _targetLanePaint = Paint()
    ..color = const Color(0xFF263554)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _markerLinePaint = Paint()
    ..color = const Color(0xFF334466)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  final Paint _activeDistancePaint = Paint()
    ..color = const Color(0xFF00FFCC).withValues(alpha: 0.7)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;
  final Paint _floodlightPolePaint = Paint()
    ..color = const Color(0xFF131B2A)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  final Paint _floodlightLampPaint = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..style = PaintingStyle.fill;
  final Paint _floodlightGlowPaint = Paint()
    ..color = const Color(0x3338BDF8)
    ..style = PaintingStyle.fill;
  final Paint _boardBgPaint = Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.fill;
  final Paint _boardBorderPaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  // Reusable Path to avoid heap allocations
  final Path _reusablePath = Path();

  // Cached TextPainter for distance signs
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  // Reusable rects
  Rect _cachedSkyRect = Rect.zero;
  double _lastW = 0.0;
  double _lastH = 0.0;

  // Active highlighted target distance
  double activeDistance = ArcheryK.distNear;

  void resize(double width, double height) {
    if (width == _lastW && height == _lastH) return;
    _lastW = width;
    _lastH = height;
    _cachedSkyRect = Rect.fromLTWH(0, 0, width, height);

    _skyPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF04060C),
        Color(0xFF070B16),
        Color(0xFF0D1424),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(_cachedSkyRect);
  }

  void render(Canvas canvas) {
    if (_lastW <= 0.0 || _lastH <= 0.0) return;

    // 1. Sky Gradient (Background)
    canvas.drawRect(_cachedSkyRect, _skyPaint);

    // 2. Projected Horizon Line (where ground meets sky at Z -> infinity)
    // Looking forward at eye height eyeY = 1.6m, horizon is at sy where pitch tilts
    // In camera coordinates: dy = -eyeY, dz = inf -> sy = screenH/2 + f * tan(pitch)
    final double horizonY = _lastH * 0.5 + camera.focalLengthPx * math.tan(camera.pitch);

    // 3. Far Treeline / Stadium Silhouette (Parallax at infinity)
    _renderParallaxSilhouette(canvas, horizonY);

    // 4. Ground Turf
    if (horizonY < _lastH) {
      canvas.drawRect(
        Rect.fromLTRB(0, horizonY.clamp(0.0, _lastH), _lastW, _lastH),
        _groundPaint,
      );
    }

    // 5. 3D Projected Ground Lanes
    _renderGroundLanes(canvas);

    // 6. 3D Distance Lines and Marker Boards (10m - 70m)
    _renderDistanceMarkers(canvas);

    // 7. 3D Stadium Floodlight Posts
    _renderFloodlights(canvas);
  }

  void _renderParallaxSilhouette(Canvas canvas, double horizonY) {
    // Parallax horizontal offset based on yaw
    final double yawOffset = camera.focalLengthPx * math.tan(camera.yaw);
    final double baseY = horizonY;

    _reusablePath.reset();
    _reusablePath.moveTo(0, _lastH);
    _reusablePath.lineTo(0, baseY);

    // Draw stylized stadium and pine silhouettes across width
    const double step = 28.0;
    final int count = (_lastW / step).ceil() + 4;
    final double startX = -((yawOffset * 0.4) % step) - step;

    for (int i = 0; i <= count; i++) {
      final double px = startX + i * step;
      // Deterministic jagged horizon profile
      final double h = 18.0 + 14.0 * math.sin(i * 1.7) + 8.0 * math.cos(i * 3.1);
      _reusablePath.lineTo(px, baseY - h);
    }

    _reusablePath.lineTo(_lastW, baseY);
    _reusablePath.lineTo(_lastW, _lastH);
    _reusablePath.close();

    canvas.drawPath(_reusablePath, _treelinePaint);
  }

  void _renderGroundLanes(Canvas canvas) {
    // Left & right lane boundary lines in 3D: X = ±1.25m, ±3.5m running from Z = 1 to 75m
    const double zNear = 1.0;
    const double zFar = 75.0;

    _draw3DLine(canvas, -1.25, 0.0, zNear, -1.25, 0.0, zFar, _targetLanePaint);
    _draw3DLine(canvas, 1.25, 0.0, zNear, 1.25, 0.0, zFar, _targetLanePaint);
    _draw3DLine(canvas, -3.5, 0.0, zNear, -3.5, 0.0, zFar, _laneLinePaint);
    _draw3DLine(canvas, 3.5, 0.0, zNear, 3.5, 0.0, zFar, _laneLinePaint);

    // Center dotted guide line
    for (double z = 2.0; z < 70.0; z += 3.0) {
      _draw3DLine(canvas, 0.0, 0.0, z, 0.0, 0.0, z + 1.2, _laneLinePaint);
    }
  }

  void _renderDistanceMarkers(Canvas canvas) {
    // Distance markers from 10m to 70m
    const List<double> distances = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0];

    for (final double dist in distances) {
      final bool isActive = (dist - activeDistance).abs() < 0.5;
      final Paint linePaint = isActive ? _activeDistancePaint : _markerLinePaint;

      // Cross line on ground from X = -2.5 to +2.5
      _draw3DLine(canvas, -2.5, 0.0, dist, 2.5, 0.0, dist, linePaint);

      // Distance sign board at right side (X = 2.8, Y = 0.25, Z = dist)
      _renderDistanceBoard(canvas, 2.9, 0.35, dist, '${dist.toInt()}m', isActive);
      _renderDistanceBoard(canvas, -2.9, 0.35, dist, '${dist.toInt()}m', isActive);
    }
  }

  void _renderDistanceBoard(
    Canvas canvas,
    double x,
    double y,
    double z,
    String text,
    bool isActive,
  ) {
    if (!camera.project(x, y, z)) return;
    final double cx = camera.sx;
    final double cy = camera.sy;
    final double pxPerM = camera.pxPerMeterAt(camera.depth);

    final double boardW = pxPerM * 0.50; // 50 cm width
    final double boardH = pxPerM * 0.26; // 26 cm height
    if (boardW < 4.0) return; // Too far to draw

    final Rect boardRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boardW,
      height: boardH,
    );

    // Board background & border
    canvas.drawRect(boardRect, _boardBgPaint);
    _boardBorderPaint.color = isActive ? const Color(0xFF00FFCC) : const Color(0xFF38BDF8);
    canvas.drawRect(boardRect, _boardBorderPaint);

    // Text rendering if large enough
    if (boardW >= 18.0) {
      _textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: isActive ? const Color(0xFF00FFCC) : const Color(0xFFE2E8F0),
          fontSize: (boardH * 0.65).clamp(8.0, 20.0),
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
      _textPainter.layout();
      _textPainter.paint(
        canvas,
        Offset(cx - _textPainter.width * 0.5, cy - _textPainter.height * 0.5),
      );
    }
  }

  void _renderFloodlights(Canvas canvas) {
    // Floodlight poles along sides: X = ±6.0m, Z = 15, 35, 55m, Height = 5.5m
    const List<double> poleDistances = [15.0, 35.0, 55.0];

    for (final double z in poleDistances) {
      _renderFloodlightTower(canvas, -6.0, z);
      _renderFloodlightTower(canvas, 6.0, z);
    }
  }

  void _renderFloodlightTower(Canvas canvas, double x, double z) {
    const double poleHeight = 5.5;

    // Draw pole from base (y=0) to top (y=5.5)
    _draw3DLine(canvas, x, 0.0, z, x, poleHeight, z, _floodlightPolePaint);

    // Project lamp head at top
    if (camera.project(x, poleHeight, z)) {
      final double lx = camera.sx;
      final double ly = camera.sy;
      final double pxPerM = camera.pxPerMeterAt(camera.depth);
      final double lampRadius = (pxPerM * 0.35).clamp(2.0, 24.0);

      // Glow halo
      canvas.drawCircle(Offset(lx, ly), lampRadius * 2.2, _floodlightGlowPaint);
      // Crisp light head
      canvas.drawCircle(Offset(lx, ly), lampRadius * 0.8, _floodlightLampPaint);
    }
  }

  void _draw3DLine(
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
    final double sx2 = camera.sx;
    final double sy2 = camera.sy;

    canvas.drawLine(Offset(sx1, sy1), Offset(sx2, sy2), paint);
  }
}
