import 'dart:math' as math;
import '../archery_constants.dart';

/// Zero-allocation 3D pinhole camera with yaw/pitch rotation and FOV zoom.
///
/// Converts 3D world coordinates (meters) to 2D canvas coordinates (pixels).
/// Writes results directly to mutable fields [sx], [sy], [depth] to eliminate
/// heap allocations on every frame.
class ArcheryCamera {
  // --- Camera Position ---
  double eyeX = 0.0;
  double eyeY = ArcheryK.eyeY;
  double eyeZ = 0.0;

  // --- Orientation (radians) ---
  /// Rotation around world Y axis (positive = look right).
  double yaw = 0.0;

  /// Rotation around camera X axis (positive = look up).
  double pitch = 0.0;

  /// Vertical field of view in radians.
  double fovY = ArcheryK.idleFovRad;

  // --- Viewport Dimensions (pixels) ---
  double screenW = 0.0;
  double screenH = 0.0;

  // --- Cached Trigonometric & Focal Values ---
  double _f = 0.0;
  double _cy = 1.0;
  double _sy = 0.0;
  double _cp = 1.0;
  double _sp = 0.0;

  // --- Output Registers (read immediately after project()) ---
  double sx = 0.0;
  double sy = 0.0;
  double depth = 0.0;

  /// Call once per frame after [screenW], [screenH], [yaw], [pitch], or [fovY] change.
  void prepare() {
    if (screenH <= 0.0) return;
    _f = (screenH * 0.5) / math.tan(fovY * 0.5);
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(pitch);
    _sp = math.sin(pitch);
  }

  /// Projects 3D world position ([x], [y], [z]) in meters onto the 2D screen.
  ///
  /// Returns `true` if point is in front of the camera near plane (`depth > 0.05m`).
  /// Results are written to [sx], [sy], and [depth].
  bool project(double x, double y, double z) {
    // 1. Translate relative to camera eye
    final double dx = x - eyeX;
    final double dy = y - eyeY;
    final double dz = z - eyeZ;

    // 2. Rotate by -yaw around world Y axis
    final double x1 = _cy * dx - _sy * dz;
    final double z1 = _sy * dx + _cy * dz;

    // 3. Rotate by -pitch around camera X axis
    final double y2 = _cp * dy - _sp * z1;
    final double z2 = _sp * dy + _cp * z1;

    depth = z2;
    if (z2 <= 0.05) return false;

    // 4. Perspective projection onto screen plane
    final double invZ = 1.0 / z2;
    sx = screenW * 0.5 + _f * (x1 * invZ);
    sy = screenH * 0.5 - _f * (y2 * invZ);
    return true;
  }

  /// Calculates the screen pixel radius/length for 1 meter at specified [depth].
  double pxPerMeterAt(double depth) => depth > 0.05 ? _f / depth : 0.0;

  /// Effective focal length in screen pixels.
  double get focalLengthPx => _f;
}
