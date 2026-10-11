import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../basketball_game.dart';
import '../physics/ball_physics_3d.dart';
import '../physics/perspective_camera.dart';
import '../telemetry/shot_telemetry.dart';

/// Holographic ghost basketball replaying an opponent's recorded shot.
///
/// Features:
/// 1. Pure ballistic 3D physics matching live basketball kinematics
/// 2. Ethereal translucent neon cyan aesthetic with halo glow & basketball ribbing
/// 3. Synchronized 3D perspective foreshortening & dynamic floor drop shadow
/// 4. Non-interactive (zero touch drag callbacks, passes cleanly through live balls)
/// 5. Automatically dispatches ghost score notifications to the dual scoreboard
class GhostBasketball extends BodyComponent<BasketballGame> {
  final RecordedShot shot;
  final double radius;

  late final BallPhysics3D physics;

  PerspectiveCamera3D? _cachedCamera;
  Vector2? _lastCameraSize;

  PerspectiveCamera3D get camera3D {
    if (_cachedCamera == null || _lastCameraSize != game.size) {
      _lastCameraSize = game.size.clone();
      _cachedCamera = PerspectiveCamera3D.standard(game.size.x, game.size.y);
    }
    return _cachedCamera!;
  }

  GhostBasketball({
    required this.shot,
    this.radius = 0.58,
  }) : super(priority: 4) {
    physics = BallPhysics3D(
      initialPos: Vector3(shot.startX, shot.startY, shot.startZ),
      radius: 0.125,
      onScored: ({required bool isSwish, required bool isBankShot}) {
        if (!isMounted) return;
        final pts = shot.points > 0 ? shot.points : (isSwish ? 3 : 2);
        game.onGhostScored(
          points: pts,
          isSwish: isSwish,
          isBankShot: isBankShot,
        );
      },
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Launch recorded trajectory immediately on spawn
    physics.launch(
      Vector3(shot.vx, shot.vy, shot.vz),
      backspin: shot.backspin,
    );
  }

  @override
  Body createBody() {
    final startF2D = camera3D.projectToForge2D(
      shot.startX,
      shot.startY,
      shot.startZ,
    );
    final bodyDef = BodyDef(
      type: BodyType.kinematic,
      position: Vector2(startF2D.dx, startF2D.dy),
    );

    final body = world.createBody(bodyDef);
    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(friction: 0.8, restitution: 0.82),
      filter: forge2d.Filter(
        categoryBits: 0x0010, // Ghost category
        maskBits: 0, // Zero physical collision with live balls
      ),
    );
    body.createShape(forge2d.Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!physics.isLaunched) return;

    // Substep physics simulation
    final subDt = dt / 4.0;
    for (int i = 0; i < 4; i++) {
      physics.update(subDt);
    }

    if (physics.timeSinceLaunch > 4.0) {
      removeFromParent();
      return;
    }

    final f2d = camera3D.projectToForge2D(
      physics.pos.x,
      physics.pos.y,
      physics.pos.z,
    );
    body.setTransform(Vector2(f2d.dx, f2d.dy), const forge2d.Rot.identity());

    _updateRenderPriority();
  }

  void _updateRenderPriority() {
    final bool inRimZone =
        physics.pos.z >=
            (BallPhysics3D.rimCenter.z - BallPhysics3D.rimRadius) &&
        physics.pos.y <= (BallPhysics3D.rimCenter.y + 0.50) &&
        physics.pos.y >= (BallPhysics3D.rimCenter.y - 0.50);

    if (physics.pos.z > BallPhysics3D.backboardZ) {
      priority = 0;
    } else if (physics.pos.z > BallPhysics3D.rimCenter.z ||
        inRimZone ||
        (physics.passedThroughRim &&
            physics.pos.y <= BallPhysics3D.rimCenter.y &&
            physics.pos.y >= BallPhysics3D.netBottomY)) {
      priority = 2;
    } else {
      priority = 4;
    }
  }

  @override
  void render(Canvas canvas) {
    final double opacity = physics.timeSinceLaunch > 2.2
        ? (1.0 - (physics.timeSinceLaunch - 2.2) / 1.8).clamp(0.0, 1.0)
        : 1.0;

    if (opacity <= 0.01) return;

    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );

    // 1. Ethereal Cyan Floor Drop Shadow
    final bool onCourtFloor =
        physics.pos.z <= BallPhysics3D.wallZ &&
        physics.pos.x.abs() <= BallPhysics3D.halfWidth;

    if (onCourtFloor) {
      final floorF2D = camera3D.projectToForge2D(
        physics.pos.x,
        0.0,
        physics.pos.z,
      );
      final floorOffset = Offset(
        floorF2D.dx - body.position.x,
        floorF2D.dy - body.position.y,
      );

      final double maxDropH = (BallPhysics3D.rimCenter.y + 1.5).clamp(
        1.0,
        10.0,
      );
      final double floorProximity =
          (1.0 - (physics.pos.y / maxDropH)).clamp(0.0, 1.0);
      final double zScale = camera3D.scaleAtDepth(physics.pos.z);
      final double visualRadius = radius * zScale * 1.38;
      final double shadowSpread = 0.50 + (1.0 - floorProximity) * 1.10;

      final shadowRect = Rect.fromCenter(
        center: floorOffset,
        width: visualRadius * 2.0 * shadowSpread,
        height: visualRadius * 0.70 * shadowSpread,
      );

      final shadowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(56, 189, 248, 0.40 * floorProximity),
            Color.fromRGBO(14, 165, 233, 0.15 * floorProximity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(shadowRect);

      canvas.drawOval(shadowRect, shadowPaint);
    }

    // 2. 3D Scale Foreshortening
    final scaleFactor = 1.38 * camera3D.scaleAtDepth(physics.pos.z);
    canvas.save();
    canvas.scale(scaleFactor);

    // Outer cyan halo aura
    final haloPaint = Paint()
      ..color = const Color(0x5538BDF8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.18);
    canvas.drawCircle(Offset.zero, radius * 1.12, haloPaint);

    // Holographic core sphere
    final coreRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final corePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.40),
        radius: 0.90,
        colors: [
          Color(0xF0E0F2FE), // Bright neon cyan specular apex
          Color(0xCC38BDF8), // Electric cyan body
          Color(0x990284C7), // Deep azure rim
          Color(0x660369A1), // Soft perimeter shadow
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(coreRect);
    canvas.drawCircle(Offset.zero, radius, corePaint);

    // Glowing basketball seam markings
    final seamPaint = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035;

    // Outer perimeter rim stroke
    canvas.drawCircle(Offset.zero, radius, seamPaint);

    // Horizontal equator seam
    canvas.drawLine(
      Offset(-radius * 0.92, 0),
      Offset(radius * 0.92, 0),
      seamPaint,
    );

    // Curved side ribs
    final ribPath = Path()
      ..moveTo(0, -radius * 0.92)
      ..quadraticBezierTo(radius * 0.55, 0, 0, radius * 0.92)
      ..moveTo(0, -radius * 0.92)
      ..quadraticBezierTo(-radius * 0.55, 0, 0, radius * 0.92);
    canvas.drawPath(ribPath, seamPaint);

    canvas.restore();
    canvas.restore();
  }
}
