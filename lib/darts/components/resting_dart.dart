import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// The dart in your hand, drawn in 3D at the release point: big, near the
/// bottom of the screen, pointing up at the board so its body shows, with
/// the flights running off the bottom edge.
///
/// - Follows the finger left and right; only lifts a little when you drag
///   up (GamePigeon style), and leans into sideways motion.
/// - [startXm]/[startYm] are where a throw leaves your hand (physics metres),
///   [pitch]/[yaw] the pose it leaves with.
/// - Zero heap allocations in `update()` and `render()`.
class RestingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  /// Kept for callers; both players use the same dart.
  int playerIndex;

  /// Hidden while a dart flies and on the opponent's turn.
  bool visible = true;

  bool _holding = false;
  double _fingerX = 0.0;
  double _fingerY = 0.0;
  double _pickupY = 0.0;

  /// Current (smoothed) tip position in screen px.
  double tipX = 0.0;
  double tipY = 0.0;
  double _lean = 0.0;
  bool _placed = false;

  /// Spin frame shown in hand (changes per dart, so each looks a bit different).
  int spinColumn = 2;

  RestingDart({
    required this.projection,
    required this.sprites,
    this.playerIndex = 0,
  }) : super(priority: 6);

  /// In-hand pose (radians).
  double get pitch => DartsK.handPitchDeg * math.pi / 180.0;
  double get yaw => _lean;

  /// Where a throw starts (physics metres at the release distance).
  double get startXm {
    projection.unproject(tipX, tipY, DartsK.throwDistanceM);
    return projection.outX;
  }

  double get startYm {
    projection.unproject(tipX, tipY, DartsK.throwDistanceM);
    return projection.outY;
  }

  /// Called every frame with the finger state from the flick controller.
  void setHold(bool holding, double fingerX, double fingerY) {
    if (holding && !_holding) _pickupY = fingerY;
    _holding = holding;
    _fingerX = fingerX;
    _fingerY = fingerY;
  }

  /// Puts the dart straight back at rest (new dart, new turn).
  void resetToRest() {
    _holding = false;
    tipX = projection.handX;
    tipY = projection.handY;
    _lean = 0.0;
    _placed = true;
    spinColumn = (spinColumn + 3) % sprites.spinColumns;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (projection.screenHeight <= 0.0) return;
    if (!_placed) resetToRest();

    final double h = projection.screenHeight;
    double targetX = projection.handX;
    double targetY = projection.handY;
    if (_holding) {
      final double margin = projection.screenWidth * 0.12;
      targetX = _fingerX.clamp(margin, projection.screenWidth - margin).toDouble();
      // Barely lifts: a third of the drag, capped.
      targetY = projection.handY +
          ((_fingerY - _pickupY) * 0.35)
              .clamp(-DartsK.handLiftFrac * h, 0.015 * h)
              .toDouble();
    }

    final double k = 1.0 - math.exp(-dt * 28.0);
    final double moveX = (targetX - tipX) * k;
    tipX += moveX;
    tipY += (targetY - tipY) * k;

    // Turn a little toward sideways motion (yaw), settle back when still.
    final double leanTarget = dt > 0.0
        ? ((moveX / dt) / 3000.0).clamp(-0.25, 0.25).toDouble()
        : 0.0;
    _lean += (leanTarget - _lean) * (1.0 - math.exp(-dt * 12.0));
  }

  @override
  void render(ui.Canvas canvas) {
    if (!visible || projection.screenHeight <= 0.0) return;
    projection.unproject(tipX, tipY, DartsK.throwDistanceM);
    final double x = projection.outX;
    final double y = projection.outY;
    final double p = pitch;
    final double cp = math.cos(p);
    DartRenderer.draw3D(
      canvas,
      sprites,
      projection,
      x,
      y,
      DartsK.throwDistanceM,
      math.sin(_lean) * cp,
      math.sin(p),
      -math.cos(_lean) * cp,
      spinColumn,
    );
  }
}
