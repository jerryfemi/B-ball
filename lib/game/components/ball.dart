import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class Basketball extends BodyComponent with DragCallbacks {
  final Vector2 initialPosition;
  final double radius;
  final VoidCallback? onLaunched;

  ui.FragmentProgram? _program;

  // 3D rotation driven by physical spin (initialized with natural resting tilt)
  double _pitch = 0.36; // tilted forward toward camera
  double _yaw = -0.42; // tilted sideways

  bool isLaunched = false;
  double timeSinceLaunch = 0.0;
  bool _hasActivatedRimCollision = false;
  bool _hasBankedBackboard = false;
  double _launchPower = 0.0;

  final bool animateEntrance;
  bool isEntering = false;
  double enterProgress = 0.0;

  late final forge2d.Shape _shape;
  Vector2? _dragStartPos;
  Vector2? _lastDragPos;
  int? _dragStartTimeMs;

  Basketball({
    required this.initialPosition,
    this.radius = 0.58,
    this.onLaunched,
    this.animateEntrance = false,
  }) : super(priority: 2) {
    if (animateEntrance) {
      isEntering = true;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/basketball.frag');
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  @override
  Body createBody() {
    final startY =
        animateEntrance ? initialPosition.y + 2.5 : initialPosition.y;

    final bodyDef = BodyDef(
      type: BodyType.kinematic,
      position: Vector2(initialPosition.x, startY),
      linearDamping: 0.05,
      angularDamping: 0.15,
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(
        friction: 0.8,
        restitution: 0.82,
      ),
      filter: forge2d.Filter(
        categoryBits: 0x0008, // Basketball category
        maskBits: 0, // Unlaunched/entering ball collides with nothing
      ),
    );

    _shape = body.createShape(forge2d.Circle(radius: radius), shapeDef);
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
      final curY =
          ui.lerpDouble(initialPosition.y + 2.5, initialPosition.y, t)!;
      body.setTransform(
        Vector2(initialPosition.x, curY),
        const forge2d.Rot.identity(),
      );
      return;
    }

    if (isLaunched && body.type == BodyType.dynamic) {
      timeSinceLaunch += dt;
      // Garbage collection: remove ball 6.0 seconds after shot
      if (timeSinceLaunch > 6.0) {
        removeFromParent();
        return;
      }

      // DIRECTIONAL PARABOLIC PHASE CHECK:
      // While ascending (Vy < 0): maskBits is 0x0002 (Floor only), bypassing the rim.
      // The moment the ball reaches its apex and starts DIPPING (Vy >= 0), activate full rim collision!
      if (body.linearVelocity.y >= 0 && !_hasActivatedRimCollision) {
        _hasActivatedRimCollision = true;
        _shape.filter = forge2d.Filter(
          categoryBits: 0x0008,
          maskBits:
              forge2d.Filter.allCategories, // Solid collision with hoop pegs and floor!
        );
      }

      // Backboard Glass Bank: descending shot with high power caroms forward/down
      if (body.linearVelocity.y > 0 &&
          !_hasBankedBackboard &&
          _launchPower > 0.60 &&
          body.position.y >= 3.4 &&
          body.position.y <= 4.8 &&
          body.position.x.abs() <= 1.6) {
        _hasBankedBackboard = true;
        body.linearVelocity = Vector2(body.linearVelocity.x * 0.45, 8.5);
      }

      // Cotton Net Swish Damping: gently cushions the plunge and centers the ball
      if (body.position.y >= 5.0 &&
          body.position.y <= 6.2 &&
          body.position.x.abs() < 0.65) {
        body.linearVelocity.x *= 0.92;
        if (body.linearVelocity.y > 6.5) {
          body.linearVelocity.y = 6.5;
        }
      }

      // Realistic 3D spin tumbling driven by physical velocity
      _pitch -= body.linearVelocity.y * dt * 0.12;
      _yaw -= body.linearVelocity.x * dt * 0.15;
      _pitch -= body.angularVelocity * dt * 0.45;
    }
  }

  @override
  void render(Canvas canvas) {
    final currentY = body.position.y;

    // 1. Dynamic Hardwood Floor Drop Shadow
    // Floor is strictly at Y = 19.2m (at the bottom of the court, NEVER on the wall!)
    const floorY = 19.2;
    final distToFloor = floorY - currentY;
    final heightAboveFloor = distToFloor - radius;

    // Drop shadow only shows when the ball is grounded or near the floor (< 3.0m)
    if (heightAboveFloor >= -0.1 && heightAboveFloor < 3.0) {
      final shadowFade =
          (1.0 - (heightAboveFloor.clamp(0.0, 3.0) / 3.0)).clamp(0.0, 1.0);
      final shadowAlpha = (0.55 * shadowFade).clamp(0.0, 0.55);
      final shadowScale =
          (1.0 + (heightAboveFloor.clamp(0.0, 3.0) / 3.0) * 0.4)
              .clamp(1.0, 1.4);
      final blurRadius =
          (0.06 + heightAboveFloor.clamp(0.0, 3.0) * 0.08).clamp(0.06, 0.30);

      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

      canvas.save();
      // Counter-rotate by physical body roll so the shadow stays strictly flat on the horizontal floor
      canvas.rotate(-body.angle);

      final shadowRect = Rect.fromCenter(
        center: Offset(0, distToFloor),
        width: radius * 2.2 * shadowScale,
        height: radius * 0.50 * shadowScale,
      );
      canvas.drawOval(shadowRect, shadowPaint);
      canvas.restore();
    }

    // 2. Natural Perspective Foreshortening:
    // In foreground hands (Y = 18.62m), scales up to 1.35x (visual radius ~0.78m)
    // At the rim (Y = 5.0m), scales to 1.0x (visual radius 0.58m, exact 1:1 match with physical Box2D circle)
    final depthProgress =
        ((18.62 - currentY) / (18.62 - 5.0)).clamp(0.0, 1.0);
    final scaleFactor = ui.lerpDouble(1.35, 1.0, depthProgress)!;

    canvas.save();
    canvas.scale(scaleFactor);

    if (_program != null) {
      final shader = _program!.fragmentShader();

      final transform = canvas.getTransform();
      final logicalCenterX = transform[12];
      final logicalCenterY = transform[13];
      final logicalScale =
          math.sqrt(transform[0] * transform[0] + transform[1] * transform[1]);

      final dpr =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

      final physicalCenterX = logicalCenterX * dpr;
      final physicalCenterY = logicalCenterY * dpr;
      final physicalRadius = radius * logicalScale * dpr;

      shader.setFloat(0, physicalCenterX);
      shader.setFloat(1, physicalCenterY);
      shader.setFloat(2, physicalRadius);
      shader.setFloat(3, _yaw);
      shader.setFloat(4, _pitch);
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

    double vx = event.velocity.x;
    double vy = event.velocity.y;
    Vector2? delta;

    if (_dragStartPos != null &&
        _lastDragPos != null &&
        _dragStartTimeMs != null) {
      delta = _lastDragPos! - _dragStartPos!;
      final dtMs =
          (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!)
              .clamp(40, 600);
      final dispVy = delta.y / (dtMs / 1000.0);
      final dispVx = delta.x / (dtMs / 1000.0);

      if (dispVy < vy) {
        vy = dispVy;
        vx = dispVx;
      }
    }

    // Only launch when swiped upwards toward the hoop
    final isUpward = vy <= -40.0 || (delta != null && delta.y <= -25.0);
    if (!isUpward) return;

    final dtMs = (_dragStartTimeMs != null)
        ? (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!)
            .clamp(40, 500)
        : 150;
    final dtSec = dtMs / 1000.0;
    final dispX = (delta != null) ? delta.x : vx * dtSec;
    final dispY = (delta != null) ? delta.y : vy * dtSec;

    // Upward swipe velocity in pixels/second
    final swipeSpeedY = (dispY.abs() / dtSec).clamp(200.0, 2400.0);
    // Lateral swipe ratio (aim angle)
    final swipeRatioX = (dispX / dispY.abs()).clamp(-0.8, 0.8);

    // Launch velocity calibration for 20m arena with g = 30 m/s²:
    // Minimum flick (-27.0 m/s) -> short shot that peaks below the rim (airball)
    // Medium flick (-31.8 m/s) -> perfect arc that peaks at Y ~ 1.8m and dips cleanly into hoop
    // Firm flick (-35.5 m/s) -> high rainbow arc that banks off the backboard
    final powerFactor = ((swipeSpeedY - 250.0) / 1100.0).clamp(0.0, 1.0);
    _launchPower = powerFactor;
    final targetVy = ui.lerpDouble(-27.5, -35.5, powerFactor)!;

    // Lateral velocity based on flick angle:
    // Over the ~1.5s flight time to the rim, swipeRatioX directly steers the shot
    // A straight flick (swipeRatioX ~ 0) stays centered for a swish.
    // A slight flick (swipeRatioX ~ 0.12) drifts to ~0.8m to hit the rim peg.
    final targetVx = swipeRatioX * 4.6;

    isLaunched = true;
    body.type = BodyType.dynamic;

    // Ascending phase: collides ONLY with floor (0x0002), passes freely in front of the rim
    _shape.filter = forge2d.Filter(
      categoryBits: 0x0008,
      maskBits: 0x0002, // Floor only while rising
    );

    onLaunched?.call();

    body.linearVelocity = Vector2(targetVx, targetVy);
    body.angularVelocity = targetVy * 0.18; // Authentic backspin
  }
}
