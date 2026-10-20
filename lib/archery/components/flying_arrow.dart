import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../camera/archery_camera.dart';
import '../physics/arrow_physics.dart';
import 'arrow_renderer.dart';

/// Renders the flying arrow in 3D perspective using the shared ArrowRenderer3D (Build Plan v2 §1.3).
class FlyingArrow {
  final ArcheryCamera camera;
  final ArrowPhysics3D physics;

  FlyingArrow({required this.camera, required this.physics});

  void resetTrail() {}

  void render(Canvas canvas) {
    if (!physics.inFlight) return;

    final double speed = physics.vel.length;
    if (speed < 0.1) return;

    final double invSpeed = 1.0 / speed;
    final double forwardX = physics.vel.x * invSpeed;
    final double forwardY = physics.vel.y * invSpeed;
    final double forwardZ = physics.vel.z * invSpeed;

    // Visual arrow spin: 3 full rotations per second in flight
    final double roll = 2.0 * math.pi * 3.0 * physics.timeSinceRelease;

    // Archer's paradox wobble applies slight lateral offset to nock
    final double wobbleOffset = math.sin(physics.wobbleYaw) * 0.008;

    ArrowRenderer3D.render(
      canvas: canvas,
      camera: camera,
      tipX: physics.pos.x,
      tipY: physics.pos.y,
      tipZ: physics.pos.z,
      forwardX: forwardX,
      forwardY: forwardY,
      forwardZ: forwardZ,
      roll: roll,
      quiverOffsetX: wobbleOffset,
      drawEntryHole: false,
    );
  }
}
