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

  // Track 3D rotation driven by 2D physics (initialized with organic resting tilt)
  double _pitch = 0.36; // tilted forward toward camera
  double _yaw = -0.42; // tilted sideways

  bool isLaunched = false;
  double timeSinceLaunch = 0.0;

  final bool animateEntrance;
  bool isEntering = false;
  double enterProgress = 0.0;

  late final forge2d.Shape _shape;
  Vector2? _dragStartPos;
  Vector2? _lastDragPos;
  int? _dragStartTimeMs;

  Basketball({
    required this.initialPosition,
    this.radius = 0.78,
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
      type: BodyType.kinematic, // Start kinematic so it hovers in the ready position
      position: Vector2(initialPosition.x, startY),
      linearDamping: 0.1,
      angularDamping: 0.2, // Adds some natural spin friction
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: 1.0,
      material: SurfaceMaterial(
        friction: 0.8, // More friction for better rolling/spinning
        restitution: 0.82, // Extra bouncy
      ),
      filter: forge2d.Filter(
        categoryBits: 2,
        maskBits: isLaunched ? forge2d.Filter.allCategories : 0,
      ),
    );

    _shape = body.createShape(forge2d.Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth Feeder Entrance: glide up from below into the ready position
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
    }

    if (isLaunched) {
      timeSinceLaunch += dt;
      // Garbage collection: remove balls 4 seconds after they are shot
      if (timeSinceLaunch > 4.0) {
        removeFromParent();
        return;
      }
    }

    // Fake 3D rotation based on actual 2D velocity and angular velocity!
    // If it moves up/down (Y velocity), it spins around X axis (pitch)
    _pitch -= body.linearVelocity.y * dt * 0.15;

    // If it moves left/right (X velocity), it spins around Y axis (yaw)
    _yaw -= body.linearVelocity.x * dt * 0.15;

    // We also factor in the Forge2D physical angular velocity for perfect synchronization when bouncing
    _pitch -= body.angularVelocity * dt * 0.5;
  }

  @override
  void render(Canvas canvas) {
    final currentY = body.position.y;

    // 1. Dynamic Floor Drop Shadow (Spatial Height Perception)
    const floorY = 19.2;
    final distToFloor = floorY - currentY;
    final heightAboveFloor = distToFloor - radius;

    // Only render floor shadow when the ball is within 3.5m of the ground
    if (heightAboveFloor >= -0.1 && heightAboveFloor < 3.5) {
      final shadowFade =
          (1.0 - (heightAboveFloor.clamp(0.0, 3.5) / 3.5)).clamp(0.0, 1.0);
      final shadowAlpha = (0.55 * shadowFade).clamp(0.0, 0.55);
      final shadowScale =
          (1.0 + (heightAboveFloor.clamp(0.0, 3.5) / 3.5) * 0.5).clamp(1.0, 1.5);
      final blurRadius =
          (0.06 + heightAboveFloor.clamp(0.0, 3.5) * 0.08).clamp(0.06, 0.35);

      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

      canvas.save();
      // Counter-rotate by physical body roll so the shadow stays strictly flat on the horizontal floor
      canvas.rotate(-body.angle);

      final shadowRect = Rect.fromCenter(
        center: Offset(0, distToFloor.clamp(radius, 25.0)),
        width: radius * 2.2 * shadowScale,
        height: radius * 0.50 * shadowScale,
      );
      canvas.drawOval(shadowRect, shadowPaint);
      canvas.restore();
    }

    // 2. Perspective scaling: scales down to ~0.73x as it rises up to the hoop (1.8m rim)
    final scaleFactor = (0.65 + (currentY / 20.0) * 0.35).clamp(0.65, 1.0);

    canvas.save();
    canvas.scale(scaleFactor);

    if (_program != null) {
      final shader = _program!.fragmentShader();

      // Read exact screen pixels and scale from Flutter's Canvas transform matrix
      final transform = canvas.getTransform();
      final logicalCenterX = transform[12];
      final logicalCenterY = transform[13];
      // Rotation-invariant scale: sqrt(m00^2 + m10^2)
      final logicalScale =
          math.sqrt(transform[0] * transform[0] + transform[1] * transform[1]);

      // Query hardware device pixel ratio (DPR) to bridge logical canvas to WebGL FlutterFragCoord
      final dpr =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

      final physicalCenterX = logicalCenterX * dpr;
      final physicalCenterY = logicalCenterY * dpr;
      final physicalRadius = radius * logicalScale * dpr;

      // Pass Uniforms in exact physical screen space
      shader.setFloat(0, physicalCenterX); // u_center.x
      shader.setFloat(1, physicalCenterY); // u_center.y
      shader.setFloat(2, physicalRadius); // u_radius
      shader.setFloat(3, _yaw); // u_rotation.x
      shader.setFloat(4, _pitch); // u_rotation.y
      shader.setFloat(5, radius); // u_local_radius

      final paint = Paint()..shader = shader;
      // Draw a rect covering the ball bounds with padding for anti-aliasing
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.2,
        height: radius * 2.2,
      );
      canvas.drawRect(rect, paint);
    } else {
      // Fallback rendering while shader compiles/loads
      final paint = Paint()..color = const Color(0xFFFF6F00);
      canvas.drawCircle(Offset.zero, radius, paint);
    }

    canvas.restore();
  }

  @override
  bool containsPoint(Vector2 point) {
    if (isLaunched || isEntering) return false;
    // Generous touch target (2.5x radius) so quick swipe gestures never miss
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

    // Displacement-based gesture fallback: captures full upward flick even if mouse release lagged
    if (_dragStartPos != null &&
        _lastDragPos != null &&
        _dragStartTimeMs != null) {
      delta = _lastDragPos! - _dragStartPos!;
      final dtMs =
          (DateTime.now().millisecondsSinceEpoch - _dragStartTimeMs!)
              .clamp(40, 600);
      final dispVy = delta.y / (dtMs / 1000.0);
      final dispVx = delta.x / (dtMs / 1000.0);

      // If displacement shows a decisive upward flick, take the stronger velocity
      if (dispVy < vy) {
        vy = dispVy;
        vx = dispVx;
      }
    }

    // Only launch when swiped upwards toward the hoop (via speed or displacement)
    final isUpward = vy <= -40.0 || (delta != null && delta.y <= -25.0);
    if (!isUpward) return;

    isLaunched = true;
    body.type = BodyType.dynamic; // Become physical!
    // Enable full collision response across all physical objects once in flight
    _shape.filter = forge2d.Filter(
      categoryBits: 1,
      maskBits: forge2d.Filter.allCategories,
    );
    onLaunched?.call(); // Notify the game to spawn the next ball after delay

    // Scale swipe velocity to world physical velocity calibrated for the 20m arena
    // vy is negative (upward) in screen pixels/sec
    final targetVx = (vx / 65.0).clamp(-12.0, 12.0);
    // Base launch velocity of -24.0 m/s + scaled swipe energy, clamped between -37.0 m/s (high arc/board) and -25.5 m/s (floater/rim)
    final targetVy = (-24.0 + (vy / 75.0)).clamp(-37.0, -25.5);

    body.linearVelocity = Vector2(targetVx, targetVy);

    // Natural backspin proportional to upward launch speed
    body.angularVelocity = targetVy * 0.22;
  }
}

/// https://one.google.com/ai?utm_source=gemini&utm_medium=web&utm_campaign=workflow_assist_card_fix_payment&g1_landing_page=75
/// DO NOT TOUCH I KEPT THE LINK HERE FOR A REASON
