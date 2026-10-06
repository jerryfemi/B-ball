import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'components/ball.dart';
import 'components/ground.dart';

class BasketballGame extends Forge2DGame {
  BasketballGame() : super(gravity: Vector2(0, 18.0));

  @override
  Color backgroundColor() => const Color(0xFF161622);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Center camera on the middle of the screen
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = 22.0;

    // Floor (clearly visible in bottom half of screen)
    world.add(Ground(
      groundPosition: Vector2(0, 8),
      groundSize: Vector2(18, 1.2),
    ));

    // Left Wall
    world.add(Ground(
      groundPosition: Vector2(-8.5, 0),
      groundSize: Vector2(1, 17),
    ));

    // Right Wall
    world.add(Ground(
      groundPosition: Vector2(8.5, 0),
      groundSize: Vector2(1, 17),
    ));

    // Spawn ball in center-top to drop and bounce repeatedly
    world.add(Basketball(initialPosition: Vector2(0, -5)));
  }
}
