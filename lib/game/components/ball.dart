import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../basketball_game.dart';
import '../physics/ball_physics_3d.dart';
import '../physics/perspective_camera.dart';
import '../physics/launch_solver.dart';

/// Basketball component featuring true 3D projectile kinematics,
/// exact 3D Torus rim collision, backboard glass bounce, hardwood floor roll,
/// and continuous ground drop shadow within the 1-point perspective gymnasium.
class Basketball extends BodyComponent<BasketballGame> with DragCallbacks {
  final Vector2 initialPosition;
  final double radius;
  final VoidCallback? onLaunched;
  final bool animateEntrance;

  // 3D physics simulator
  late final BallPhysics3D physics;

  // 3D perspective camera for projection
  PerspectiveCamera3D get camera3D =>
      PerspectiveCamera3D.standard(game.size.x, game.size.y);

  ui.FragmentProgram? _program;
  bool isEntering = false;
  double enterProgress = 0.0;

  Vector2? _dragStartPos;
  Vector2? _lastDragPos;
  int? _dragStartTimeMs;

  Basketball({
    required this.initialPosition,
    this.radius = 0.58,
    this.onLaunched,
    this.animateEntrance = false,
  }) : super(priority: 5) {
    physics = BallPhysics3D(
      initialPos: Vector3(0.0, 0.25, 0.0),
      radius: 0.125,
    );
    if (animateEntrance) {
      isEntering = true;
      physics.pos.y = -0.4; // Start slightly below floor level for smooth slide-in
    }
  }

