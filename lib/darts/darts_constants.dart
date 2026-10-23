/// Single Source of Truth (SSOT) for all tunable darts parameters (DARTS_PLAN.md).
///
/// Follows GamePigeon Darts 301 feel:
/// - 301 countdown, straight in, straight out, equal turns
/// - Standard London / clock dartboard dimensions in millimeters
/// - Fixed-step 240 Hz ballistic dart physics at 2.37 m distance
/// - Hold-aim, flick-up throw with sweet-band power/angle error
/// - Settle → steady → fatigue deterministic reticle wobble
/// - Real perspective camera behind the oche; the dart is drawn from an
///   angle-sweep sprite sheet (one row per viewing angle)
abstract final class DartsK {
  // ─── Regulation Dartboard Dimensions (mm) ─────────────────────────────────
  // Radii measured from board center to the outer edge of each wire boundary.
  // Standard BDO / WDF / PDC regulation dartboard specifications.
  static const double innerBullR = 6.35;
  static const double outerBullR = 15.9;
  static const double trebleInR = 99.0;
  static const double trebleOutR = 107.0;
  static const double doubleInR = 162.0;
  static const double doubleOutR = 170.0;

  /// Outer radius of the scoring board face (including black number ring).
  static const double boardR = 225.5;

  /// Standard clock dartboard segment sequence clockwise starting from top (12 o'clock).
  /// 20 is centered on top (spanning -9° to +9°).
  static const List<int> segmentOrder = <int>[
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];

  /// Angular width of each of the 20 radial segments (18 degrees).
  static const double segmentAngleDeg = 18.0;

  // ─── Physics & Ballistics ──────────────────────────────────────────────────
  /// Standard regulation oche throw distance (2.37 m / 7 ft 9.25 in).
  static const double throwDistanceM = 2.37;

  /// Earth gravity (m/s²).
  static const double gravity = 9.81;

  /// Launch speed used by the ballistic solver (m/s). About 0.27 s to the
  /// board: quick like a real throw, with a small rise and a visible dip.
  static const double idealSpeed = 9.0;

  /// Fixed physics integration timestep (240 Hz).
  static const double fixedDt = 1.0 / 240.0;

  /// Maximum substeps integrated per display frame.
  static const int maxSubstepsPerFrame = 8;

  /// Maximum frame dt passed into the accumulator (clamped to 1/20 s).
  static const double dtClamp = 0.05;

  // ─── Flick & Throw Gesture (pure flick, no aim preview) ────────────────────
  /// Minimum upward flick speed required to trigger a throw (screen heights / s).
  /// Releasing below this speed drops the dart back into the hand with no penalty.
  static const double minFlick = 0.90;

  /// Upward flick speed (screen heights / s) that sends the dart to bull height.
  /// Faster goes higher, slower goes lower.
  static const double flickRefSpeed = 2.4;

  /// Board millimetres of height per 1.0 of flick speed relative to
  /// [flickRefSpeed] (10% faster ≈ 26 mm higher). Treble 20 needs a
  /// consistent flick about 40% faster than the bull flick.
  static const double flickHeightMmPerUnit = 260.0;

  /// Sideways drift: board mm per tan(angle) of the swipe away from straight
  /// up (5° past the dead zone ≈ 26 mm).
  static const double flickDriftMmPerTan = 300.0;

  /// A natural thumb arc this close to straight up adds no drift (degrees).
  static const double flickDeadZoneDeg = 2.0;

  /// Aim is clamped to this radius (board mm); anything past ~226 mm misses.
  static const double flickMaxAimMm = 420.0;

  /// Touches above this fraction of the screen height don't pick the dart up.
  static const double flickTouchTopFrac = 0.45;

  /// Nominal ideal upward flick speed (screen heights / s).
  static const double idealFlick = 1.60;

  /// Sweet band for flick power relative to ideal (0.8× to 1.3×).
  /// Inside this band, power error is 0.
  static const double sweetLow = 0.8;
  static const double sweetHigh = 1.3;

  /// Millimeters of vertical landing error per 1.0 unit of normalized power error.
  /// Target: 25% outside the sweet band (0.25) ≈ 30 mm off target.
  static const double powerErrorPerUnit = 120.0;

  /// Angle tolerance vs straight-up (±6°).
  /// Inside this cone, yaw error is 0.
  static const double angleSweetDeg = 6.0;

  /// Millimeters of lateral landing error per extra degree beyond [angleSweetDeg].
  static const double angleErrorMmPerDeg = 2.5;

  /// Thumb-roll aim sensitivity (board-mm per screen pixel at reference board size).
  static const double aimGain = 1.6;

