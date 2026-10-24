import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

import '../darts_constants.dart';
import '../physics/dart_physics.dart';
import '../physics/dart_scoring.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// The flying dart's shadow on the board: a dart-shaped silhouette that slides
/// in from below and meets the tip at the moment of impact.
///
/// Priority 3: above the board, below stuck darts and the flying dart.
class FlyingDartShadow extends Component {
  final FlyingDart flyingDart;
  final BoardProjection projection;
  final DartSprites sprites;

  FlyingDartShadow({
    required this.flyingDart,
    required this.projection,
    required this.sprites,
  }) : super(priority: 3);

  @override
  void render(ui.Canvas canvas) {
    final FlyingDart d = flyingDart;
    if (!d.isFlying) return;
    final vm64.Vector3 pos = d.physics.pos;
    // Faint far away, darker as the dart nears the board.
    final double near = 1.0 - (pos.z / DartsK.throwDistanceM).clamp(0.0, 1.0).toDouble();
    DartRenderer.drawShadow(
      canvas,
      sprites,
      projection,
      pos.x,
      pos.y,
      pos.z,
      d.axisX,
      d.axisY,
      d.axisZ,
      d.spinColumn,
      0.16 + 0.32 * near,
    );
  }
}

/// The dart in flight, drawn in true perspective.
///
/// - Physics ([DartPhysics], fixed 240 Hz ballistic) moves the tip; the
///   camera ([BoardProjection]) puts it on screen, so it starts big in your
///   hand, shrinks fast as it flies away, rises a little and drops in.
/// - The dart turns from its in-hand pose to point along its velocity over
///   the first part of the flight, then follows the velocity (pitch
///   exaggerated by [DartsK.flightPitchGain]) so it visibly dips into the board.
/// - Drawn from the angle-sweep sheet, so the view changes from the long body
///   to the tail-on X of the flights as it goes.
/// - Zero heap allocations in `update()` and `render()`.
class FlyingDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;

  final DartPhysics physics = DartPhysics();

  /// Shadow component (priority 3).
  late final FlyingDartShadow shadow;

  /// Kept for callers; both players use the same dart.
  int playerIndex = 0;

  bool isFlying = false;

  /// Called on impact.
  void Function(DartHit hit)? onLanded;

  /// Current unit axis (tail → tip), physics space.
  double axisX = 0.0;
  double axisY = 0.0;
  double axisZ = -1.0;

  /// Current spin frame.
  int spinColumn = 0;

  // In-hand pose at release (unit axis).
  double _handAx = 0.0;
  double _handAy = 0.0;
  double _handAz = -1.0;
  double _flightTime = 1.0;
  int _spinStart = 0;

  FlyingDart({
    required this.projection,
    required this.sprites,
  }) : super(priority: 5) {
    shadow = FlyingDartShadow(
      flyingDart: this,
      projection: projection,
      sprites: sprites,
    );
  }

  /// Launches a dart with [launchVel] (m/s) from ([startXm], [startYm]) at the
  /// release distance. [handPitch]/[handYaw] (radians) are the pose it had in
  /// your hand; it eases from there into its flight direction.
  void launch({
    required vm64.Vector3 launchVel,
    int playerIndex = 0,
    void Function(DartHit hit)? onLanded,
    double startXm = 0.0,
    double startYm = 0.0,
    double handPitch = DartsK.handPitchDeg * math.pi / 180.0,
    double handYaw = 0.0,
    int spinStart = 0,
  }) {
    this.playerIndex = playerIndex;
    this.onLanded = onLanded;
    physics.launch(launchVel: launchVel, startX: startXm, startY: startYm);

    final double cp = math.cos(handPitch);
    _handAx = math.sin(handYaw) * cp;
    _handAy = math.sin(handPitch);
    _handAz = -math.cos(handYaw) * cp;
    axisX = _handAx;
    axisY = _handAy;
    axisZ = _handAz;

    final double vz = launchVel.z.abs() < 1e-6 ? -1e-6 : launchVel.z;
    _flightTime = DartsK.throwDistanceM / -vz;
    _spinStart = spinStart;
    spinColumn = spinStart % sprites.spinColumns;
    isFlying = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isFlying) return;

    physics.update(dt);
    _updatePose();

    if (physics.hasHit) {
      isFlying = false;
      final DartHit hit = DartScoring.score(physics.hitX, physics.hitY);
      onLanded?.call(hit);
    }
  }

  void _updatePose() {
    // Direction of travel, pitch exaggerated so the rise and dip read.
    final vm64.Vector3 v = physics.vel;
    double fx = v.x;
    double fy = v.y * DartsK.flightPitchGain;
    double fz = v.z;
    double fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fl < 1e-9) fl = 1.0;
    fx /= fl;
    fy /= fl;
    fz /= fl;

    // Ease from the in-hand pose into the flight direction.
    final double f = (physics.flightTime / _flightTime).clamp(0.0, 1.0).toDouble();
    double w = (f / DartsK.launchSettleFrac).clamp(0.0, 1.0).toDouble();
    w = w * w * (3.0 - 2.0 * w);
    final double ax = _handAx + (fx - _handAx) * w;
    final double ay = _handAy + (fy - _handAy) * w;
    final double az = _handAz + (fz - _handAz) * w;
    double al = math.sqrt(ax * ax + ay * ay + az * az);
    if (al < 1e-9) al = 1.0;
    axisX = ax / al;
    axisY = ay / al;
    axisZ = az / al;

    // Spin: the sheet covers spinDegrees; turn at flightSpinRps.
    final double steps = physics.flightTime *
        DartsK.flightSpinRps *
        (360.0 / sprites.spinDegrees) *
        sprites.spinColumns;
    spinColumn = (_spinStart + steps.floor()) % sprites.spinColumns;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!isFlying || projection.screenHeight <= 0.0) return;
    final vm64.Vector3 pos = physics.pos;
    DartRenderer.draw3D(
      canvas,
      sprites,
      projection,
      pos.x,
      pos.y,
      pos.z,
      axisX,
      axisY,
      axisZ,
      spinColumn,
    );
  }
}
