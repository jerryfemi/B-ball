import 'dart:math' as math;

/// Single Source of Truth (SSOT) for all tunable archery parameters (Build Plan v2).
///
/// Follows GamePigeon-style archery conventions:
/// - 50 ft target distance (15.24 m)
/// - 80 cm World Archery regulation face on square white board
/// - Dolly-only camera (no rotation) with horizon lens shift
/// - Thumb-roll crosshair with steady ring, timer arc, and deterministic sway
/// - Per-arrow 2D wind with wind pill
/// - Sets of 3 arrows format
abstract final class ArcheryK {
  // --- Distance & World Geometry ---
  /// Target distance: 50 ft in meters.
  static const double distanceM = 15.24;
  static const String distanceLabel = '50ft';

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
  static const double fovYDeg = 60.0;
  static const double fovYRad = fovYDeg * math.pi / 180.0;
  static const double minFovXDeg = 56.0; // Never show less than this horizontally (contain rule)
  static const double minFovXRad = minFovXDeg * math.pi / 180.0;

  /// Fraction of smaller screen side occupied by target face diameter while aiming.
  static const double aimFaceFrac = 0.26;

  /// Horizon lens shift (fraction of screen height).
  static const double horizonFrac = 0.52;

  /// "At the line" camera position (behind the archer).
  static const double camLineZ = -2.0;

  /// Aiming camera position (pushed in).
  static const double camAimZ = 1.0;

  /// Close-up camera distance in front of target.
  static const double camCloseupDist = 2.2;

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

  // --- Wind (GamePigeon 0.0 - 2.0 format) ---
  static const double windMaxDisplay = 2.0;
  static const double windLateralAccelPerUnit = 1.9; // m/s² per 1.0 displayed wind
  static const double windAlongAccelPerUnit = 0.6;   // m/s² per 1.0 displayed wind
}
