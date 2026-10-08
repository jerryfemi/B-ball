import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'components/background.dart';
import 'components/backboard_visual.dart';
import 'components/front_rim_visual.dart';
import 'components/hoop_physics.dart';
import 'components/ball.dart';
import 'components/ground.dart';

class BasketballGame extends Forge2DGame {
  BasketballGame() : super(gravity: Vector2(0, 30.0));

  static const double worldHeightInMeters = 20.0;

  @override
  Color backgroundColor() => const Color(0xFF090D16);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Fluid Full-Screen Viewport (No black letterbox bars!)
    // Camera defaults to full screen view.
    final metersToPixels = size.y / worldHeightInMeters;

    final viewfinder = camera.viewfinder as Forge2DViewfinder;
    viewfinder.metersToPixels = metersToPixels;
    viewfinder.zoom = 1.0;
    viewfinder.anchor = Anchor.topLeft;
    viewfinder.position = Vector2.zero();

    // 2. Procedural Arena & Hardwood Court Background
    camera.backdrop.add(GameBackground());

    // World dimensions in physics meters
    final worldWidthInMeters = size.x / metersToPixels;

    // 3. Ground physics floor at the bottom of the court
    final floorYInMeters = 19.2;
    world.add(Ground(
      groundPosition: Vector2(worldWidthInMeters / 2, floorYInMeters),
      groundSize: Vector2(worldWidthInMeters * 2, 1.0),
    ));

    // 4. Hoop positioned in world coordinates (25% down, horizontally centered)
    final hoopCenterInMeters = Vector2(worldWidthInMeters / 2, 5.0);
    const hoopWidthInMeters = 1.4;

    // 5. 2.5D Layering Pipeline:
    // Priority 1: Backboard, pole, rear rim half, and rear net mesh
    world.add(BackboardVisual(
      position: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    ));

    // Physics colliders (circles for rims, deflector plate, score sensor)
    world.add(HoopPhysics(
      hoopCenterInMeters: hoopCenterInMeters,
      hoopWidthInMeters: hoopWidthInMeters,
    ));

    // Priority 2: Basketball (passes over backboard, behind front rim)
    world.add(Basketball(
      initialPosition: Vector2(worldWidthInMeters / 2, floorYInMeters - 2.5),
      radius: 0.5,
    ));

    // Priority 3: Front rim half and front net cords
    world.add(FrontRimVisual(
      position: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    ));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final viewfinder = camera.viewfinder as Forge2DViewfinder;
      viewfinder.metersToPixels = size.y / worldHeightInMeters;
    }
  }
}
