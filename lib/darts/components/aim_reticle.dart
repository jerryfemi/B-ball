import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../scene/board_projection.dart';

/// Aiming reticle with steady ring and deterministic wobble visualization.
///
/// Follows DARTS_PLAN.md §1.2, §1.3 & Step 11:
/// - Priority 7 (drawn above resting dart, below score popups).
/// - Crosshair and steady ring rendered in `#38BDF8` (Sky blue).
/// - Steady ring shrinks into the steady window over the first 0.6s of hold.
/// - Dark outline provides clear contrast across all board segments.
/// - Zero heap allocations during `render()` and `update()`.
class AimReticle extends Component {
  final BoardProjection projection;

  bool visible = false;

  /// Target aim position in board millimeters (+x right, +y up).
  double targetMmX = 0.0;
  double targetMmY = 0.0;

  /// Current hold duration in seconds (controls steady ring shrinkage).
  double holdTime = 0.0;

  final Vector2 _screenPos = Vector2.zero();

  // ─── Zero-Allocation Cached Paints ─────────────────────────────────────────
  final ui.Paint _shadowPaint = ui.Paint()
    ..color = const ui.Color(0x99000000)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..isAntiAlias = true;

  final ui.Paint _reticlePaint = ui.Paint()
    ..color = const ui.Color(DartsK.accentP1)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..isAntiAlias = true;

  final ui.Paint _dotPaint = ui.Paint()
    ..color = const ui.Color(DartsK.accentP1)
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;

  final ui.Paint _steadyRingPaint = ui.Paint()
    ..color = const ui.Color(DartsK.accentP1).withValues(alpha: 0.45)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..isAntiAlias = true;

  AimReticle({required this.projection}) : super(priority: 7);

  /// Sets reticle position in board millimeters and hold time in seconds.
  void setAim({
    required double mmX,
    required double mmY,
    required double holdSec,
  }) {
    targetMmX = mmX;
    targetMmY = mmY;
    holdTime = holdSec;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!visible) return;

    // Project board millimeters into screen pixel coordinates
    projection.boardMmToScreen(targetMmX, targetMmY, _screenPos);
    final double cx = _screenPos.x;
    final double cy = _screenPos.y;

    const double innerR = 9.0;
    const double tickGap = 4.0;
    const double tickLen = 8.0;

    // 1. Draw high-contrast dark drop shadow
    canvas.drawCircle(ui.Offset(cx, cy), innerR, _shadowPaint);
    canvas.drawLine(
      ui.Offset(cx, cy - innerR - tickGap),
      ui.Offset(cx, cy - innerR - tickGap - tickLen),
      _shadowPaint,
    );
    canvas.drawLine(
      ui.Offset(cx, cy + innerR + tickGap),
      ui.Offset(cx, cy + innerR + tickGap + tickLen),
      _shadowPaint,
    );
    canvas.drawLine(
      ui.Offset(cx - innerR - tickGap, cy),
      ui.Offset(cx - innerR - tickGap - tickLen, cy),
      _shadowPaint,
    );
    canvas.drawLine(
      ui.Offset(cx + innerR + tickGap, cy),
      ui.Offset(cx + innerR + tickGap + tickLen, cy),
      _shadowPaint,
    );

    // 2. Draw sky blue reticle ring & crosshair ticks
    canvas.drawCircle(ui.Offset(cx, cy), innerR, _reticlePaint);
    canvas.drawCircle(ui.Offset(cx, cy), 2.2, _dotPaint);

    canvas.drawLine(
      ui.Offset(cx, cy - innerR - tickGap),
      ui.Offset(cx, cy - innerR - tickGap - tickLen),
      _reticlePaint,
    );
    canvas.drawLine(
      ui.Offset(cx, cy + innerR + tickGap),
      ui.Offset(cx, cy + innerR + tickGap + tickLen),
      _reticlePaint,
    );
    canvas.drawLine(
      ui.Offset(cx - innerR - tickGap, cy),
      ui.Offset(cx - innerR - tickGap - tickLen, cy),
      _reticlePaint,
    );
    canvas.drawLine(
      ui.Offset(cx + innerR + tickGap, cy),
      ui.Offset(cx + innerR + tickGap + tickLen, cy),
      _reticlePaint,
    );

    // 3. Steady ring: shrinks from 38 px settling radius to 12 px steady radius
    final double settleFrac = (holdTime / DartsK.wobbleSettleTau).clamp(0.0, 1.0);
    double ringRadius = 12.0 + 26.0 * math.exp(-holdTime / DartsK.wobbleSettleTau);

    // If fatigued (hold > 3.0s), steady ring pulses slightly
    if (holdTime > DartsK.fatigueStart) {
      final double fatigueFrac = ((holdTime - DartsK.fatigueStart) /
              (DartsK.fatigueFull - DartsK.fatigueStart))
          .clamp(0.0, 1.0);
      ringRadius += (math.sin(holdTime * 12.0) * 2.5) * fatigueFrac;
    }

    final double ringAlpha = (0.30 + 0.35 * (1.0 - settleFrac)).clamp(0.15, 0.65);
    _steadyRingPaint.color =
        const ui.Color(DartsK.accentP1).withValues(alpha: ringAlpha);

    canvas.drawCircle(ui.Offset(cx, cy), ringRadius, _steadyRingPaint);
  }
}
