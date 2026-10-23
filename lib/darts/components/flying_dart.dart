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

/// Renders the in-flight ballistic dart with perspective scaling and flight spin.
///
/// Follows DARTS_PLAN.md Step 10:
/// - Priority 5 (above stuck darts and board shadows, below resting dart).
/// - Depth scale: $f / (f + z)$ (~1.0 at release down to ~0.15 at the board).
/// - 4.5 revolutions/second spin cycle through pre-rendered 8-frame atlas sprites.
/// - Dynamic flight pitch tilt $\text{atan2}(v_y, -v_z) \times 0.35$ as dart arcs downward.
/// - Zero heap allocations during `update()` and `render()`.
class FlyingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  final DartPhysics physics = DartPhysics();

  /// Associated board shadow component at priority 3.
  late final FlyingDartShadow shadow;

  /// Player index: 0 for P1 (you / sky blue), 1 for P2 / bot (amber).
  int playerIndex = 0;

  /// Whether a dart is currently in flight.
  bool isFlying = false;

  /// Callback fired upon board impact.
  void Function(DartHit hit)? onLanded;

  final vm.Vector2 _screenPos = vm.Vector2.zero();

  FlyingDart({
    required this.projection,
    required this.sprites,
  }) : super(priority: 5) {
    shadow = FlyingDartShadow(flyingDart: this, projection: projection);
  }

  /// Launches a dart with specified 3D velocity vector in meters/second.
  void launch({
    required vm64.Vector3 launchVel,
    int playerIndex = 0,
    void Function(DartHit hit)? onLanded,
  }) {
    this.playerIndex = playerIndex;
    this.onLanded = onLanded;
    physics.launch(launchVel: launchVel);
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
    if (!isFlying) return;

    final double screenH = projection.screenHeight;
    if (screenH <= 0.0) return;

    // 1. Project 3D physics position to screen coordinates
    projection.projectFlightPosition(
      physics.pos.x,
      physics.pos.y,
      physics.pos.z,
      _screenPos,
    );

    // 2. Perspective depth scale (~1.0 at launch down to ~0.15 at board)
    final double depth = projection.depthScale(physics.pos.z);
    final double restScale =
        (screenH * DartsK.restingDartHeightFrac) / sprites.cellHeight;
    final double scale = restScale * depth;

    // 3. Spin frame index: 18 cycles/sec for 4-flight symmetry (~4.5 rps)
    final int pIdx = playerIndex.clamp(0, 1);
    final List<ui.Rect> spinList = sprites.spin[pIdx];
    final int spinCount = spinList.length;
    final int spinIdx =
        (physics.flightTime * 18.0 * spinCount).floor() % spinCount;
    final ui.Rect src = spinList[spinIdx];

    // 4. Aerodynamic flight orientation: pitch tilt + lateral lean
    final double fwdSpeed = math.max(-physics.vel.z, 0.1);
    final double lateralYaw = math.atan2(physics.vel.x, fwdSpeed);
    final double pitchDown = math.atan2(physics.vel.y, fwdSpeed) * 0.35;
    final double angle = (lateralYaw * 0.5) + pitchDown;

    // 5. Draw sprite with zero allocations
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
