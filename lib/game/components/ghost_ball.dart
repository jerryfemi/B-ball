import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../basketball_game.dart';
import '../physics/ball_physics_3d.dart';
import '../physics/perspective_camera.dart';
import '../telemetry/shot_telemetry.dart';
import 'ball.dart';

/// Translucent replay basketball recreating recorded shots.
///
/// Features:
/// 1. Exact visual parity with regulation basketball (GLSL fragment shader, textures & spin)
/// 2. Rendered at semi-transparent ~55% opacity for clear distinction without sci-fi artifacts
/// 3. Realistic hardwood floor drop shadow and backboard contact shadow
/// 4. Synchronized 3D perspective foreshortening
/// 5. Non-interactive (passes cleanly through live balls with zero user touch capture)
class GhostBasketball extends BodyComponent<BasketballGame> {
  final RecordedShot shot;
  final double radius;

  late final BallPhysics3D physics;
  ui.FragmentShader? _shader;

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
    final program = await Basketball.loadProgram();
    _shader = program?.fragmentShader();
    // Launch recorded trajectory immediately on spawn
    physics.launch(
      Vector3(shot.vx, shot.vy, shot.vz),
      backspin: shot.backspin,
    );
  }

  @override
  void onRemove() {
    _shader?.dispose();
    _shader = null;
    super.onRemove();
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
        categoryBits: 0x0010, // Ghost/replay category
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
    final double fadeOut = physics.timeSinceLaunch > 2.2
        ? (1.0 - (physics.timeSinceLaunch - 2.2) / 1.8).clamp(0.0, 1.0)
        : 1.0;

    // Semi-transparent: 0.55 base opacity, smoothly fading out towards the end
    final double totalOpacity = (0.55 * fadeOut).clamp(0.0, 1.0);
    if (totalOpacity <= 0.01) return;

    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, totalOpacity),
    );

    // 1. Continuous Hardwood Floor Drop Shadow
    final bool onCourtFloor =
        physics.pos.z <= BallPhysics3D.wallZ &&
        physics.pos.x.abs() <= BallPhysics3D.halfWidth;

    if (onCourtFloor) {
      final floorF2D = camera3D.projectToForge2D(
        physics.pos.x,
        0.0,
        physics.pos.z,
      );
      final shadowLocalOffset = Offset(
        floorF2D.dx - body.position.x,
        floorF2D.dy - body.position.y,
      );

      final heightAboveFloor = (physics.pos.y - physics.radius).clamp(0.0, 8.0);
      final shadowAlpha =
          (0.52 / (1.0 + heightAboveFloor * 0.40)).clamp(0.0, 0.52);

      if (shadowAlpha > 0.01) {
        final zScale = camera3D.scaleAtDepth(physics.pos.z);
        final visualRadius = radius * zScale * 1.38;
        final shadowScale = 1.0 + heightAboveFloor * 0.16;
        final shadowRect = Rect.fromCenter(
          center: shadowLocalOffset,
          width: visualRadius * 2.2 * shadowScale,
          height: visualRadius * 0.42 * shadowScale,
        );

        final shadowPaint = Paint()
          ..shader = ui.Gradient.radial(
            shadowLocalOffset,
            visualRadius * 1.1 * shadowScale,
            [
              Color.fromRGBO(0, 0, 0, shadowAlpha),
              Color.fromRGBO(0, 0, 0, shadowAlpha * 0.45),
              const Color(0x00000000),
            ],
            const [0.0, 0.55, 1.0],
          );
        canvas.drawOval(shadowRect, shadowPaint);
      }
    }

    // 2. Dynamic Backboard Glass Proximity Contact Shadow
    final double distToBoard =
        (BallPhysics3D.backboardZ - (physics.pos.z + physics.radius))
            .clamp(0.0, 0.35);
    final bool inBoardFrame =
        physics.pos.x.abs() <= BallPhysics3D.backboardMaxX + 0.05 &&
        physics.pos.y >= BallPhysics3D.backboardMinY - 0.05 &&
        physics.pos.y <= BallPhysics3D.backboardMaxY + 0.05;

    if (distToBoard < 0.35 && inBoardFrame) {
      final double boardProximity = 1.0 - (distToBoard / 0.35);
      final double boardShadowAlpha = (boardProximity * 0.42).clamp(0.0, 0.42);

      if (boardShadowAlpha > 0.01) {
        final double shadowY = physics.pos.y - (0.02 + distToBoard * 0.05);
        final boardF2D = camera3D.projectToForge2D(
          physics.pos.x,
          shadowY,
          BallPhysics3D.backboardZ,
        );
        final boardShadowOffset = Offset(
          boardF2D.dx - body.position.x,
          boardF2D.dy - body.position.y,
        );

        final boardZScale = camera3D.scaleAtDepth(BallPhysics3D.backboardZ);
        final boardVisualRadius = radius * boardZScale * 1.38;
        final shadowSpread = 1.0 + (1.0 - boardProximity) * 0.30;
        final blurMeters =
            (0.03 + (1.0 - boardProximity) * 0.10).clamp(0.02, 0.16);

        final boardShadowPaint = Paint()
          ..color = Color.fromRGBO(0, 0, 0, boardShadowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurMeters);

        final boardShadowRect = Rect.fromCenter(
          center: boardShadowOffset,
          width: boardVisualRadius * 1.9 * shadowSpread,
          height: boardVisualRadius * 1.9 * shadowSpread,
        );
        canvas.drawOval(boardShadowRect, boardShadowPaint);
      }
    }

    // 3. Monotonic Perspective Foreshortening based on exact 3D Z-depth
    final scaleFactor = 1.38 * camera3D.scaleAtDepth(physics.pos.z);

    canvas.save();
    canvas.scale(scaleFactor);

    if (_shader != null) {
      final shader = _shader!;

      final transform = canvas.getTransform();
      final logicalCenterX = transform[12];
      final logicalCenterY = transform[13];
      final logicalScale = math.sqrt(
        transform[0] * transform[0] + transform[1] * transform[1],
      );

      final dpr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;

      final physicalCenterX = logicalCenterX * dpr;
      final physicalCenterY = logicalCenterY * dpr;
      final physicalRadius = radius * logicalScale * dpr;

      shader.setFloat(0, physicalCenterX);
      shader.setFloat(1, physicalCenterY);
      shader.setFloat(2, physicalRadius);
      shader.setFloat(3, physics.yaw);
      shader.setFloat(4, physics.pitch);
      shader.setFloat(5, radius);

      final paint = Paint()..shader = shader;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.2,
        height: radius * 2.2,
      );
      canvas.drawRect(rect, paint);
    } else {
      final paint = Paint()..color = const Color(0xFFFF6F00);
      canvas.drawCircle(Offset.zero, radius, paint);
    }

    canvas.restore();
    canvas.restore(); // Restore opacity saveLayer
  }
}
