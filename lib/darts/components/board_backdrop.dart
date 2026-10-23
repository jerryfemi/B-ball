import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../darts_constants.dart';
import '../scene/board_projection.dart';

/// Renders the dark obsidian pub wall backdrop with warm amber spotlight.
///
/// Follows DARTS_PLAN.md §1.5:
/// - Dark obsidian gradient (`#0A0E1A` → `#0F172A`).
/// - Soft warm amber spotlight focused on the dartboard.
/// - Recorded once into a [ui.Picture] on resize.
/// - Render loop is a single `drawPicture` call with zero runtime allocations.
class BoardBackdrop extends Component {
  final BoardProjection projection;

  ui.Picture? _picture;

  BoardBackdrop({required this.projection}) : super(priority: 0);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recordBackdrop(size.x, size.y);
  }

  void _recordBackdrop(double width, double height) {
    _picture?.dispose();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 1. Base dark obsidian vertical gradient
    final Rect screenRect = Rect.fromLTWH(0, 0, width, height);
    final Paint wallPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, height),
        const [
          Color(DartsK.surfaceDark), // #0A0E1A
          Color(DartsK.surfaceMid),  // #0F172A
          Color(0xFF070B14),
        ],
        const [0.0, 0.6, 1.0],
      );
    c.drawRect(screenRect, wallPaint);

    // 2. Warm amber spotlight centered around the dartboard
    final double cx = projection.boardCenterX;
    final double cy = projection.boardCenterY;
    final double spotlightRadius = projection.boardRadiusPx * 2.5;

    final Paint spotlightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        spotlightRadius,
        const [
          Color(0x3AF59E0B), // Soft warm amber
          Color(0x1DF59E0B),
          Color(0x06F59E0B),
          Color(0x00000000),
        ],
        const [0.0, 0.35, 0.70, 1.0],
      );
    c.drawCircle(Offset(cx, cy), spotlightRadius, spotlightPaint);

    // 3. Subtle vignette around screen borders
    final Paint vignettePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.5, height * 0.5),
        math.max(width, height) * 0.75,
        const [
          Color(0x00000000),
          Color(0x80050810),
        ],
        const [0.65, 1.0],
      );
    c.drawRect(screenRect, vignettePaint);

    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }
}
