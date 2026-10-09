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

  double targetFloorY = 19.2;
  int _bounceCount = 0;

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
  }) : super(priority: 5) {
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
      // Garbage collection: keep made/missed balls lingering on court for 6 seconds
      if (timeSinceLaunch > 6.0) {
        removeFromParent();
        return;
      }

      // 1. Dynamic 3D Depth Layering:
      // While ascending (Vy < 0) or above the rim: renders IN FRONT of the front rim (priority 5).
      // Only when dipping into the rim cylinder: priority 2 (front rim renders in front of ball).
      _updateRenderPriority();

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

      // 2. 2.5D Court Floor Collision & Natural Bouncing
      if (body.position.y >= targetFloorY) {
        body.setTransform(
          Vector2(body.position.x, targetFloorY),
          const forge2d.Rot.identity(),
        );

        if (body.linearVelocity.y.abs() > 1.2) {
          _bounceCount++;
          // Rebound upward with authentic hardwood floor restitution
          body.linearVelocity = Vector2(
            body.linearVelocity.x * 0.82,
            -body.linearVelocity.y.abs() * 0.62,
          );
          body.angularVelocity *= 0.75;
          // Slight forward progression on each bounce
          if (targetFloorY < 17.5 && _bounceCount < 4) {
            targetFloorY += 0.40;
          }
        } else {
          // Settled peacefully to rest on the hardwood court floor
          body.linearVelocity = Vector2(
            body.linearVelocity.x * 0.85,
            0.0,
          );
          if (body.linearVelocity.x.abs() < 0.1) {
            body.linearVelocity = Vector2.zero();
            body.angularVelocity = 0.0;
          }
        }
      }

      // Realistic 3D spin tumbling driven by physical velocity
      _pitch -= body.linearVelocity.y * dt * 0.12;
      _yaw -= body.linearVelocity.x * dt * 0.15;
      _pitch -= body.angularVelocity * dt * 0.45;
    }
  }

  void _updateRenderPriority() {
    // While ascending (Vy < 0) or above the rim (Y < 4.9m):
    // The ball is in front of the entire hoop apparatus (in foreground)
    if (body.linearVelocity.y < 0 || body.position.y < 4.9) {
      priority = 5;
    } else if (body.position.x.abs() <= 0.95 &&
        body.position.y >= 4.9 &&
        body.position.y <= 6.8) {
      // Dipping through the rim opening and net cylinder:
      // Front rim (priority 3) wraps in front of the ball, backboard (priority 1) is behind it
      priority = 2;
    } else {
      // Cleared the net or fallen outside the rim: renders in front of the court
      priority = 5;
    }
  }

  @override
  void render(Canvas canvas) {
    // Opacity fade out over the last 3 seconds of the 6 second lifetime (solid for 3s, fade for 3s)
    final double opacity = timeSinceLaunch > 3.0 
        ? (1.0 - (timeSinceLaunch - 3.0) / 3.0).clamp(0.0, 1.0) 
        : 1.0;

    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );

    final currentY = body.position.y;

    // 1. Dynamic Hardwood Floor Drop Shadow
    // Shadow is calculated relative to the ball's natural landing court depth
    final currentFloorY = isLaunched ? targetFloorY : 19.2;
    final distToFloor = currentFloorY - currentY;
    final heightAboveFloor = distToFloor - radius;

    // Drop shadow shows when the ball is within 3.5m of its landing court floor
    if (heightAboveFloor >= -0.2 && heightAboveFloor < 3.5) {
      final shadowFade =
          (1.0 - (heightAboveFloor.clamp(0.0, 3.5) / 3.5)).clamp(0.0, 1.0);
      final shadowAlpha = (0.55 * shadowFade).clamp(0.0, 0.55);
      final shadowScale =
          (1.0 + (heightAboveFloor.clamp(0.0, 3.5) / 3.5) * 0.4)
              .clamp(1.0, 1.4);
      final blurRadius =
          (0.06 + heightAboveFloor.clamp(0.0, 3.5) * 0.08).clamp(0.06, 0.30);

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
    canvas.restore(); // Restore the saveLayer for opacity
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
          (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!)
              .clamp(40, 500) / 1000.0;
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
    final swipeSpeedY = finalVy.abs().clamp(200.0, 3000.0);
    // Lateral swipe ratio (aim angle)
    final swipeRatioX = (finalVx / finalVy.abs()).clamp(-0.8, 0.8);

    // Launch velocity calibration for 20m arena with g = 30 m/s²:
    // Minimum flick (-27.0 m/s) -> short shot that peaks below the rim (airball)
    // Medium flick (-32.0 m/s) -> perfect arc that peaks at Y ~ 1.8m and dips cleanly into hoop
    // Firm flick (-42.0 m/s) -> high rainbow arc
    final powerFactor = ((swipeSpeedY - 150.0) / 1500.0).clamp(0.0, 1.0);
    _launchPower = powerFactor;
    final targetVy = ui.lerpDouble(-28.0, -42.0, powerFactor)!;

    // 2.5D Court Landing Floor based on shot power:
    // Firm shot to the hoop: lands under the basket in the red key (Y ~ 13.4m)
    // Short shot / airball: lands near the free-throw circle (Y ~ 14.8m to 16.5m)
    // Weak swipe in foreground: lands near the feeder (Y ~ 17.5m to 18.2m)
    targetFloorY = ui.lerpDouble(18.2, 13.4, powerFactor)!;
    _bounceCount = 0;

    // Lateral velocity based on flick angle:
    // Over the ~1.5s flight time to the rim, swipeRatioX directly steers the shot
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
