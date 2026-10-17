import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../physics/perspective_camera.dart';
import '../telemetry/shot_telemetry.dart';
import 'ball.dart';

/// Translucent replay basketball that extends [Basketball], inheriting
/// 100% of the authentic GLSL fragment shader, 3D perspective foreshortening,
/// and dynamic court shadows with zero code duplication.
class GhostBasketball extends Basketball {
  final RecordedShot shot;

  GhostBasketball({
    required this.shot,
    super.radius = 0.58,
  }) : super(
          initialPosition: Vector2(
            shot.startX * PerspectiveCamera3D.forge2dUnitsPerMeterAtZ0,
            0.0,
          ),
          initialPos3D: Vector3(shot.startX, shot.startY, shot.startZ),
        );

  @override
  double get baseOpacity => 0.55;

  @override
  bool get isLiveBall => false;

  @override
  int get activeStreak => shot.streak;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    physics.launch(
      Vector3(shot.vx, shot.vy, shot.vz),
      backspin: shot.backspin,
    );
  }

  @override
  void onScoredBasket({required bool isSwish, required bool isBankShot}) {
    if (!isMounted) return;
    final pts = shot.points > 0 ? shot.points : (isSwish ? 3 : 2);
    game.onGhostScored(
      points: pts,
      isSwish: isSwish,
      isBankShot: isBankShot,
      // shot.streak is the streak heading into this shot; this callback only
      // fires on a make, so the make extends it (works for live shots too,
      // which are broadcast at launch before isMake is known).
      streak: shot.streak + 1,
    );
  }
}
