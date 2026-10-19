import 'dart:math' as math;

/// Single Source of Truth (SSOT) for all tunable archery parameters.
///
/// Follows DunkVerse conventions: SI units (meters, seconds, radians).
/// All values are calibrated for realistic yet snappy arcade feel.
abstract final class ArcheryK {
  // --- Physics Constants ---
  /// Standard gravity acceleration in m/s².
  static const double gravity = 9.81;

  /// Arrow velocity at 100% full draw (m/s).
  /// Fast arcade velocity (real compound/recurve bows are ~55–90 m/s).
  static const double fullDrawSpeed = 62.0;

  /// Speed ratio at minimal/accidental draw (60% of full draw speed).
  static const double minDrawSpeedRatio = 0.60;

  /// Draw ratio threshold (95%) that counts as a perfect full draw.
  static const double fullDrawPlateau = 0.95;

  /// Aerodynamic quadratic drag coefficient (1/m).
  static const double dragK = 0.0006;

  /// Lateral acceleration per 1 m/s of crosswind (m/s² per m/s).
  static const double windAccelPerMps = 0.10;

  /// Fixed physics integration timestep (240 Hz = ~4.167 ms).
  static const double fixedDt = 1.0 / 240.0;

  /// Maximum physics substeps per rendered frame to prevent death spirals.
  static const int maxSubstepsPerFrame = 8;

  // --- World & Geometry ---
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

  // --- Target & Boss ---
  /// World Archery 122 cm target face outer radius (m).
  static const double faceRadius = 0.61;

  /// Width of each concentric ring (10 rings total, m).
  static const double ringWidth = 0.061;

  /// Inner X-ring radius (m).
  static const double xRingRadius = 0.0305;

  /// Height of target face center above ground (m).
  static const double targetCenterY = 1.30;

  /// Width of straw/foam boss (m).
  static const double bossWidth = 1.30;

  /// Height of straw/foam boss (m).
  static const double bossHeight = 1.30;

  /// Thickness of straw/foam boss (m).
  static const double bossDepth = 0.30;

  // --- Standard Round Distances ---
  static const double distNear = 20.0;
  static const double distMid = 40.0;
  static const double distFar = 60.0;
  static const List<double> roundDistances = [distNear, distMid, distFar];

  // --- Input & Feel Timings ---
  /// Duration of hold required to reach 100% full draw (seconds).
  static const double autoDrawSeconds = 0.70;

  /// Hold duration after which arm fatigue and sway begins (seconds).
  static const double fatigueStartSeconds = 2.5;

  /// Hold duration at which fatigue reaches maximum sway intensity (seconds).
  static const double fatigueFullSeconds = 6.0;

  /// Base sway amplitude in radians (approx ±7 cm at 60 m).
  static const double baseSwayRad = 0.0012;

  /// Sway multiplier at peak fatigue.
  static const double fatigueSwayMultiplier = 3.0;

  /// Screen pixels of reticle movement per pixel of touch drag.
  static const double aimSensitivity = 0.55;

  // --- Aim Angle Clamps ---
  /// Maximum yaw rotation allowed left/right (±12° in radians).
  static const double maxYawRad = 12.0 * math.pi / 180.0;

  /// Minimum pitch rotation allowed (look down -5° in radians).
  static const double minPitchRad = -5.0 * math.pi / 180.0;

  /// Maximum pitch rotation allowed (look up +10° in radians).
  static const double maxPitchRad = 10.0 * math.pi / 180.0;

  // --- Camera & Optics ---
  /// Default idle vertical Field of View (degrees).
  static const double idleFovDeg = 42.0;
  static const double idleFovRad = idleFovDeg * math.pi / 180.0;

  /// Fraction of screen height that target face occupies at full draw.
  static const double faceScreenFraction = 0.38;

  /// Critically damped spring angular frequency for FOV zoom.
  static const double fovSpringOmega = 9.0;

  // --- Aesthetics & Color Palette ---
  static const int colorBgDark = 0xFF0A0E1A;
  static const int colorSurfaceCard = 0xFF0F172A;
  static const int colorSurfaceTile = 0xFF1E2638;
  static const int colorAccentCyan = 0xFF00FFCC;
  static const int colorAccentSky = 0xFF38BDF8;
  static const int colorAccentAmber = 0xFFF59E0B;
  static const int colorAccentRed = 0xFFEF4444;
  static const int colorTextMuted = 0xFF94A3B8;
}