  // ─── Reticle Wobble / Sway Model (mm) ──────────────────────────────────────
  /// Initial settling wobble amplitude immediately after touch-down (mm).
  static const double wobbleSettle = 18.0;

  /// Exponential decay time constant for settling wobble (seconds).
  static const double wobbleSettleTau = 0.6;

  /// Baseline steady window wobble amplitude (mm).
  static const double wobbleBase = 4.0;

  /// Maximum additional fatigue wobble amplitude (mm).
  static const double wobbleFatigue = 20.0;

  /// Hold duration after which fatigue shake begins to ramp up (seconds).
  static const double fatigueStart = 3.0;

  /// Hold duration at which fatigue shake reaches maximum amplitude (seconds).
  static const double fatigueFull = 5.0;

  // ─── Match Rules & Timing ──────────────────────────────────────────────────
  static const int startScore = 301;
  static const int dartsPerTurn = 3;
  static const int maxRounds = 20;

  /// Shot clock per dart in online play (seconds).
  static const int shotClockSeconds = 20;

  /// Match round duration timeout for Firestore online turn claim (seconds).
  static const int onlineTurnSeconds = 90;

  /// Bot accuracy standard deviation (mm) for 2D Gaussian scatter.
  static const double botSigmaMm = 20.0;

  /// Delay between completing a turn and starting the dart retrieval / fade (seconds).
  static const double turnEndPauseSec = 0.8;

  /// Flight interval between successive bot darts (seconds).
  static const double botDartGapSec = 0.7;

  // ─── Screen Layout & Camera Framing ───────────────────────────────────────
  /// Reference aspect ratio for portrait framing (same formula as Archery):
  /// refW = min(width, height * refAspect).
  static const double refAspect = 0.62;

  /// Board outer diameter as a fraction of refW.
  static const double boardFrac = 0.92;

  /// Vertical position of the board center as a fraction of screen height.
  static const double boardCenterYFrac = 0.38;

  // ─── Camera (real perspective, DARTS_PLAN §1.5 rebuilt) ────────────────────
  /// The player's eye is this far behind the release point (m). The dart in
  /// hand sits this far in front of the camera, so it is drawn big and
  /// shrinks fast as it flies away.
  static const double releaseDepthM = 0.82;

  /// Where the tip of the dart in hand sits, as a fraction of screen height.
  /// The eye height is solved from this so the board stays where it is.
  static const double handTipFrac = 0.67;

  /// How far the dart in hand lifts with the finger (fraction of screen height).
  static const double handLiftFrac = 0.05;

  /// The dart in hand points up/forward at this angle (degrees), showing depth
  /// and receding toward the board.
  static const double handPitchDeg = 48.0;

  // ─── Dart Sprites & Animation ──────────────────────────────────────────────
  /// Drawn dart length, tip to tail (m). Sized so it sits naturally in hand
  /// and fits comfortably on the board.
  static const double dartLengthM = 0.076;

  /// In-hand scale multiplier so the entire dart body (flights, shaft, and tip)
  /// is fully visible in frame.
  static const double handDartScale = 0.82;

  /// The dart's pitch in flight is exaggerated by this much so the rise and
  /// the dip into the board read clearly (1 = exactly along the velocity).
  static const double flightPitchGain = 1.6;

  /// Fraction of the flight over which the dart turns from its in-hand pose
  /// to pointing along its velocity.
  static const double launchSettleFrac = 0.35;

  /// Light direction for dart shadows (travelling toward the board, z = -1):
  /// from above and slightly left, so shadows fall below and right and
  /// slide in to meet the dart as it lands.
  static const double shadowLightX = 0.08;
  static const double shadowLightY = -0.22;

  /// Flight spin rate in revolutions per second (~4.5 turns/s).
  static const double flightSpinRps = 4.5;

  /// Maximum stuck dart wobble duration upon impact (seconds).
  static const double stuckWobbleDurationSec = 0.35;

  /// Stuck dart pull-out fade duration (seconds).
  static const double dartPullFadeSec = 0.20;

  // ─── UI Palette Tokens (ARGB hex integers) ───────────────────────────────
  static const int surfaceDark = 0xFF0A0E1A;
  static const int surfaceMid = 0xFF0F172A;
  static const int surfaceCard = 0xFF1E2638;

  static const int accentP1 = 0xFF38BDF8; // Sky blue (You)
  static const int accentP2 = 0xFFF59E0B; // Amber (Opponent / Bot)
  static const int accentMint = 0xFF00FFCC; // Green / Checkout
  static const int accentRed = 0xFFEF4444; // Bust / Miss

  static const int textPrimary = 0xFFFFFFFF;
  static const int textMuted = 0xFF94A3B8;
  static const int textSubtle = 0xFF64748B;
}
