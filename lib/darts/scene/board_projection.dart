import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../darts_constants.dart';

/// Camera projection mapping between dartboard millimeters and screen pixels.
///
/// Follows DARTS_PLAN.md §1.5:
/// - Screen framing: `refW = min(width, height * DartsK.refAspect)`.
/// - Board diameter: `refW * DartsK.boardFrac`.
/// - Board center: horizontally centered, vertical at `height * DartsK.boardCenterYFrac`.
/// - Coordinate conversion:
///   - Board center is `(0, 0)` in millimeters.
///   - `+x` is right (mm), `+y` is up (mm).
///   - Screen `(0, 0)` is top-left, `+x` right (px), `+y` down (px).
/// - Depth scale: perspective scaling for flying darts (`~1.0` at release down to `~0.15` at board).
/// - Zero heap allocations: recomputed ONLY on `resize()`, with in-place vector helpers.
class BoardProjection {
  // ── Screen Dimensions ──────────────────────────────────────────────────────
  double screenWidth = 0.0;
  double screenHeight = 0.0;
  double refW = 0.0;

  // ── Board Pixel Geometry ───────────────────────────────────────────────────
  double boardDiameterPx = 0.0;
  double boardRadiusPx = 0.0;
  double boardCenterX = 0.0;
  double boardCenterY = 0.0;

  /// Conversion ratio: screen pixels per board millimeter at the board plane ($z = 0$).
  double mmToPx = 0.0;

  /// Conversion ratio: board millimeters per screen pixel.
  double pxToMm = 0.0;

  // ── Hand / Release Anchor (px) ─────────────────────────────────────────────
  double handX = 0.0;
  double handY = 0.0;

  // ── Cached Vector2 for Zero-Allocation Projection ──────────────────────────
  final Vector2 _cachedScreenPos = Vector2.zero();
  final Vector2 _cachedBoardPos = Vector2.zero();

  /// Recomputes all projection metrics given the current viewport [size].
  ///
  /// Must be called during `onGameResize`. Never called in `update()` or `render()`.
  void resize(Vector2 size) {
    screenWidth = size.x;
    screenHeight = size.y;

    refW = math.min(screenWidth, screenHeight * DartsK.refAspect);

    boardDiameterPx = refW * DartsK.boardFrac;
    boardRadiusPx = boardDiameterPx * 0.5;

    boardCenterX = screenWidth * 0.5;
    boardCenterY = screenHeight * DartsK.boardCenterYFrac;

    mmToPx = boardRadiusPx / DartsK.boardR;
    pxToMm = mmToPx > 0.0 ? (1.0 / mmToPx) : 0.0;

    handX = boardCenterX;
    handY = screenHeight * (1.0 - DartsK.restingDartHeightFrac * 0.35);
  }

  /// Converts board millimeter coordinates `(xMm, yMm)` to screen pixel coordinates `(xPx, yPx)`.
  ///
  /// In-place write to [out] avoids heap allocation in hot render loops.
  void boardMmToScreen(double xMm, double yMm, Vector2 out) {
    out.x = boardCenterX + (xMm * mmToPx);
    out.y = boardCenterY - (yMm * mmToPx);
  }

  /// Convenience method returning a pixel coordinate record `(dx, dy)`.
  ({double dx, double dy}) boardMmToOffset(double xMm, double yMm) {
    return (
      dx: boardCenterX + (xMm * mmToPx),
      dy: boardCenterY - (yMm * mmToPx),
    );
  }

  /// Converts screen pixel coordinates `(screenX, screenY)` to board millimeters.
  ///
  /// In-place write to [out] avoids heap allocation.
  void screenToBoardMm(double screenX, double screenY, Vector2 out) {
    out.x = (screenX - boardCenterX) * pxToMm;
    out.y = (boardCenterY - screenY) * pxToMm;
  }

  /// Computes perspective depth scale factor for a dart at distance [zM] (meters) to the board.
  ///
  /// At release ($z = 2.37$ m): `depthScale ≈ 1.0`.
  /// At board plane ($z = 0.0$ m): `depthScale ≈ 0.15`.
  double depthScale(double zM) {
    // Distance from virtual camera (behind player's eye) to board:
    // f = 0.42 m gives exact 0.42 / (2.37 + 0.42) = 0.1505 (~0.15) at board.
    const double fCam = 0.42;
    final double distFromEye = (DartsK.throwDistanceM - zM) + fCam;
    if (distFromEye <= 1e-4) return 1.0;
    return (fCam / distFromEye).clamp(0.10, 1.20);
  }

  /// Projects 3D dart physics position `(xM, yM, zM)` into 2D screen coordinates `(pxX, pxY)`.
  ///
  /// In-place write to [out] guarantees zero heap allocations.
  void projectFlightPosition(double xM, double yM, double zM, Vector2 out) {
    // Board impact point in screen pixels
    final double targetPxX = boardCenterX + (xM * 1000.0) * mmToPx;
    final double targetPxY = boardCenterY - (yM * 1000.0) * mmToPx;

    // Fractional progress along throw distance (0.0 = at hand, 1.0 = at board)
    final double flightFrac =
        ((DartsK.throwDistanceM - zM) / DartsK.throwDistanceM).clamp(0.0, 1.0);

    // Smooth linear screen interpolation toward the target
    out.x = handX + (targetPxX - handX) * flightFrac;
    out.y = handY + (targetPxY - handY) * flightFrac;
  }

  Vector2 get cachedScreenPos => _cachedScreenPos;
  Vector2 get cachedBoardPos => _cachedBoardPos;
}
