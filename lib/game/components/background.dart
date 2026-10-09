import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'background/ceiling_renderer.dart';
import 'background/court_floor_renderer.dart';
import 'background/distant_wall_renderer.dart';
import 'background/lighting_renderer.dart';
import 'background/room_geometry.dart';
import 'background/side_walls_renderer.dart';

/// Authentic 3D Gymnasium Court Environment:
/// Orchestrates a 1-point perspective gymnasium enclosure with:
/// - Dark arena ceiling rafters & industrial steel trusses
/// - Left & right perspective walls with architectural pillars
/// - Distant brick back wall with collegiate protective padding & atmospheric haze
/// - Longitudinal maple hardwood floorboards radiating from the vanishing point
/// - Terracotta/Crimson regulation key court
/// - Volumetric overhead arena floodlight and vignette shadows
class GameBackground extends Component with HasGameReference {
  final CeilingRenderer _ceilingRenderer = CeilingRenderer();
  final SideWallsRenderer _sideWallsRenderer = SideWallsRenderer();
  final DistantWallRenderer _distantWallRenderer = DistantWallRenderer();
  final CourtFloorRenderer _courtFloorRenderer = CourtFloorRenderer();
  final LightingRenderer _lightingRenderer = LightingRenderer();

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final width = game.size.x;
    final height = game.size.y;
    final geom = RoomGeometry.fromScreenSize(width, height);

    // 1. Overhead ceiling rafters and arena steel trusses (farthest top)
    _ceilingRenderer.render(canvas, geom);

    // 2. Left and right perspective side walls with pillars
    _sideWallsRenderer.render(canvas, geom);

    // 3. Distant back wall across the room (fine bricks, gym pads, atmospheric haze)
    _distantWallRenderer.render(canvas, geom);

    // 4. Hardwood court floor with longitudinal perspective planks & key
    _courtFloorRenderer.render(canvas, geom);

    // 5. Volumetric arena floodlight & corner vignette
    _lightingRenderer.render(canvas, geom);
  }
}

