import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class Basketball extends BodyComponent with DragCallbacks {
  final Vector2 initialPosition;
  final double radius;

  ui.FragmentProgram? _program;

  // Track 3D rotation driven by 2D physics
  double _pitch = 0.0;
  double _yaw = 0.0;

  Basketball({
    required this.initialPosition,
    this.radius = 0.5,
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
      type: BodyType.dynamic,
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
      final shadowAlpha = (1.0 - (distToFloor / 15.0)).clamp(0.0, 0.45);
      final shadowScale = (1.0 + (distToFloor / 12.0)).clamp(1.0, 2.0);
      final shadowPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowAlpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          (1.0 + distToFloor * 0.35).clamp(1.0, 5.0),
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

      // Read exact screen pixels and scale directly from Flutter's Canvas transform matrix!
      final transform = canvas.getTransform();
      final screenX = transform[12];
      final screenY = transform[13];
      final pixelScale = transform[0];
      final screenRadius = radius * pixelScale;

      // Pass Uniforms
      shader.setFloat(0, screenX); // u_center.x
      shader.setFloat(1, screenY); // u_center.y
      shader.setFloat(2, screenRadius); // u_radius
      shader.setFloat(3, _yaw); // u_rotation.x
      shader.setFloat(4, _pitch); // u_rotation.y

      final paint = Paint()..shader = shader;
      // Draw a rect covering the ball bounds
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 2,
      );
      canvas.drawRect(rect, paint);
    } else {
      // Fallback rendering
      final paint = Paint()..color = const Color(0xFFFF6F00);
      canvas.drawCircle(Offset.zero, radius, paint);
    }

    canvas.restore();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    final velocity = event.velocity;
    final impulse = velocity / 90.0;

    body.applyLinearImpulse(impulse);

    // Add a natural backspin when swiped upwards!
    if (impulse.y < 0) {
      body.applyAngularImpulse(impulse.y * 0.4);
    }
  }
}

/// https://one.google.com/ai?utm_source=gemini&utm_medium=web&utm_campaign=workflow_assist_card_fix_payment&g1_landing_page=75
/// DO NOT TOUCH I KEPT THE LINK HERE FOR A REASON
