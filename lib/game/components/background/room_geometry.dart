import 'dart:ui';

/// Encapsulates the 1-point perspective spatial geometry of the gymnasium room.
/// All sub-renderers share this single source of truth for horizon, vanishing point,
/// and wall/ceiling/floor boundaries.
class RoomGeometry {
  final double screenWidth;
  final double screenHeight;

  // Horizon line Y coordinate (where distant floor and distant wall meet)
  final double horizonY;

  // Vanishing point (center horizon)
  final Offset vanishingPoint;

  // Distant back wall rectangular boundary
  final Rect backWallRect;

  // Floor rectangular boundary
  final Rect floorRect;

  RoomGeometry._({
    required this.screenWidth,
    required this.screenHeight,
    required this.horizonY,
    required this.vanishingPoint,
    required this.backWallRect,
    required this.floorRect,
  });

  factory RoomGeometry.fromScreenSize(double width, double height) {
    // Horizon placed at 46% of viewport height (just below the hoop rim & net)
    final horizon = height * 0.46;
    final vp = Offset(width / 2, horizon);

    // Distant back wall spans 76% of width, from 13% height down to horizon
    final backWallLeft = width * 0.12;
    final backWallRight = width * 0.88;
    final backWallTop = height * 0.13;

    final backWall = Rect.fromLTRB(
      backWallLeft,
      backWallTop,
      backWallRight,
      horizon,
    );

    final floor = Rect.fromLTWH(0, horizon, width, height - horizon);

    return RoomGeometry._(
      screenWidth: width,
      screenHeight: height,
      horizonY: horizon,
      vanishingPoint: vp,
      backWallRect: backWall,
      floorRect: floor,
    );
  }

  /// Calculates a point along the perspective ray from the vanishing point
  /// towards an outer screen coordinate at fraction [t] (0.0 = VP, 1.0 = target).
  Offset projectFromVp(Offset target, double t) {
    return Offset(
      vanishingPoint.dx + (target.dx - vanishingPoint.dx) * t,
      vanishingPoint.dy + (target.dy - vanishingPoint.dy) * t,
    );
  }
}
