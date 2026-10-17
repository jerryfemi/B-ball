import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../basketball_game.dart';
import 'backboard_visual.dart';

/// Renders the rear half of the metal rim, solid steel mounting bracket neck,
/// and rear net mesh at priority = 3.
///
/// In the 2.5D layering pipeline:
/// - Priority 1: BackboardVisual (wall shadows, pole, backboard glass, target square)
/// - Priority 2: Basketball when banking off backboard or on rear neck (Z >= 4.70m)
/// - Priority 3: RearRimVisual (rear rim arc, mounting bracket flange, rear net)
/// - Priority 4: Basketball inside hoop cylinder / net (4.23m <= Z < 4.70m)
/// - Priority 5: FrontRimVisual (front rim arc, highlight, front net)
/// - Priority 6: Basketball in foreground (Z < 4.23m)
///
/// This mathematically guarantees that balls hitting the bank zone bounce visibly
/// in front of the backboard faceplate while remaining solidly behind the rear rim
/// and mounting bracket — completely eliminating any visual "slip-through" glitch.
class RearRimVisual extends PositionComponent
    with HasGameReference<BasketballGame> {
  final double hoopWidth;
  final double hoopDepth;

  BackboardVisual? _cachedBackboard;

  RearRimVisual({
    required Vector2 position,
    this.hoopWidth = 1.8,
    this.hoopDepth = 0.15,
  }) : super(
          position: position,
          size: Vector2(4.0, 4.0),
          anchor: Anchor.center,
          priority: 3,
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
    _renderMountingBracket(canvas);
    _renderRearNet(canvas);
    _renderRearRim(canvas);
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

  void _renderMountingBracket(Canvas canvas) {
    final bracketPaint = Paint()
      ..color = const Color(0xFF7F1319) // Burnished iron crimson
      ..style = PaintingStyle.fill;

    // Solid mounting flange connecting rear rim to backboard faceplate
    // Spans from rear rim (Y = -0.075) to backboard collar (Y = -0.22)
    final bracketRect = Rect.fromCenter(
      center: const Offset(0, -0.10),
      width: 0.34,
      height: 0.18,
    );
    canvas.drawRect(bracketRect, bracketPaint);

    // Top crest metallic highlight
    final highlightPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;
    canvas.drawLine(
      const Offset(-0.16, -0.18),
      const Offset(0.16, -0.18),
      highlightPaint,
    );

    // Heavy mounting bolts
    final boltPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-0.10, -0.10), 0.024, boltPaint);
    canvas.drawCircle(const Offset(0.10, -0.10), 0.024, boltPaint);
  }

  void _renderRearRim(Canvas canvas) {
    final rimRect = Rect.fromCenter(
      center: Offset.zero,
      width: hoopWidth,
      height: hoopDepth,
    );

    // Top half of rim ellipse (from pi to 2*pi): curves upwards/away
    final rearRimPaint = Paint()
      ..color = const Color(0xFF751117) // Shaded deep iron crimson
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.08;

    canvas.drawArc(rimRect, math.pi, math.pi, false, rearRimPaint);
  }

  static final Paint _rearNetPaint = Paint()
    ..color = const Color(0x5094A3B8) // Translucent rear cords
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.025;

  /// Rear half of the cloth net (seen through the front, behind the ball).
  void _renderRearNet(Canvas canvas) {
    final net = _cachedBackboard?.net;
    if (net == null) return;
    net.drawMesh(canvas, _rearNetPaint, front: false);
  }
}
