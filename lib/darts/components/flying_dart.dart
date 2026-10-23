import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

import '../darts_constants.dart';
import '../physics/dart_physics.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// Pre-rendered soft shadow component cast onto the dartboard plane.
///
/// Follows DARTS_PLAN.md Step 10:
/// - Priority 3 (drawn above dartboard, below stuck darts and flying dart).
/// - Pre-blurred ellipse `ui.Image` generated once in `onLoad` (zero MaskFilter runtime cost).
/// - Shadow tightens and darkens as $z \to 0$ (approaching board impact).
/// - Zero per-frame heap allocations.
class FlyingDartShadow extends Component {
  final FlyingDart flyingDart;
  final BoardProjection projection;

  ui.Image? _shadowImage;
  static const double _imgSize = 64.0;
  static final ui.Rect _srcRect = const ui.Rect.fromLTWH(0, 0, _imgSize, _imgSize);
  static final ui.Rect _dstAtOrigin = const ui.Rect.fromLTWH(
    -_imgSize * 0.5,
    -_imgSize * 0.5,
    _imgSize,
    _imgSize,
  );

  final ui.Paint _shadowPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  final vm.Vector2 _shadowPos = vm.Vector2.zero();

  FlyingDartShadow({
    required this.flyingDart,
    required this.projection,
  }) : super(priority: 3);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _shadowImage = await _createShadowImage();
  }

  static Future<ui.Image> _createShadowImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    const double size = _imgSize;
    final ui.Rect rect = const ui.Rect.fromLTWH(0, 0, size, size);

    final ui.Paint paint = ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(size * 0.5, size * 0.5),
        size * 0.5,
        const [
          ui.Color(0xD0000000), // Dense core (~82% black)
          ui.Color(0x60000000), // Mid falloff
          ui.Color(0x00000000), // Transparent edge
        ],
        const [0.0, 0.45, 1.0],
      );

    canvas.drawOval(rect, paint);
    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }

  @override
  void render(ui.Canvas canvas) {
    if (!flyingDart.isFlying || _shadowImage == null) return;

    final DartPhysics physics = flyingDart.physics;

    // Projected position on the board face in screen pixels
    projection.boardMmToScreen(
      physics.pos.x * 1000.0,
      physics.pos.y * 1000.0,
      _shadowPos,
    );

    // Distance fraction from board: 1.0 at launch (2.37 m), 0.0 at impact (0.0 m)
    final double zFrac =
        (physics.pos.z / DartsK.throwDistanceM).clamp(0.0, 1.0);

    // Shadow offset from overhead light collapses to (0, 0) on board impact
    _shadowPos.y += 24.0 * zFrac * (projection.screenHeight / 800.0);
    _shadowPos.x += 6.0 * zFrac * (projection.screenWidth / 450.0);

    // Shadow tightens and darkens as dart nears the board
    final double alpha = (0.75 - 0.60 * zFrac).clamp(0.05, 0.85);
    _shadowPaint.color =
        ui.Color.fromARGB((alpha * 255.0).round(), 255, 255, 255);

    // Shadow scale: larger & more diffuse at release, tight at board impact
    final double targetWidth = 18.0 + 44.0 * zFrac;
    final double targetHeight = 10.0 + 22.0 * zFrac;
    final double scaleX = targetWidth / _imgSize;
    final double scaleY = targetHeight / _imgSize;

    canvas.save();
    canvas.translate(_shadowPos.x, _shadowPos.y);
    canvas.scale(scaleX, scaleY);
    canvas.drawImageRect(_shadowImage!, _srcRect, _dstAtOrigin, _shadowPaint);
    canvas.restore();
  }

  @override
  void onRemove() {
    _shadowImage?.dispose();
    super.onRemove();
  }
}

