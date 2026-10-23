import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// Renders the dart resting in the player's hand during the aim phase.
///
/// Follows DARTS_PLAN.md Step 10:
/// - Priority 6 (drawn above flying dart and board, below reticle and popups).
/// - Scaled to ~38% of screen height ([DartsK.restingDartHeightFrac]).
/// - Follows reticle horizontally (±12% of screen width) and leans toward it (±6°).
/// - Adds deterministic hand wobble offset so fatigue shaking is visibly apparent.
/// - Pulls back ~4% of dart height for 80 ms during the upward flick gesture.
/// - Zero heap allocations during `update()` and `render()`.
class RestingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  /// Player index: 0 for P1 (you / sky blue), 1 for P2 / bot (amber).
  int playerIndex = 0;

  /// Whether the resting dart is visible (hidden while dart is in flight).
  bool visible = true;

  /// Normalized aim horizontal offset in `[-1.0, 1.0]` (0.0 = center).
  double reticleNormX = 0.0;

  /// Current reticle wobble offsets in board millimeters (+x right, +y up).
  double wobbleMmX = 0.0;
  double wobbleMmY = 0.0;

  // ─── Flick Pullback State ──────────────────────────────────────────────────
  bool _isPullingBack = false;
  double _pullBackTimer = 0.0;
  static const double _pullBackDuration = 0.080; // 80 ms

  RestingDart({
    required this.projection,
    required this.sprites,
    this.playerIndex = 0,
  }) : super(priority: 6);

  /// Sets reticle aim horizontal offset normalized by reference board radius.
  void setAimOffset(double normX) {
    reticleNormX = normX.clamp(-1.0, 1.0);
  }

  /// Sets current wobble shake offsets in board millimeters.
  void setWobble(double mmX, double mmY) {
    wobbleMmX = mmX;
    wobbleMmY = mmY;
  }

  /// Starts the 80 ms pullback animation when an upward flick is initiated.
  void startPullBack() {
    _isPullingBack = true;
    _pullBackTimer = 0.0;
  }

  /// Resets the pullback animation back to resting position.
  void resetPullBack() {
    _isPullingBack = false;
    _pullBackTimer = 0.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isPullingBack && _pullBackTimer < _pullBackDuration) {
      _pullBackTimer += dt;
      if (_pullBackTimer > _pullBackDuration) {
        _pullBackTimer = _pullBackDuration;
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!visible) return;

    final double screenH = projection.screenHeight;
    final double screenW = projection.screenWidth;
    if (screenH <= 0.0 || screenW <= 0.0) return;

    // 1. Uniform scale to achieve ~38% of screen height
    final double dartHeight = screenH * DartsK.restingDartHeightFrac;
    final double scale = dartHeight / sprites.cellHeight;

    // 2. Horizontal position: screen center + reticle sway (±12%) + wobble (px)
    final double swayPx = reticleNormX * (screenW * 0.12);
    final double wobblePxX = wobbleMmX * projection.mmToPx;
    final double cx = (screenW * 0.5) + swayPx + wobblePxX;

    // 3. Lean angle: ±6° toward reticle aim direction
    const double maxLeanRad = 6.0 * math.pi / 180.0;
    final double angle = reticleNormX * maxLeanRad;

    // 4. Vertical position: tip sits at hand height, plus pullback and vertical wobble
    final double tipBaseY = screenH - dartHeight + (dartHeight * 0.14);
    final double pullBackFrac = _isPullingBack
        ? (_pullBackTimer / _pullBackDuration).clamp(0.0, 1.0)
        : 0.0;
    final double pullBackPx = dartHeight * 0.04 * pullBackFrac;
    // Invert wobbleMmY since +y is up in board mm, but down on screen canvas
    final double wobblePxY = wobbleMmY * projection.mmToPx;
    final double cy = tipBaseY + pullBackPx - wobblePxY;

    final int pIdx = playerIndex.clamp(0, 1);
    DartRenderer.draw(
      canvas,
      sprites.atlasImage,
      sprites.rest[pIdx],
      cx,
      cy,
      scale,
      angle,
      sprites.dstAtOrigin,
    );
  }
}
