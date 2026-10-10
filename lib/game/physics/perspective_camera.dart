import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

/// 1-Point Perspective Camera that projects 3D world coordinates (in meters)
/// to 2D screen coordinates (in pixels).
///
/// Coordinate Conventions:
/// - X: Horizontal lateral axis (0 = center of court, -X = left, +X = right)
/// - Y: Vertical height axis (0 = hardwood floor, +Y = upwards into the air)
/// - Z: Depth distance axis (0 = player's hands at free throw line, +Z = away from camera towards hoop)
class PerspectiveCamera3D {
  final double screenWidth;
  final double screenHeight;

  // Screen Y coordinate of the horizon line (vanishing point)
  final double horizonScreenY;

  // Camera eye height above the hardwood floor (in meters)
  final double eyeHeightInMeters;

  // Focal distance parameter d (controls field-of-view perspective strength)
  final double focalDistance;

  // Conversion factor from meters to screen pixels at z = 0
  final double pixelsPerMeter;

  PerspectiveCamera3D({
    required this.screenWidth,
    required this.screenHeight,
    required this.horizonScreenY,
    this.eyeHeightInMeters = 2.1,
    this.focalDistance = 5.2,
    required this.pixelsPerMeter,
  });

  /// Conversion factor from 3D meters at Z=0 to Forge2D world meters (constant 6.90).
  static const double forge2dUnitsPerMeterAtZ0 = 20.0 * 0.345;

  /// Factory calibrated to match GamePigeon's dynamic wide-angle 1-point perspective:
  /// - Focal distance d = 3.0 (wide-angle FOV with 2.5x foreshortening)
  /// - Apparent ball-to-rim ratio is 1.37x (matching GamePigeon's ~1.4x)
  /// - Horizon line at 44.1% height (mid-screen vanishing point)
  /// - Camera eye height at 1.67m (natural player eye level)
  /// - Exactly preserves the 3 key visual anchors:
  ///   * Hoop rim (Y=3.05m, Z=4.50m) projects to Y=0.250H (Forge2D Y=5.0)
  ///   * Back wall baseline (Y=0.0m, Z=5.25m) projects to Y=0.650H (Forge2D Y=13.0)
  ///   * Ready ball at foul line (Y=0.25m, Z=0.0m) projects to Y=0.931H (Forge2D Y=18.62)
  factory PerspectiveCamera3D.standard(double screenWidth, double screenHeight) {
    final horizonY = screenHeight * 0.441;
    final ppm = screenHeight * 0.345;

    return PerspectiveCamera3D(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      horizonScreenY: horizonY,
      eyeHeightInMeters: 1.67,
      focalDistance: 3.0,
      pixelsPerMeter: ppm,
    );
  }

  /// Inverts a Forge2D X offset to physical 3D meters at depth [z].
  double unprojectForge2DX(double f2dX, {double z = 0.0}) {
    final s = scaleAtDepth(z);
    final metersToPixels = screenHeight / 20.0;
    return (f2dX * metersToPixels) / (pixelsPerMeter * s);
  }

  /// Perspective scale factor at depth [z] (in meters).
  /// scale = 1.0 at z = 0 (foreground hands), shrinks as z increases towards the hoop.
  double scaleAtDepth(double z) {
    if (z <= -focalDistance * 0.8) return 2.5;
    return focalDistance / (z + focalDistance);
  }

  /// Projects a 3D point [p] (in meters) to 2D screen coordinates (in pixels).
  Offset project(Vector3 p) {
    return projectCoords(p.x, p.y, p.z);
  }

  /// Projects an $(x, y, z)$ coordinate to 2D screen coordinates (in pixels).
  Offset projectCoords(double x, double y, double z) {
    final s = scaleAtDepth(z);
    final screenX = (screenWidth / 2.0) + (x * pixelsPerMeter * s);
    final screenY = horizonScreenY + ((eyeHeightInMeters - y) * pixelsPerMeter * s);
    return Offset(screenX, screenY);
  }

  /// Projects a 3D coordinate to Forge2D world meters (20m total height, (0,0) at top-center).
  Offset projectToForge2D(double x, double y, double z) {
    final screenPos = projectCoords(x, y, z);
    final metersToPixels = screenHeight / 20.0;
    final f2dX = (screenPos.dx - screenWidth / 2.0) / metersToPixels;
    final f2dY = screenPos.dy / metersToPixels;
    return Offset(f2dX, f2dY);
  }
}