  // Getters for game visual listeners (FrontRimVisual, BackboardVisual, etc.)
  bool get isLaunched => physics.isLaunched;
  bool get passedThroughRim => physics.passedThroughRim;
  bool get hasClankedFrontRim => physics.hasClankedRim;
  bool get hasBankedBackboard => physics.hasBankedBackboard;
  double get timeSinceLaunch => physics.timeSinceLaunch;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/basketball.frag');
    } catch (e) {
      debugPrint('Failed to load basketball shader: $e');
    }
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.kinematic,
      position: initialPosition,
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(friction: 0.8, restitution: 0.82),
      filter: forge2d.Filter(
        categoryBits: 0x0008, // Basketball category
        maskBits: 0, // True 3D physics handles all collisions!
      ),
    );

    body.createShape(forge2d.Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth Feeder Entrance: glide up from below into ready position
    if (isEntering && !isLaunched) {
      enterProgress += dt / 0.35;
      if (enterProgress >= 1.0) {
        enterProgress = 1.0;
        isEntering = false;
      }
      final t = Curves.easeOutCubic.transform(enterProgress);
      physics.pos.y = ui.lerpDouble(-0.4, 0.25, t)!;
      final f2d = camera3D.projectToForge2D(
        physics.pos.x,
        physics.pos.y,
        physics.pos.z,
      );
      body.setTransform(Vector2(f2d.dx, f2d.dy), const forge2d.Rot.identity());
      return;
    }

    if (isLaunched) {
      // 1. Advance the 3D physics engine (substeps, torus rim, backboard, floor)
      physics.update(dt);

      // 2. Lifecycle cleanup: remove spent balls lingering on court after 6 seconds
      if (physics.timeSinceLaunch > 6.0) {
        removeFromParent();
        return;
      }

      // 3. Project 3D coordinate to Forge2D world meters
      final f2d = camera3D.projectToForge2D(
        physics.pos.x,
        physics.pos.y,
        physics.pos.z,
      );
      body.setTransform(Vector2(f2d.dx, f2d.dy), const forge2d.Rot.identity());

      // Downward velocity in Forge2D space (+Y is down)
      final f2dVelY = physics.vel.y < 0
          ? physics.vel.y.abs() * 1.5
          : -physics.vel.y * 1.5;
      body.linearVelocity = Vector2(physics.vel.x, f2dVelY);

      // 4. Dynamic 3D depth layering
      _updateRenderPriority();
    }
  }

  void _updateRenderPriority() {
    if (physics.passedThroughRim &&
        physics.pos.y <= BallPhysics3D.rimCenter.y &&
        physics.pos.y >= BallPhysics3D.netBottomY) {
      // Inside net cylinder: backboard (priority 1) < ball (priority 2) < front rim (priority 3)
      priority = 2;
    } else {
      // In foreground / in front of hoop
      priority = 5;
    }
  }

  @override
  void render(Canvas canvas) {
    // Fade out over the last 3 seconds of the 6-second lifetime
    final double opacity = physics.timeSinceLaunch > 3.0
        ? (1.0 - (physics.timeSinceLaunch - 3.0) / 3.0).clamp(0.0, 1.0)
        : 1.0;

    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );

    // 1. Continuous Hardwood Floor Drop Shadow
    // Shadow is calculated at (physics.pos.x, 0.0, physics.pos.z) on the court floor
    final floorF2D = camera3D.projectToForge2D(
      physics.pos.x,
      0.0,
      physics.pos.z,
    );
    final shadowLocalOffset = Offset(
      floorF2D.dx - body.position.x,
      floorF2D.dy - body.position.y,
    );

    final heightAboveFloor =
        (physics.pos.y - physics.radius).clamp(0.0, 8.0);
    final shadowAlpha =
        ((0.52 / (1.0 + heightAboveFloor * 0.40)) * opacity).clamp(0.0, 0.52);

    if (shadowAlpha > 0.01) {
      final zScale = camera3D.scaleAtDepth(physics.pos.z);
      final visualRadius = radius * zScale * 1.38;
      final shadowScale = 1.0 + heightAboveFloor * 0.16;
      final blurMeters = (0.05 + heightAboveFloor * 0.06).clamp(0.05, 0.35);

      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurMeters);

      final shadowRect = Rect.fromCenter(
        center: shadowLocalOffset,
        width: visualRadius * 2.2 * shadowScale,
        height: visualRadius * 0.42 * shadowScale, // Perspective flattening
      );
      canvas.drawOval(shadowRect, shadowPaint);
    }

    // 2. Monotonic Perspective Foreshortening based on exact 3D Z-depth
    final scaleFactor = 1.38 * camera3D.scaleAtDepth(physics.pos.z);

    canvas.save();
    canvas.scale(scaleFactor);

    if (_program != null) {
      final shader = _program!.fragmentShader();

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

  @override
  bool containsPoint(Vector2 point) {
    if (isLaunched || isEntering) return false;
    final dist = (point - body.position).length;
    return dist <= radius * 2.5;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isLaunched && !isEntering) {
      _dragStartPos = event.canvasPosition;
      _lastDragPos = event.canvasPosition;
      _dragStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isLaunched && !isEntering) {
      _lastDragPos = event.canvasEndPosition;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (isLaunched || isEntering) return;

    double finalVx = event.velocity.x;
    double finalVy = event.velocity.y;
    Vector2? delta;

    if (_dragStartPos != null &&
        _lastDragPos != null &&
        _dragStartTimeMs != null) {
      delta = _lastDragPos! - _dragStartPos!;
      final dtSec =
          (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!).clamp(
            40,
            500,
          ) /
          1000.0;
      final dispVy = delta.y / dtSec;
      final dispVx = delta.x / dtSec;

      // Use displacement velocity if it was a faster upward flick
      if (dispVy < finalVy) {
        finalVy = dispVy;
        finalVx = dispVx;
      }
    }

    // Only launch when swiped upwards toward the hoop
    final isUpward = finalVy <= -40.0 || (delta != null && delta.y <= -25.0);
    if (!isUpward) return;

    // Upward swipe velocity in pixels/second
    final swipeSpeedY = finalVy.abs();
    // Lateral swipe ratio (aim angle dx / |dy|)
    final swipeRatioX = (finalVx / swipeSpeedY).clamp(-0.8, 0.8);

    // Dynamic swipe calibration with 50% reduced speed threshold:
    // - Under 350 px/s: weak flick -> 0.60 to 0.88 (short arc, front rim clank or key landing)
    // - 350 to 1100 px/s: natural swipe -> 0.88 to 1.08 (sweet spot centered at ~800 px/s for swishes & soft bank shots)
    // - 1100+ px/s: aggressive swipe -> 1.08 to 1.25 (deep backboard bank)
    double powerRatio;
    if (swipeSpeedY < 350.0) {
      powerRatio = 0.60 + (swipeSpeedY / 350.0) * 0.28;
    } else if (swipeSpeedY <= 1100.0) {
      powerRatio = 0.88 + ((swipeSpeedY - 350.0) / 750.0) * 0.20;
    } else {
      powerRatio = 1.08 + ((swipeSpeedY - 1100.0) / 800.0) * 0.17;
    }
    powerRatio = powerRatio.clamp(0.45, 1.28);

    final launchVel = LaunchSolver.calculateLaunchVelocity(
      powerRatio: powerRatio,
      aimRatio: swipeRatioX,
      from: physics.pos,
    );

    physics.launch(launchVel, backspin: 14.0);
    onLaunched?.call();
  }
}
