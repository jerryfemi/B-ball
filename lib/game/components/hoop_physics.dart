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
    this.hoopWidthInMeters = 6.0,
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

    // 1. Left Rim Circle Collider (radius 0.22m)
    final leftRim = forge2d.Circle(
      radius: 0.22,
      center: Vector2(-hoopWidthInMeters / 2, 0),
    );
    body.createShape(leftRim, ShapeDef(material: rimMaterial));

    // 2. Right Rim Circle Collider (radius 0.22m)
    final rightRim = forge2d.Circle(
      radius: 0.22,
      center: Vector2(hoopWidthInMeters / 2, 0),
    );
    body.createShape(rightRim, ShapeDef(material: rimMaterial));

    // 3. Backboard Deflector (stops high overshots above the rim)
    final backboardDeflector = Polygon([
      Vector2(-hoopWidthInMeters, -4.5),
      Vector2(hoopWidthInMeters, -4.5),
      Vector2(hoopWidthInMeters, -4.2),
      Vector2(-hoopWidthInMeters, -4.2),
    ]);
    body.createShape(
      backboardDeflector,
      ShapeDef(material: SurfaceMaterial(friction: 0.2, restitution: 0.6)),
    );

    // 4. Score Detection Sensor (placed inside the rim opening)
    final scoreSensor = Polygon([
      Vector2(-hoopWidthInMeters / 2 + 0.4, 0.2),
      Vector2(hoopWidthInMeters / 2 - 0.4, 0.2),
      Vector2(hoopWidthInMeters / 2 - 0.4, 0.6),
      Vector2(-hoopWidthInMeters / 2 + 0.4, 0.6),
    ]);
    body.createShape(
      scoreSensor,
      ShapeDef(
        isSensor: true,
        enableSensorEvents: true,
        userData: 'hoop_score_sensor',
      ),
    );

    return body;
  }
}
