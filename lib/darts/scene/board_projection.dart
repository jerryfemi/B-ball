import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../darts_constants.dart';

/// The camera: maps board millimetres and 3D flight positions to screen pixels.
///
/// The board is framed exactly as before (DARTS_PLAN.md §1.5):
/// - `refW = min(width, height * DartsK.refAspect)`, board diameter
///   `refW * DartsK.boardFrac`, centred horizontally at
///   `height * DartsK.boardCenterYFrac`.
/// - Board mm: centre `(0, 0)`, `+x` right, `+y` up.
///
/// On top of that it is a real pinhole camera, so a thrown dart is drawn in
/// true perspective (big in your hand, shrinking fast as it flies away):
/// - Physics space (metres): `+x` right, `+y` up (0 = bull height), `+z` is
///   the distance from the board (the dart leaves your hand at
///   `z = DartsK.throwDistanceM`).
/// - The eye sits [DartsK.releaseDepthM] behind the release point at height
///   [eyeHeightM]; the eye height is solved so the dart in hand appears at
///   [DartsK.handTipFrac] of the screen height while the board plane keeps
///   exactly the 2D framing above.
///
/// Everything is recomputed in [resize] only; the projection helpers write
/// into fields, so `update()`/`render()` allocate nothing.
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

  /// Screen pixels per board millimetre on the board plane.
  double mmToPx = 0.0;

  /// Board millimetres per screen pixel on the board plane.
  double pxToMm = 0.0;

  // ── Camera ─────────────────────────────────────────────────────────────────
  /// Distance from the eye to the board (m).
  double eyeZ = 0.0;

  /// Eye height above bull height (m).
  double eyeHeightM = 0.0;

  /// Focal length in pixels.
  double focalPx = 0.0;

  /// Screen y of the eye's height (where a level line of sight lands).
  double horizonY = 0.0;

  // ── Hand ───────────────────────────────────────────────────────────────────
  /// Where the tip of the dart in hand sits at rest (screen px).
  double handX = 0.0;
  double handY = 0.0;

  // ── Projection outputs (written by [project] / [projectBoard]) ─────────────
  /// Last projected screen x / y (px) and the point's depth from the eye (m).
  double outX = 0.0;
  double outY = 0.0;
  double outDepth = 1.0;

  /// Recomputes all metrics for the viewport [size]. Never called per frame.
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

    // Camera: pixels per metre on the board plane, s0 = focal / eyeZ.
    final double s0 = mmToPx * 1000.0;
    eyeZ = DartsK.throwDistanceM + DartsK.releaseDepthM;
    focalPx = s0 * eyeZ;

    // A release point at bull height appears s0*h*(eyeZ/release - 1) px
    // below the board centre; solve h so that lands at handTipFrac.
    final double spread = s0 * (eyeZ / DartsK.releaseDepthM - 1.0);
    final double drop =
        (DartsK.handTipFrac - DartsK.boardCenterYFrac) * screenHeight;
    eyeHeightM = spread > 0.0 ? drop / spread : 0.0;
    horizonY = boardCenterY - s0 * eyeHeightM;

    handX = boardCenterX;
    handY = screenHeight * DartsK.handTipFrac;
  }

  /// Projects a physics-space point (m) to the screen. Writes [outX], [outY]
  /// and [outDepth]. Points closer than 5 cm to the eye are clamped there.
  void project(double xM, double yM, double zM) {
    double depth = eyeZ - zM;
    if (depth < 0.05) depth = 0.05;
    outDepth = depth;
    outX = boardCenterX + focalPx * xM / depth;
    outY = horizonY - focalPx * (yM - eyeHeightM) / depth;
  }

  /// Turns a screen point into the physics-space point at distance
  /// [zM] from the board that projects there. Writes x into [outX] and y
  /// into [outY] (metres).
  void unproject(double screenX, double screenY, double zM) {
    final double depth = math.max(0.05, eyeZ - zM);
    outX = (screenX - boardCenterX) * depth / focalPx;
    outY = eyeHeightM - (screenY - horizonY) * depth / focalPx;
    outDepth = depth;
  }

  /// Converts board millimetres to screen pixels, in place.
  void boardMmToScreen(double xMm, double yMm, Vector2 out) {
    out.x = boardCenterX + (xMm * mmToPx);
    out.y = boardCenterY - (yMm * mmToPx);
  }

  /// Convenience record version of [boardMmToScreen].
  ({double dx, double dy}) boardMmToOffset(double xMm, double yMm) {
    return (
      dx: boardCenterX + (xMm * mmToPx),
      dy: boardCenterY - (yMm * mmToPx),
    );
  }

  /// Converts screen pixels to board millimetres, in place.
  void screenToBoardMm(double screenX, double screenY, Vector2 out) {
    out.x = (screenX - boardCenterX) * pxToMm;
    out.y = (boardCenterY - screenY) * pxToMm;
  }
}
