import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'backboard_visual.dart';

/// Renders the front half of the metal rim and front net cords.
/// Configured with priority = 5 so it renders in front of the basketball inside the net (priority = 4),
/// completing the 2.5D immersion when the ball drops into the hoop.
///
/// Highly optimized: Synchronizes net dynamics directly from [BackboardVisual]
/// rather than redundantly scanning world children and solving duplicate springs.
class FrontRimVisual extends PositionComponent
    with HasGameReference<BasketballGame> {
  final double hoopWidth;
  final double hoopDepth;

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
    _cachedBackboard ??=
        parent?.children.whereType<BackboardVisual>().firstOrNull;
  }

  // ── Version-checked picture cache ──
  // The rim metal never changes and the cloth net only moves for a moment
  // after contact. The picture is re-recorded only when the net simulation
  // reports a new version, so at rest the render loop allocates nothing.
  // Rim wobble (HoopFx) is a translation applied at draw time — free.
  ui.Picture? _picture;
  int _recordedNetVersion = -1;

  ui.Picture _recordPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Shift origin so (0, 0) corresponds to the hoop center
    canvas.translate(size.x / 2, size.y / 2);
    _renderFrontNet(canvas);
    _renderFrontRim(canvas);
    _recordedNetVersion = _cachedBackboard?.net.version ?? -1;
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final netVersion = _cachedBackboard?.net.version ?? -1;
    if (_picture == null || netVersion != _recordedNetVersion) {
      _picture?.dispose();
      _picture = _recordPicture();
    }
    final fx = game.hoopFx;
    final shaking = fx.rimOffsetX != 0.0 || fx.rimOffsetY != 0.0;
    if (shaking) {
      canvas.save();
      canvas.translate(fx.rimOffsetX, fx.rimOffsetY);
    }
    canvas.drawPicture(_picture!);
    if (shaking) canvas.restore();
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

  static final Paint _netCordPaint = Paint()
    ..color = const Color(0xF2FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.035;

  static final Paint _knotPaint = Paint()
    ..color = const Color(0xFFE2E8F0)
    ..style = PaintingStyle.fill;

  /// Front half of the cloth net (drawn over the ball inside the hoop).
  void _renderFrontNet(Canvas canvas) {
    final net = _cachedBackboard?.net;
    if (net == null) return;
    net.drawMesh(canvas, _netCordPaint, front: true);
    net.drawKnots(canvas, _knotPaint, 0.02);
  }
}
