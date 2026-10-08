import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flame/camera.dart';

import 'components/background.dart';
import 'components/hoop_visual.dart';
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

    // Lock the logical resolution to a mobile portrait ratio (like 400x800).
    // This ensures the game scales perfectly on ANY screen size (desktop or mobile).
    camera.viewport = FixedResolutionViewport(resolution: Vector2(400, 800));

    // The camera defaults to top-left (0,0) world coordinates.
    camera.viewfinder.anchor = Anchor.topLeft;
    // Use a standard 10x zoom. 1 meter = 10 pixels.
    camera.viewfinder.zoom = 10.0;

    // 1. Add Visuals to the Camera Backdrop (rendered in screen pixel coordinates!)
    camera.backdrop.add(GameBackground());

    final hoopSize = Vector2(150, 150);
    final hoopPosition = Vector2(
      size.x / 2 - hoopSize.x / 2, // Center horizontally
      size.y * 0.15, // 15% down from top
    );
    camera.backdrop.add(HoopVisual(
      position: hoopPosition,
      size: hoopSize,
    ));

    // 2. Add Physics Bodies (rendered in meter coordinates)
    
    // Convert screen pixel coordinates to world meter coordinates
    final floorYInMeters = size.y / camera.viewfinder.zoom;
    final screenWidthInMeters = size.x / camera.viewfinder.zoom;
    
    // Add physics floor
    world.add(Ground(
      groundPosition: Vector2(screenWidthInMeters / 2, floorYInMeters),
      groundSize: Vector2(screenWidthInMeters, 2.0),
    ));
    
    // Add physics hoop
    final hoopYInMeters = (size.y * 0.15 + hoopSize.y / 2) / camera.viewfinder.zoom;
    world.add(HoopPhysics(
      hoopCenterInMeters: Vector2(screenWidthInMeters / 2, hoopYInMeters),
      hoopWidthInMeters: (hoopSize.x * 0.4) / camera.viewfinder.zoom,
    ));

    // Spawn ball in center, near the bottom (with a proper radius of 2.5 meters so it takes up 50 pixels)
    world.add(Basketball(
      initialPosition: Vector2(screenWidthInMeters / 2, floorYInMeters - 10),
      radius: 2.5,
    ));
  }
}
