import 'dart:math' as math;
import '../archery_constants.dart';

/// Zero-rotation, dolly-only pinhole camera with lens shift (Build Plan v2).
///
/// Features:
/// - Never turns (yaw = 0, pitch = 0), keeping ground plane and billboards exact.
/// - Dolly movement only (eyeX, eyeY, eyeZ).
/// - Lens shift (horizonFrac = 0.52) placing the horizon slightly below center.
/// - Unprojection from screen pixels to 3D world coordinates on plane Z = D.
/// - Zero allocations per frame.
class ArcheryCamera {
  // --- Camera Position (Meters) ---
  double eyeX = 0.0;
  double eyeY = ArcheryK.eyeY;
  double eyeZ = ArcheryK.camLineZ;

  // Viewport dimensions
  double screenW = 0.0;
  double screenH = 0.0;

  // Zoom & UI scale
  double zoom = 1.0;
  double uiScale = 1.0;

  // Cached optical parameters
  double _baseF = 0.0;
  double _f = 0.0;
  double _cx = 0.0;
  double _cy = 0.0;

  // --- Output Registers for project() ---
  double sx = 0.0;
  double sy = 0.0;
  double depth = 0.0;

  // --- Output Registers for unprojectToPlane() ---
  double outX = 0.0;
  double outY = 0.0;

  /// Portrait-equivalent width used for framing (see [ArcheryK.refAspect]).
  double get refWidth => math.min(screenW, screenH * ArcheryK.refAspect);

  /// Precomputes optical centres and focal length.
  ///
  /// Long-lens framing like GamePigeon: the focal length is chosen so the
  /// target face at 50 ft covers [ArcheryK.lineFaceFrac] of [refWidth] from the
  /// line. It never depends on the current set's distance, so 100 ft and
  /// 150 ft targets really do look smaller (that's the difficulty curve).
  void prepare() {
    if (screenW <= 0.0 || screenH <= 0.0) return;
    _baseF = ArcheryK.lineFaceFrac *
        refWidth *
        (ArcheryK.distanceM - ArcheryK.camLineZ) /
        (2.0 * ArcheryK.faceRadius);
    _f = _baseF * zoom;
    _cx = screenW * 0.5;
    _cy = screenH * ArcheryK.horizonFrac; // Lens shift
  }

  /// Projects 3D world position ([x], [y], [z]) in meters onto the 2D screen.
  bool project(double x, double y, double z) {
    final double dz = z - eyeZ;
    depth = dz;
    if (dz <= 0.05) return false;

    final double inv = 1.0 / dz;
    sx = _cx + _f * (x - eyeX) * inv;
    sy = _cy - _f * (y - eyeY) * inv;
    return true;
  }

  /// Inverse projection: maps screen pixel point ([screenX], [screenY]) to world
  /// coordinates on the vertical plane at [planeZ].
  ///
  /// Writes results to [outX] and [outY].
  void unprojectToPlane(double screenX, double screenY, double planeZ) {
    final double dz = planeZ - eyeZ;
    outX = eyeX + (screenX - _cx) * dz / _f;
    outY = eyeY - (screenY - _cy) * dz / _f;
  }

  /// Scale factor: screen pixels per 1 meter at specified [depth].
  double pxPerMeterAt(double depth) => depth > 0.05 ? _f / depth : 0.0;

  /// Effective focal length in pixels.
  double get focalLengthPx => _f;
  double get focal => _f;
  double get baseFocal => _baseF;

  double get opticalCenterX => _cx;
  double get opticalCenterY => _cy;
}
