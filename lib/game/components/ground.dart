import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;
import 'package:flutter/material.dart';

class Ground extends BodyComponent {
  final Vector2 groundPosition;
  final Vector2 groundSize;

  Ground({
    Vector2? groundPosition,
    Vector2? groundSize,
  })  : groundPosition = groundPosition ?? Vector2(0, 8),
        groundSize = groundSize ?? Vector2(18, 1.2);

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: groundPosition,
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      material: SurfaceMaterial(
        friction: 0.8,
        restitution: 0.75,
      ),
      filter: forge2d.Filter(
        categoryBits: 0x0002, // Floor category
        maskBits: forge2d.Filter.allCategories,
      ),
    );

    body.createShape(
      Polygon.box(groundSize.x / 2, groundSize.y / 2),
      shapeDef,
    );
    return body;
  }

  @override
  void render(Canvas canvas) {
    // Invisible physics collider so procedural court floor shows cleanly
  }
}
