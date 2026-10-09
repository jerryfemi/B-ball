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

    // 1. Fluid Full-Screen Viewport
    final metersToPixels = size.y / worldHeightInMeters;

    final viewfinder = camera.viewfinder as Forge2DViewfinder;
    viewfinder.metersToPixels = metersToPixels;
    viewfinder.zoom = 1.0;
    // Set anchor to topCenter so that x=0 is always the horizontal middle of the screen.
    viewfinder.anchor = Anchor.topCenter;
    viewfinder.position = Vector2.zero();

    // 2. Procedural Arena & Hardwood Court Background
    camera.backdrop.add(GameBackground());

    // 3. Ground physics floor at the bottom of the court
    final floorYInMeters = 19.2;
    world.add(
      Ground(
        groundPosition: Vector2(0, floorYInMeters),
        groundSize: Vector2(
          100.0,
          1.0,
        ), // Arbitrarily wide to cover any screen width
      ),
    );

    // 4. Hoop positioned in world coordinates (25% down, horizontally centered at x=0)
    final hoopCenterInMeters = Vector2(0, 5.0);
    const hoopWidthInMeters = 1.8; // Increased from 1.4 to make hoop bigger

    // 5. 2.5D Layering Pipeline:
    // Priority 1: Backboard, wall mounts, rear rim half, and rear net mesh
    world.add(
      BackboardVisual(
        position: hoopCenterInMeters,
        hoopWidth: hoopWidthInMeters,
      ),
    );

    // Physics colliders (circles for rims, deflector plate, score sensor)
    world.add(
      HoopPhysics(
        hoopCenterInMeters: hoopCenterInMeters,
        hoopWidthInMeters: hoopWidthInMeters,
      ),
    );

    // Priority 2: Basketball (passes over backboard, behind front rim)
    _spawnReadyBall();

    // Priority 3: Front rim half and front net cords
    world.add(
      FrontRimVisual(
        position: hoopCenterInMeters,
        hoopWidth: hoopWidthInMeters,
      ),
    );
  }

  void _spawnReadyBall({bool animate = false}) {
    final ball = Basketball(
      // Rest directly on the hardwood court floor (floor 19.2m - radius 0.78m = 18.42m)
      initialPosition: Vector2(0, 18.42),
      radius: 0.78,
      animateEntrance: animate,
      onLaunched: () {
        // Wait 800ms for launched ball to clear the key before feeding next ball
        Future.delayed(const Duration(milliseconds: 800), () {
          if (isLoaded) {
            _spawnReadyBall(animate: true);
          }
        });
      },
    );
    world.add(ball);
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
