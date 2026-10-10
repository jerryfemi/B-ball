import 'dart:ui';

import '../../physics/perspective_camera.dart';

/// Encapsulates the 1-point perspective spatial geometry of the gymnasium room.
/// All sub-renderers share this single source of truth for horizon, vanishing point,
/// 3D camera projection, and wall/ceiling/floor boundaries.
class RoomGeometry {
  final double screenWidth;
  final double screenHeight;
  final PerspectiveCamera3D camera;

  // Gym 3D boundary constants in meters
  static const double wallZ = 5.25;
  static const double ceilingHeight = 6.5;

  // Horizon line Y coordinate (camera eye level)
  final double horizonY;

  // Vanishing point (center horizon)
  final Offset vanishingPoint;

  // Y coordinate where distant back wall meets the hardwood court floor at depth wallZ
  final double wallBaseY;

  // Distant back wall rectangular boundary
  final Rect backWallRect;

  // Hardwood floor rectangular boundary
  final Rect floorRect;

  RoomGeometry._({
    required this.screenWidth,
    required this.screenHeight,
    required this.camera,
    required this.horizonY,
    required this.vanishingPoint,
    required this.wallBaseY,
    required this.backWallRect,
    required this.floorRect,
  });

  factory RoomGeometry.fromScreenSize(double width, double height) {
    final camera = PerspectiveCamera3D.standard(width, height);
    final horizonY = camera.horizonScreenY;
    final vanishingPoint = Offset(width / 2.0, horizonY);

    // Baseline where wall meets the court floor at depth wallZ (y = 0.0)
    final wallBaseY = camera.projectCoords(0.0, 0.0, wallZ).dy;

    // Distant back wall spans across width, from top down to court baseline
    final backWall = Rect.fromLTRB(0.0, 0.0, width, wallBaseY);

    // Court floor spans from baseline down to bottom of screen
    final floor = Rect.fromLTWH(0.0, wallBaseY, width, height - wallBaseY);

    return RoomGeometry._(
      screenWidth: width,
      screenHeight: height,
      camera: camera,
      horizonY: horizonY,
      vanishingPoint: vanishingPoint,
      wallBaseY: wallBaseY,
      backWallRect: backWall,
      floorRect: floor,
    );
  }

  /// Projects a 3D court floor coordinate (y = 0.0) to 2D screen pixels.
  Offset projectFloor(double x, double z) => camera.projectCoords(x, 0.0, z);

  /// Projects an arbitrary 3D coordinate (x, y, z) in meters to 2D screen pixels.
  Offset project(double x, double y, double z) => camera.projectCoords(x, y, z);

  /// Calculates a point along the perspective ray from the vanishing point
  /// towards an outer screen coordinate at fraction [t] (0.0 = VP, 1.0 = target).
  Offset projectFromVp(Offset target, double t) {
    return Offset(
      vanishingPoint.dx + (target.dx - vanishingPoint.dx) * t,
      vanishingPoint.dy + (target.dy - vanishingPoint.dy) * t,
    );
  }
}
