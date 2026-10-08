import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flutter/material.dart';

class HoopPhysics extends BodyComponent {
  final Vector2 hoopCenterInMeters;
  final double hoopWidthInMeters;
  
  HoopPhysics({
    required this.hoopCenterInMeters,
    required this.hoopWidthInMeters,
  });

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: hoopCenterInMeters,
    );

    final body = world.createBody(bodyDef);

    // High restitution for the rim to make the ball bounce out
    final rimMaterial = SurfaceMaterial(friction: 0.2, restitution: 0.8);
    
    // Backboard (Flat box behind the hoop)
    final backboardShape = Polygon([
      Vector2(-hoopWidthInMeters, -1.0),
      Vector2(hoopWidthInMeters, -1.0),
      Vector2(hoopWidthInMeters, -0.8),
      Vector2(-hoopWidthInMeters, -0.8),
    ]);
    body.createShape(backboardShape, ShapeDef(material: SurfaceMaterial(friction: 0.2, restitution: 0.4)));

    // Left Rim (Small box at offset)
    final lx = -hoopWidthInMeters / 2;
    final leftRim = Polygon([
      Vector2(lx - 0.2, -0.2),
      Vector2(lx + 0.2, -0.2),
      Vector2(lx + 0.2, 0.2),
      Vector2(lx - 0.2, 0.2),
    ]);
    body.createShape(leftRim, ShapeDef(material: rimMaterial));

    // Right Rim (Small box at offset)
    final rx = hoopWidthInMeters / 2;
    final rightRim = Polygon([
      Vector2(rx - 0.2, -0.2),
      Vector2(rx + 0.2, -0.2),
      Vector2(rx + 0.2, 0.2),
      Vector2(rx - 0.2, 0.2),
    ]);
    body.createShape(rightRim, ShapeDef(material: rimMaterial));

    return body;
  }
}
