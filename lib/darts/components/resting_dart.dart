import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';

import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// The dart in your hand, bottom-centre of the screen.
///
/// - Sized from [BoardProjection.restDartHeightPx] (scales with the screen).
/// - While a finger holds it, it follows the finger (smoothed), with a small
///   lean in the direction the finger is moving. No aim preview.
/// - [tipX]/[tipY] are where a throw starts its flight.
/// - Zero heap allocations in `update()` and `render()`.
class RestingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  /// Sprite row (0 = you, 1 = opponent / bot).
  int playerIndex = 0;

  /// Hidden while a dart flies and on the opponent's turn.
  bool visible = true;

  // Finger hold (screen px), set by the game each frame.
  bool _holding = false;
  double _fingerX = 0.0;
  double _fingerY = 0.0;

  /// Current (smoothed) tip position in screen px.
  double tipX = 0.0;
  double tipY = 0.0;
  double _lean = 0.0;
  bool _placed = false;

  RestingDart({
    required this.projection,
    required this.sprites,
    this.playerIndex = 0,
  }) : super(priority: 6);

  /// Called every frame with the finger state from the flick controller.
  void setHold(bool holding, double fingerX, double fingerY) {
    _holding = holding;
    _fingerX = fingerX;
    _fingerY = fingerY;
  }

  /// Puts the dart straight back at its rest spot (new dart, new turn).
  void resetToRest() {
    _holding = false;
    tipX = projection.handX;
    tipY = projection.handY;
    _lean = 0.0;
    _placed = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (projection.screenHeight <= 0.0) return;
    if (!_placed) resetToRest();

    final double h = projection.restDartHeightPx;
    double targetX;
    double targetY;
    if (_holding) {
      // The finger holds the dart around its barrel.
      final double margin = h * 0.18;
      targetX = _fingerX.clamp(margin, projection.screenWidth - margin).toDouble();
      targetY = (_fingerY - h * 0.55)
          .clamp(projection.screenHeight * 0.42, projection.handY)
          .toDouble();
    } else {
      targetX = projection.handX;
      targetY = projection.handY;
    }

    // Snappy follow without jitter (frame-rate independent).
    final double k = 1.0 - math.exp(-dt * 28.0);
    final double moveX = (targetX - tipX) * k;
    tipX += moveX;
    tipY += (targetY - tipY) * k;

    // Lean a little into sideways motion, settle back when still.
    final double leanTarget = dt > 0.0
        ? ((moveX / dt) / 2500.0).clamp(-0.18, 0.18).toDouble()
        : 0.0;
    _lean += (leanTarget - _lean) * (1.0 - math.exp(-dt * 12.0));
  }

  @override
  void render(ui.Canvas canvas) {
    if (!visible || projection.screenHeight <= 0.0) return;
    final double scale = projection.restDartHeightPx / sprites.cellHeight;
    final int pIdx = playerIndex.clamp(0, 1);
    DartRenderer.draw(
      canvas,
      sprites.atlasImage,
      sprites.rest[pIdx],
      tipX,
      tipY,
      scale,
      _lean,
      sprites.dstAtOrigin,
    );
  }
}
