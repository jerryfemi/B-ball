import 'dart:math' as math;

/// Single Source of Truth (SSOT) for all tunable archery parameters (Build Plan v2).
///
/// Follows GamePigeon-style archery conventions:
/// - 50 ft target distance (15.24 m)
/// - 80 cm World Archery regulation face on square white board
/// - Dolly-only camera (no rotation) with horizon lens shift
/// - Thumb-roll crosshair with steady ring, timer arc, and deterministic sway
/// - Per-arrow wind in mph with wind pill
/// - Sets of 3 arrows format
abstract final class ArcheryK {
  // --- Distance & World Geometry ---
  /// Reference distance (set 1): 50 ft in meters. Camera framing, aim
  /// sensitivity and wind strength are all calibrated at this distance.
  static const double distanceM = 15.24;

  /// Target distance per set (GamePigeon): 50 ft → 100 ft → 150 ft,
  /// then stays at 150 ft for any further sets.
  static const List<double> setDistancesM = [15.24, 30.48, 45.72];
  static const List<String> setDistanceLabels = ['50ft', '100ft', '150ft'];

  static double distanceForSet(int setIndex) =>
      setDistancesM[setIndex.clamp(0, setDistancesM.length - 1)];
  static String distanceLabelForSet(int setIndex) =>
      setDistanceLabels[setIndex.clamp(0, setDistanceLabels.length - 1)];

  /// Archer eye position height above ground (m).
  static const double eyeY = 1.60;

  /// Arrow nock/launch point height (under the chin, m).
  static const double launchY = 1.52;

  /// Forward launch offset from eye along Z (m).
  static const double launchZ = 0.35;

  /// Length of the arrow shaft (m).
  static const double arrowLength = 0.75;

  /// Arrow shaft radius (m) used for the line-cutter scoring rule.
  static const double arrowShaftRadius = 0.0035;

  // --- Target & Board (80 cm face on 1.0m board) ---
  /// 80 cm World Archery face outer radius (m).
  static const double faceRadius = 0.40;

  /// Width of each concentric ring (10 rings total, m).
  static const double ringWidth = 0.040;

  /// Inner X-ring radius (m).
  static const double xRingRadius = 0.020;

  /// Height of target face center above ground (m).
  static const double targetCenterY = 1.30;

  /// White square board dimensions (m).
  static const double boardWidth = 1.00;
  static const double boardHeight = 1.00;
  static const double boardFrame = 0.025; // brown wooden edge
  static const double legHeight = 0.80;  // board bottom height above ground

  // Compatibility aliases
  static const double bossWidth = boardWidth;
  static const double bossHeight = boardHeight;
  static const double bossDepth = 0.15;

  // --- Physics Constants ---
  static const double gravity = 9.81;
  static const double fullDrawSpeed = 62.0; // m/s at release (every arrow full speed)
  static const double dragK = 0.0006;       // quadratic drag coefficient (1/m)
  static const double fixedDt = 1.0 / 240.0;
  static const int maxSubstepsPerFrame = 8;

  // --- Camera & Dolly Viewpoints ---
  // Framing is defined by how big the target face looks (GamePigeon-style
  // long lens), measured against a portrait "reference width":
  //   refW = min(screenWidth, screenHeight * refAspect)
  // so phones, tablets and desktop all frame the target the same way.
  static const double refAspect = 0.62;

  /// Target face diameter / refW at the line, at 50 ft.
  static const double lineFaceFrac = 0.11;

  /// Target face diameter / refW while aiming, at 50 ft (about 1.5× the line
  /// view, like GamePigeon). Farther sets look proportionally smaller.
  static const double aimFaceFrac = 0.175;

  /// Focal zoom applied while aiming (constant; the dolly adds the rest).
  static const double aimZoom = (aimFaceFrac / lineFaceFrac) *
      ((distanceM - camAimZ) / (distanceM - camLineZ));

  /// Horizon lens shift (fraction of screen height).
  static const double horizonFrac = 0.52;

  /// "At the line" camera position (behind the archer).
  static const double camLineZ = -2.0;

  /// Painted shooting line on the ground, drawn ahead of the archer so it is
  /// visible near the bottom of the long-lens line view (the archer's feet are
  /// off-screen). Must match the value in shaders/archery_ground.frag.
  static const double shootingLineZ = 4.0;

  /// Half-width of the lane at the shooting line (the "V" lines start here).
  static const double laneHalfWidthAtLine = 1.6;

  /// Aiming camera position (pushed in).
  static const double camAimZ = 1.0;

  /// Close-up camera distance in front of target (board fills ~60% of refW).
  static const double camCloseupDist = 3.8;

  /// Chase camera offset behind and above arrow.
  static const double chaseBehind = 1.2;
  static const double chaseAbove = 0.15;

  // --- Aim Controls (Thumb-Roll) ---
  /// Crosshair pixels per pixel of thumb movement.
  static const double aimGain = 3.0;

  /// Exponential smoothing frequency on raw crosshair input.
  static const double aimSmoothOmega = 18.0;

  /// Steady ring start radius fraction of screen width.
  static const double ringStartRadiusFrac = 0.30;

  /// Time in seconds for steady ring to shrink to minimum size.
  static const double ringSettleSeconds = 1.8;

  /// Maximum shot hold duration before auto-firing.
  static const double shotTimerSeconds = 5.0;

  // --- Sway (radians of aim angle) ---
  static const double swaySettle = 0.0060;
  static const double swaySettleTau = 0.6;
  static const double swayBase = 0.0008;
  static const double swayFatigue = 0.0035;
  static const double fatigueStart = 3.5;

  // --- Wind (mph) ---
  /// Strongest wind shown (mph).
  static const double windMaxMph = 12.0;

  /// Same value under its old name (tree sway and the gauge scale by it).
  static const double windMaxDisplay = windMaxMph;

  /// Push per mph at 50 ft (m/s²). Calibrated so a full 12 mph crosswind
  /// moves an unaimed arrow about 5 rings at 50 ft, 7 at 100 ft and 9 at
  /// 150 ft (the edge of the face).
  static const double windLateralAccelPerMph = 0.55;

  /// Tailwind lifts / headwind drops: about a third of the crosswind effect.
  static const double windVerticalAccelPerMph = 0.18;
  static const double windAlongAccelPerMph = 0.05;

  /// Wind is calibrated at 50 ft. Drift grows with flight time², so without
  /// scaling a 150 ft arrow would drift ~9× more. (50ft/D)^1.45 keeps the
  /// growth to about 5 → 7 → 9 rings across the three distances.
  static double windScaleFor(double distance) =>
      math.pow(distanceM / distance, 1.45).toDouble();
}
