import 'package:flame/camera.dart';
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

  @override
  Color backgroundColor() => const Color(0xFF161622);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Lock the logical resolution to a mobile portrait ratio (400x800).
    // This ensures the game scales perfectly on ANY screen size (desktop or mobile).
    camera.viewport = FixedResolutionViewport(resolution: Vector2(400, 800));

    // The camera defaults to top-left (0,0) world coordinates.
    camera.viewfinder.anchor = Anchor.topLeft;
    // Standard 10x zoom: 1 meter = 10 pixels.
    camera.viewfinder.zoom = 10.0;

    // 1. Court background (renders in backdrop behind all World elements)
    camera.backdrop.add(GameBackground());

    // Convert screen dimensions to world meter coordinates
    final screenWidthInMeters = size.x / camera.viewfinder.zoom; // 40.0 meters
    final floorYInMeters = size.y / camera.viewfinder.zoom; // 80.0 meters

    // Physics floor at the base of the viewport
    world.add(Ground(
      groundPosition: Vector2(screenWidthInMeters / 2, floorYInMeters),
      groundSize: Vector2(screenWidthInMeters, 2.0),
    ));

    // Hoop positioning in World coordinates
    final hoopCenterInMeters = Vector2(screenWidthInMeters / 2, 20.0);
    const hoopWidthInMeters = 6.0;

    // 2. 2.5D Layering pipeline:
    // Priority 1: Backboard, pole, rear rim half, and rear net mesh
    world.add(BackboardVisual(
      position: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    ));

    // Physics colliders (circles for rims, backboard deflector, score sensor)
    world.add(HoopPhysics(
      hoopCenterInMeters: hoopCenterInMeters,
      hoopWidthInMeters: hoopWidthInMeters,
    ));

    // Priority 2: Basketball (passes over backboard, under front rim)
    world.add(Basketball(
      initialPosition: Vector2(screenWidthInMeters / 2, floorYInMeters - 10),
      radius: 2.5,
    ));

    // Priority 3: Front rim half (highlighted orange) and front net cords
    world.add(FrontRimVisual(
      position: hoopCenterInMeters,
      hoopWidth: hoopWidthInMeters,
    ));
  }
}
