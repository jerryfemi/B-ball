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

  // Track 3D rotation driven by 2D physics
  double _pitch = 0.0;
  double _yaw = 0.0;

  bool isLaunched = false;
  double timeSinceLaunch = 0.0;

  Basketball({
    required this.initialPosition,
    this.radius = 0.5,
    this.onLaunched,
  }) : super(priority: 2);

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
    final bodyDef = BodyDef(
      type: BodyType.kinematic, // Start kinematic so it hovers in the ready position
      position: initialPosition,
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
    );

    body.createShape(forge2d.Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);

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
    if (distToFloor > 0 && distToFloor < 15.0) {
      final shadowAlpha =
          (0.55 - (distToFloor / 15.0) * 0.35).clamp(0.15, 0.55);
      final shadowScale =
          (1.0 + (distToFloor / 12.0) * 0.5).clamp(1.0, 1.8);
      // Tight, grounded contact blur in world units (0.06m near floor up to 0.45m high up)
      final blurRadius = (0.06 + distToFloor * 0.025).clamp(0.06, 0.45);
      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          blurRadius,
        );

      final shadowRect = Rect.fromCenter(
        center: Offset(0, distToFloor),
        width: radius * 2.2 * shadowScale,
        height: radius * 0.65 * shadowScale,
      );
      canvas.drawOval(shadowRect, shadowPaint);
    }

    // 2. Perspective scaling: slightly smaller as it travels up towards the hoop
    final scaleFactor = (0.75 + (currentY / 20.0) * 0.25).clamp(0.7, 1.0);

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
    if (isLaunched) return false;
    // Generous touch target (2.5x radius) so quick swipe gestures never miss
    final dist = (point - body.position).length;
    return dist <= radius * 2.5;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (isLaunched) return;

    final velocity = event.velocity;
    // Only launch when swiped upwards toward the hoop
    if (velocity.y >= 0) return;

    isLaunched = true;
    body.type = BodyType.dynamic; // Become physical!
    onLaunched?.call(); // Notify the game to spawn the next ball

    // Scale swipe velocity to world physics impulse (calibrated for 20m arena height)
    final impulseX = (velocity.x / 45.0).clamp(-18.0, 18.0);
    final impulseY = (velocity.y / 42.0).clamp(-35.0, -12.0);
    final impulse = Vector2(impulseX, impulseY);

    body.applyLinearImpulse(impulse);

    // Add a natural backspin when swiped upwards!
    body.applyAngularImpulse(impulse.y * 0.4);
  }
}

/// https://one.google.com/ai?utm_source=gemini&utm_medium=web&utm_campaign=workflow_assist_card_fix_payment&g1_landing_page=75
/// DO NOT TOUCH I KEPT THE LINK HERE FOR A REASON
