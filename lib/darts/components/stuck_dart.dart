import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import '../physics/flick_solver.dart';
import '../scene/board_projection.dart';
import 'dart_renderer.dart';
import 'dart_sprites.dart';

/// A dart stuck in the board, drawn in 3D from the angle-sweep sheet.
///
/// - Its tip sits exactly on the hit point; its axis is the direction it was
///   flying when it hit (so it points slightly down, the way it dipped in).
///   Seen from the oche that is almost tail-on: the X of the flights.
/// - It casts a short shadow below it on the board.
/// - Impact wobble about the tip for [DartsK.stuckWobbleDurationSec].
/// - [startPull] fades it out over [DartsK.dartPullFadeSec], then removes it.
/// - Priority 4: above the board and the flying dart's shadow.
/// - Zero heap allocations in `update()` and `render()`.
class StuckDart extends Component {
  final BoardProjection projection;
  final DartSprites sprites;
  final DartHit hit;

  /// Kept for callers; both players use the same dart.
  final int playerIndex;

  /// Unit axis (tail → tip) at impact.
  final double axisX;
  final double axisY;
  final double axisZ;

  /// Spin frame it stopped on.
  final int spinColumn;

  double _wobbleTime = 0.0;
  static const double _maxWobbleRad = 3.0 * math.pi / 180.0;

  bool _isPulling = false;
  double _pullTime = 0.0;
  double _opacity = 1.0;

  StuckDart({
    required this.projection,
    required this.sprites,
    required this.hit,
    this.playerIndex = 0,
    double? axisX,
    double? axisY,
    double? axisZ,
    int? spinColumn,
  })  : axisX = axisX ?? impactAxis(hit.x, hit.y).x,
        axisY = axisY ?? impactAxis(hit.x, hit.y).y,
        axisZ = axisZ ?? impactAxis(hit.x, hit.y).z,
        spinColumn = spinColumn ?? ((hit.x * 7.0 + hit.y * 13.0).abs().floor()),
        super(priority: 4);

  /// The axis a dart thrown from the hand at rest would have when it hits
  /// (board mm). Used for darts that appear without a local flight
  /// (restored online turns).
  static ({double x, double y, double z}) impactAxis(double hitXMm, double hitYMm) {
    final v = FlickSolver.launchFor(hitXMm, hitYMm, DartsK.idealSpeed);
    final double t = DartsK.throwDistanceM / -v.z;
    final double vx = v.x;
    final double vy = (v.y - DartsK.gravity * t) * DartsK.flightPitchGain;
    final double vz = v.z;
    final double l = math.sqrt(vx * vx + vy * vy + vz * vz);
    return (x: vx / l, y: vy / l, z: vz / l);
  }

  void startPull() {
    _isPulling = true;
    _pullTime = 0.0;
  }

  /// Wobble rotation (radians) at the current time after impact.
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
      final double progress =
          (_pullTime / DartsK.dartPullFadeSec).clamp(0.0, 1.0).toDouble();
      _opacity = 1.0 - progress;
      if (progress >= 1.0) {
        removeFromParent();
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_opacity <= 0.0 || projection.screenHeight <= 0.0) return;
    final double tx = hit.x / 1000.0;
    final double ty = hit.y / 1000.0;
    final double wobble = wobbleAngle;

    DartRenderer.drawShadow(
      canvas,
      sprites,
      projection,
      tx,
      ty,
      0.0,
      axisX,
      axisY,
      axisZ,
      spinColumn,
      0.38 * _opacity,
      extraRotation: wobble * 0.5,
    );
    DartRenderer.draw3D(
      canvas,
      sprites,
      projection,
      tx,
      ty,
      0.0,
      axisX,
      axisY,
      axisZ,
      spinColumn,
      extraRotation: wobble,
      opacity: _opacity,
    );
  }
}
