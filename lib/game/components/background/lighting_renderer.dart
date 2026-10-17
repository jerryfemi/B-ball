import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'room_geometry.dart';

/// Baked arena lighting (drawn once into the background texture, so it costs
/// nothing per frame):
///  • a night-gym dimming of the brick, with warm light washes scalloping
///    down the wall from a row of overhead fixtures
///  • warm light pools on the hardwood: a bright one under the hoop that
///    pulls the eye to the basket, fainter ones off to the sides
///  • the existing floodlight focus and corner vignette
///
/// Light comes from above and slightly front-left, matching the ball
/// shader's key light (-0.25, 0.92, 0.65), so the ball sits in the scene.
class LightingRenderer {
  /// Spacing between overhead fixtures along the back wall (meters).
  static const double _fixtureSpacing = 2.3;

  void render(Canvas canvas, RoomGeometry geom) {
    _renderWallWashes(canvas, geom);
    _renderFloorPools(canvas, geom);
    _renderFloodlightAndVignette(canvas, geom);
  }

  void _renderWallWashes(Canvas canvas, RoomGeometry geom) {
    final wall = geom.backWallRect;
    if (wall.height <= 0) return;
    final cam = geom.camera;
    final pxPerMeterAtWall =
        cam.pixelsPerMeter * cam.scaleAtDepth(RoomGeometry.wallZ);

    canvas.save();
    canvas.clipRect(wall);

    // 1. Dim the brick a touch, deepest at the top: the lights, not the
    //    wall, should be what reads as bright.
    canvas.drawRect(
      wall,
      Paint()
        ..shader = ui.Gradient.linear(
          wall.topCenter,
          wall.bottomCenter,
          const [Color(0x55000000), Color(0x1E000000), Color(0x0A000000)],
          const [0.0, 0.6, 1.0],
        ),
    );

    // 2. Scalloped washes: a tall ellipse of light per fixture, centered just
    //    above the visible wall so only its lower lobe shows on the brick.
    //    Screen blending brightens the brick without bleaching its texture.
    final washPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x8CFFD8A8), Color(0x44FFC48A), Color(0x00FFB070)],
        const [0.0, 0.5, 1.0],
      );
    final rx = 0.95 * pxPerMeterAtWall;
    final ry = wall.height * 0.95;
    final top = wall.top - ry * 0.12;
    for (int k = -5; k <= 4; k++) {
      final x = (k + 0.5) * _fixtureSpacing;
      final sx = geom.project(x, 0.0, RoomGeometry.wallZ).dx;
      if (sx < wall.left - rx || sx > wall.right + rx) continue;
      canvas.save();
      canvas.translate(sx, top);
      canvas.scale(rx, ry);
      canvas.drawCircle(Offset.zero, 1.0, washPaint);
      canvas.restore();
    }

    canvas.restore();
  }

  void _renderFloorPools(Canvas canvas, RoomGeometry geom) {
    final floor = geom.floorRect;
    if (floor.height <= 0) return;
    canvas.save();
    canvas.clipRect(floor);

    // Main pool under the hoop, slightly left of center (key-light side).
    _floorPool(canvas, geom, x: -0.25, zNear: 1.4, zFar: 5.25, halfWidth: 3.4,
        colors: const [Color(0x52FFE6BE), Color(0x24FFD49C), Color(0x00FFC88A)]);
    // Fainter pools under the side fixtures.
    for (final side in const [-1.0, 1.0]) {
      _floorPool(canvas, geom, x: side * 4.6, zNear: 0.6, zFar: 4.2,
          halfWidth: 2.2,
          colors: const [
            Color(0x26FFE2B8),
            Color(0x10FFD49C),
            Color(0x00FFC88A),
          ]);
    }

    canvas.restore();
  }

  /// An elliptical light pool lying on the floor between depths [zNear] and
  /// [zFar], [halfWidth] meters wide, perspective-correct in screen space.
  void _floorPool(
    Canvas canvas,
    RoomGeometry geom, {
    required double x,
    required double zNear,
    required double zFar,
    required double halfWidth,
    required List<Color> colors,
  }) {
    final near = geom.projectFloor(x, zNear);
    final far = geom.projectFloor(x, zFar);
    final midZ = (zNear + zFar) / 2.0;
    final center = Offset(
      geom.projectFloor(x, midZ).dx,
      (near.dy + far.dy) / 2.0,
    );
    final ry = (near.dy - far.dy).abs() / 2.0;
    final rx = halfWidth *
        geom.camera.pixelsPerMeter *
        geom.camera.scaleAtDepth(midZ);
    if (rx <= 0 || ry <= 0) return;
    final paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        colors,
        const [0.0, 0.5, 1.0],
      );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(rx, ry);
    canvas.drawCircle(Offset.zero, 1.0, paint);
    canvas.restore();
  }

  void _renderFloodlightAndVignette(Canvas canvas, RoomGeometry geom) {
    final width = geom.screenWidth;
    final height = geom.screenHeight;
    final fullRect = Rect.fromLTWH(0, 0, width, height);

    // 1. Soft Overhead Floodlight centered at the hoop (X=center, Y=25% height)
    final spotlightCenter = Offset(width / 2.0, height * 0.25);
    final spotlightRadius = height * 0.80;

    final spotlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (spotlightCenter.dx / width) * 2 - 1,
          (spotlightCenter.dy / height) * 2 - 1,
        ),
        radius: spotlightRadius / width,
        colors: const [
          Color(0x00000000), // Pure crisp clarity on hoop & key
          Color(0x08000000), // Soft ambient drop
          Color(0x22000000), // Medium vignette
          Color(0x48000000), // Arena shadow in extreme corners
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, spotlightPaint);

    // 2. Corner Vignette Gradient
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const [
          Colors.transparent,
          Color(0x15000000),
          Color(0x35000000),
        ],
        stops: const [0.70, 0.88, 1.0],
      ).createShader(fullRect);

    canvas.drawRect(fullRect, vignettePaint);
  }
}
