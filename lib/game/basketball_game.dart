import 'dart:math' as math;
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

  double _lastSpawnX = 0.0;
  final math.Random _rng = math.Random();

  double _pickNextSpawnX() {
    // Diverse shooting positions along the bottom baseline (in Forge2D meters)
    const candidates = [-1.4, -0.7, 0.0, 0.7, 1.4];
    final options =
        candidates.where((x) => (x - _lastSpawnX).abs() >= 0.5).toList();
    final chosen = options[_rng.nextInt(options.length)];
    _lastSpawnX = chosen;
    return chosen;
  }

  void _spawnReadyBall({bool animate = false}) {
    final spawnX = animate ? _pickNextSpawnX() : 0.0;
    final ball = Basketball(
      // Rest directly on the hardwood court floor at the chosen baseline spot
      initialPosition: Vector2(spawnX, 18.62),
      radius: 0.58,
      animateEntrance: animate,
      onLaunched: () {
        // Snappy feed of next ball: 250ms delay
        Future.delayed(const Duration(milliseconds: 250), () {
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
