import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

class Basketball extends BodyComponent {
  final Vector2 initialPosition;
  final double radius;

  Basketball({
    required this.initialPosition,
    this.radius = 0.8,
  });

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
      linearDamping: 0.1,
      angularDamping: 0.2,
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      material: SurfaceMaterial(
        friction: 0.2,
        restitution: 0.82, // Extra bouncy
      ),
    );

    body.createShape(Circle(radius: radius), shapeDef);
    return body;
  }

  @override
  void render(Canvas canvas) {
    // Custom rendered basketball with seams
    final paint = Paint()..color = const Color(0xFFFF6F00);
    final borderPaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.drawCircle(Offset.zero, radius, borderPaint);
    // Draw ball seams
    canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), borderPaint);
    canvas.drawLine(Offset(0, -radius), Offset(0, radius), borderPaint);
  }
}
