import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// Renders a dart stuck into the dartboard face following impact.
///
/// Follows DARTS_PLAN.md Step 10:
/// - Priority 4 (drawn above board shadows and dartboard, below flying and resting darts).
/// - Perspective pose selected deterministically by landing coordinate $x$:
///   - $x < -60$ mm: `stuck_0` (tail splayed left, tip leaning toward center)
///   - $x > +60$ mm: `stuck_2` (tail splayed right, tip leaning toward center)
///   - otherwise: `stuck_1` (straight-on perspective)
/// - Impact wobble: rotates by $3^\circ \times e^{-t / 0.12} \times \sin(t \times 60)$ for 0.35 s.
/// - Retrieval pull: fades opacity out over 200 ms ([DartsK.dartPullFadeSec]), then removes.
/// - Zero heap allocations during `update()` and `render()`.
class StuckDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;
  final DartHit hit;

  /// Player index: 0 for P1 (you / sky blue), 1 for P2 / bot (amber).
  final int playerIndex;

  /// Deterministic perspective frame index (0..2).
  final int stuckPoseIndex;

  // ─── Impact Wobble State ───────────────────────────────────────────────────
  double _wobbleTime = 0.0;
  static const double _maxWobbleRad = 3.0 * math.pi / 180.0;

  // ─── Turn End Retrieval / Pull Fade State ───────────────────────────────────
  bool _isPulling = false;
  double _pullTime = 0.0;
  double _opacity = 1.0;

  final ui.Paint _fadePaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  final Vector2 _screenPos = Vector2.zero();

  StuckDart({
    required this.projection,
    required this.sprites,
    required this.hit,
    this.playerIndex = 0,
  }) : stuckPoseIndex = poseIndexForX(hit.x),
       super(priority: 4);

  /// Selects perspective stuck sprite pose based on landing coordinate $x$ in board millimeters.
  static int poseIndexForX(double xMm) {
    if (xMm < -60.0) return 0;
    if (xMm > 60.0) return 2;
    return 1;
  }

  /// Initiates retrieval fade-out animation at the end of a turn.
  void startPull() {
    _isPulling = true;
    _pullTime = 0.0;
  }

  /// Wobble rotation angle in radians at current post-impact time.
  double get wobbleAngle {
    if (_wobbleTime >= DartsK.stuckWobbleDurationSec) return 0.0;
    final double t = _wobbleTime;
    return _maxWobbleRad * math.exp(-t / 0.12) * math.sin(t * 60.0);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_wobbleTime < DartsK.stuckWobbleDurationSec) {
      _wobbleTime += dt;
      if (_wobbleTime > DartsK.stuckWobbleDurationSec) {
        _wobbleTime = DartsK.stuckWobbleDurationSec;
      }
    }

    if (_isPulling) {
      _pullTime += dt;
      final double progress = (_pullTime / DartsK.dartPullFadeSec).clamp(
        0.0,
        1.0,
      );
      _opacity = 1.0 - progress;
      if (progress >= 1.0) {
        removeFromParent();
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_opacity <= 0.0) return;

    final double screenH = projection.screenHeight;
    if (screenH <= 0.0) return;

    // 1. Tip lands exactly on the hit millimeter point on the dartboard face
    projection.boardMmToScreen(hit.x, hit.y, _screenPos);

    // 2. Board-plane perspective scale factor
    final double depth = projection.depthScale(0.0);
    final double restScale =
        (screenH * DartsK.restingDartHeightFrac) / sprites.cellHeight;
    final double scale = restScale * depth;

    // 3. Perspective pose and impact wobble angle
    final int pIdx = playerIndex.clamp(0, 1);
    final ui.Rect src = sprites.stuck[pIdx][stuckPoseIndex.clamp(0, 2)];
    final double angle = wobbleAngle;

    // 4. Draw with optional pull opacity
    if (_opacity < 1.0) {
      _fadePaint.color = ui.Color.fromARGB(
        (_opacity * 255.0).round(),
        255,
        255,
        255,
      );
      DartRenderer.draw(
        canvas,
        sprites.atlasImage,
        src,
        _screenPos.x,
        _screenPos.y,
        scale,
        angle,
        sprites.dstAtOrigin,
        _fadePaint,
      );
    } else {
      DartRenderer.draw(
        canvas,
        sprites.atlasImage,
        src,
        _screenPos.x,
        _screenPos.y,
        scale,
        angle,
        sprites.dstAtOrigin,
      );
    }
  }
}