/// The dart in flight: a lob from your hand that drops into the board.
///
/// - Physics ([DartPhysics], fixed 240 Hz) decides where it lands.
/// - On screen it travels from where it left your hand to the landing point
///   along an eased path (fast out of the hand, slowing as it gets far) with
///   an arc on top, so it rises and then drops in like a real throw instead
///   of sliding up in a straight line.
/// - It shrinks from the resting size to the stuck size, spins (8 frames)
///   and leans into its sideways motion.
/// - Zero heap allocations in `update()` and `render()`.
class FlyingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  final DartPhysics physics = DartPhysics();

  /// Associated board shadow component at priority 3.
  late final FlyingDartShadow shadow;

  /// Sprite row (0 = you, 1 = opponent / bot).
  int playerIndex = 0;

  /// Whether a dart is currently in flight.
  bool isFlying = false;

  /// Callback fired upon board impact.
  void Function(DartHit hit)? onLanded;

  // Screen path, fixed at launch (px).
  double _startX = 0.0;
  double _startY = 0.0;
  final vm.Vector2 _landPx = vm.Vector2.zero();

  /// How strongly the path eases out (higher = more "into the distance").
  static const double _ease = 1.7;

  FlyingDart({
    required this.projection,
    required this.sprites,
  }) : super(priority: 5) {
    shadow = FlyingDartShadow(flyingDart: this, projection: projection);
  }

  /// Launches a dart with [launchVel] (m/s). The flight is drawn from
  /// ([startPxX], [startPxY]), the tip of the dart in hand; defaults to the
  /// resting spot (bot and opponent throws).
  void launch({
    required vm64.Vector3 launchVel,
    int playerIndex = 0,
    void Function(DartHit hit)? onLanded,
    double? startPxX,
    double? startPxY,
  }) {
    this.playerIndex = playerIndex;
    this.onLanded = onLanded;
    physics.launch(launchVel: launchVel);
    _startX = startPxX ?? projection.handX;
    _startY = startPxY ?? projection.handY;

    // Where it will land: vz is constant, so the flight time is exact.
    final double vz = launchVel.z.abs() < 1e-6 ? -1e-6 : launchVel.z;
    final double t = DartsK.throwDistanceM / -vz;
    final double landX = launchVel.x * t * 1000.0;
    final double landY = (launchVel.y * t - 0.5 * DartsK.gravity * t * t) * 1000.0;
    projection.boardMmToScreen(landX, landY, _landPx);
    isFlying = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isFlying) return;

    physics.update(dt);

    if (physics.hasHit) {
      isFlying = false;
      final DartHit hit = DartScoring.score(physics.hitX, physics.hitY);
      onLanded?.call(hit);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!isFlying || projection.screenHeight <= 0.0) return;

    // 0 at release, 1 at the board (vz is constant, so this is also time).
    final double f = ((DartsK.throwDistanceM - physics.pos.z) /
            DartsK.throwDistanceM)
        .clamp(0.0, 1.0)
        .toDouble();

    // Eased progress along the path and the lob on top of it.
    final double rest = 1.0 - f;
    final double p = 1.0 - math.pow(rest, _ease).toDouble();
    final double arc = projection.flightArcPx;
    final double x = _startX + (_landPx.x - _startX) * p;
    final double y = _startY + (_landPx.y - _startY) * p - arc * math.sin(math.pi * f);

    // Shrinks from the in-hand size to the stuck size.
    final double heightPx = projection.restDartHeightPx +
        (projection.stuckDartHeightPx - projection.restDartHeightPx) * p;
    final double scale = heightPx / sprites.cellHeight;

    // Spin: 8 frames cover 90°, looping (four flights).
    final int pIdx = playerIndex.clamp(0, 1);
    final List<ui.Rect> spinList = sprites.spin[pIdx];
    final int spinCount = spinList.length;
    final int spinIdx =
        (physics.flightTime * DartsK.flightSpinRps * 4.0 * spinCount).floor() %
            spinCount;

    // Lean into the sideways motion (screen-space slope of the path).
    final double dpdf = _ease * math.pow(rest, _ease - 1.0).toDouble();
    final double dxdf = (_landPx.x - _startX) * dpdf;
    final double dydf = (_landPx.y - _startY) * dpdf - arc * math.pi * math.cos(math.pi * f);
    final double angle =
        (math.atan(dxdf / (dydf.abs() + 40.0)) * 0.8).clamp(-0.6, 0.6).toDouble();

    DartRenderer.draw(
      canvas,
      sprites.atlasImage,
      spinList[spinIdx],
      x,
      y,
      scale,
      angle,
      sprites.dstAtOrigin,
    );
  }
}
