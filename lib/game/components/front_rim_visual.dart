import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'backboard_visual.dart';

/// Renders the front half of the metal rim and front net cords.
/// Configured with priority = 5 so it renders in front of the basketball inside the net (priority = 4),
/// completing the 2.5D immersion when the ball drops into the hoop.
///
/// Highly optimized: Synchronizes net dynamics directly from [BackboardVisual]
/// rather than redundantly scanning world children and solving duplicate springs.
class FrontRimVisual extends PositionComponent {
  final double hoopWidth;
  final double hoopDepth;

  double _currentNetDepth = 0.9;
  double _currentBottomWidth = 0.55;
  double _currentSway = 0.0;

  BackboardVisual? _cachedBackboard;

  FrontRimVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.15,
  }) : super(
          position: position,
          size: Vector2(4.0, 4.0),
          anchor: Anchor.center,
          priority: 5,
        );

  @override
  void update(double dt) {
    super.update(dt);

    _cachedBackboard ??= parent?.children.whereType<BackboardVisual>().firstOrNull;
    if (_cachedBackboard != null) {
      _currentNetDepth = _cachedBackboard!.currentNetDepth;
      _currentBottomWidth = _cachedBackboard!.currentBottomWidth;
      _currentSway = _cachedBackboard!.currentSway;
    }
  }

  // ── Dirty-checked picture cache ──
  // The rim metal never changes and the net only wobbles for a few seconds after a make.
  // The picture is re-recorded only when the synced net state actually moves,
  // so at rest the render loop allocates nothing.
  static const double _netEpsilon = 0.0005;
  ui.Picture? _picture;
  double _recordedDepth = double.nan;
  double _recordedWidth = double.nan;
  double _recordedSway = double.nan;

  bool get _netMoved =>
      !((_currentNetDepth - _recordedDepth).abs() <= _netEpsilon &&
          (_currentBottomWidth - _recordedWidth).abs() <= _netEpsilon &&
          (_currentSway - _recordedSway).abs() <= _netEpsilon);

  ui.Picture _recordPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);
    _renderFrontNet(canvas);
    _renderFrontRim(canvas);
    _recordedDepth = _currentNetDepth;
    _recordedWidth = _currentBottomWidth;
    _recordedSway = _currentSway;
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_picture == null || _netMoved) {
      _picture?.dispose();
      _picture = _recordPicture();
    }
    canvas.drawPicture(_picture!);
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _renderFrontRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // 1. Deep underside rim shadow for metallic depth
    final underRimPaint = Paint()
      ..color = const Color(0xFF6B1116)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.09;

    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 0.010), width: hoopWidth, height: hoopDepth),
      0,
      math.pi,
      false,
      underRimPaint,
    );

    // 2. Base burnished iron crimson rim arc (bottom half from 0 to pi)
    final frontRimPaint = Paint()
      ..color = const Color(0xFF9E1B22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

    canvas.drawArc(
      rimRect,
      0,
      math.pi,
      false,
      frontRimPaint,
    );

    // 3. Specular metallic highlight along the top crest
    final highlightPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.022;

    final highlightRect = Rect.fromCenter(
      center: const Offset(0, -0.008),
      width: hoopWidth - 0.06,
      height: hoopDepth,
    );

    canvas.drawArc(
      highlightRect,
      0.15,
      math.pi - 0.3,
      false,
      highlightPaint,
    );

    // 4. Circular rim tips at the left and right collision pivots
    final pivotPaint = Paint()
      ..color = const Color(0xFF9E1B22)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(-hoopWidth / 2, 0), 0.045, pivotPaint);
    canvas.drawCircle(Offset(hoopWidth / 2, 0), 0.045, pivotPaint);
  }

  void _renderFrontNet(Canvas canvas) {
    final netCordPaint = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035;

    final knotPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    const cordCount = 8;
    final netDepth = _currentNetDepth;
    final bottomWidthRatio = _currentBottomWidth;

    final topPoints = <Offset>[];
    final bottomPoints = <Offset>[];

    // Compute attachment loops along front rim arc (0 to pi)
    for (int i = 0; i <= cordCount; i++) {
      final t = i / cordCount;
      final angle = t * math.pi;
      final x = (hoopWidth / 2) * math.cos(angle);
      final y = (hoopDepth / 2) * math.sin(angle);
      topPoints.add(Offset(x, y));

      final bx = x * bottomWidthRatio + _currentSway;
      final by = netDepth;
      bottomPoints.add(Offset(bx, by));
    }

    // 1. Draw cross-hatched cord mesh
    for (int i = 0; i < cordCount; i++) {
      canvas.drawLine(topPoints[i], bottomPoints[i + 1], netCordPaint);
      canvas.drawLine(topPoints[i + 1], bottomPoints[i], netCordPaint);
    }

    // 2. Draw front horizontal loop ribs
    for (double yFrac = 0.25; yFrac <= 0.85; yFrac += 0.25) {
      final curY = netDepth * yFrac;
      final curWidth = hoopWidth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);
      final curDepth = hoopDepth * (1.0 - (1.0 - bottomWidthRatio) * yFrac);

      final ribRect = Rect.fromCenter(
        center: Offset(_currentSway * yFrac, curY),
        width: curWidth,
        height: curDepth,
      );

      canvas.drawArc(
        ribRect,
        0,
        math.pi,
        false,
        netCordPaint,
      );

      // Knots along the horizontal rib
      for (int k = 1; k < cordCount; k++) {
        final t = k / cordCount;
        final angle = t * math.pi;
        final kx = _currentSway * yFrac + (curWidth / 2) * math.cos(angle);
        final ky = curY + (curDepth / 2) * math.sin(angle);
        canvas.drawCircle(Offset(kx, ky), 0.02, knotPaint);
      }
    }
  }
}
