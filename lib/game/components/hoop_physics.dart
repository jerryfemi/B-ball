import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:forge2d/forge2d.dart' as forge2d;

/// Static physics colliders for the basketball hoop:
/// - Circular left/right rim pivots for realistic ball rattling and rim roll.
/// - Backboard deflector plate.
/// - Invisible scoring sensor between the rim edges.
class HoopPhysics extends BodyComponent {
  final Vector2 hoopCenterInMeters;
  final double hoopWidthInMeters;

  HoopPhysics({
    required this.hoopCenterInMeters,
    this.hoopWidthInMeters = 1.8,
  });

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: hoopCenterInMeters,
    );

    final body = world.createBody(bodyDef);

    // Rim material: high restitution for authentic bounce and rattle
    final rimMaterial = SurfaceMaterial(friction: 0.25, restitution: 0.85);
    final hoopFilter = forge2d.Filter(
      categoryBits: 0x0004, // Hoop category
      maskBits: forge2d.Filter.allCategories,
    );

    // 1. Left Rim Circle Collider
    final leftRim = forge2d.Circle(
      radius: 0.05,
      center: Vector2(-hoopWidthInMeters / 2, 0),
    );
    body.createShape(
      leftRim,
      ShapeDef(material: rimMaterial, filter: hoopFilter),
    );

    // 2. Right Rim Circle Collider
    final rightRim = forge2d.Circle(
      radius: 0.05,
      center: Vector2(hoopWidthInMeters / 2, 0),
    );
    body.createShape(
      rightRim,
      ShapeDef(material: rimMaterial, filter: hoopFilter),
    );

    // 3. Score Detection Sensor (placed inside the rim opening)
    final scoreSensor = Polygon([
      Vector2(-hoopWidthInMeters / 2 + 0.1, 0.05),
      Vector2(hoopWidthInMeters / 2 - 0.1, 0.05),
      Vector2(hoopWidthInMeters / 2 - 0.1, 0.15),
      Vector2(-hoopWidthInMeters / 2 + 0.1, 0.15),
    ]);
    body.createShape(
      scoreSensor,
      ShapeDef(
        isSensor: true,
        enableSensorEvents: true,
        userData: 'hoop_score_sensor',
        filter: hoopFilter,
      ),
    );

    return body;
  }
}
