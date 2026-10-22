import 'dart:math' as math;
import '../archery_constants.dart';

/// Immutable record of a single shot score.
class ShotScore {
  /// Ring score: 1 to 10 for target face hits, 0 for miss or boss hit outside rings.
  final int ring;

  /// True if hit inside the inner X-ring (tiebreaker).
  final bool isX;

  /// True if arrow landed on the straw boss.
  final bool hitBoss;

  /// Target distance in meters.
  final double distance;

  /// Horizontal offset from center in meters.
  final double localX;

  /// Vertical offset from center in meters.
  final double localY;

  /// Radial distance from target center in meters.
  final double r;

  const ShotScore({
    required this.ring,
    required this.isX,
    required this.hitBoss,
    required this.distance,
    required this.localX,
    required this.localY,
    required this.r,
  });

  int get points => ring;

  String get displayLabel => isX ? 'X' : (ring > 0 ? '$ring' : 'M');

  /// Hex color token for the ring score.
  int get colorValue {
    if (isX || ring >= 9) return 0xFFF7D000; // Gold
    if (ring >= 7) return 0xFFE0322B;        // Red
    if (ring >= 5) return 0xFF2E7DD7;        // Blue
    if (ring >= 3) return 0xFF94A3B8;        // Slate / Black ring contrast
    if (ring >= 1) return 0xFFFFFFFF;        // White
    return 0xFFEF4444;                       // Miss / Red
  }
}

/// World Archery 122 cm target scoring engine with line-cutter rule.
abstract final class TargetScoring {
  /// Computes the ring score from the impact point ([localX], [localY]) relative
  /// to the target center.
  ///
  /// World Archery Line-Cutter rule:
  /// The arrow shaft has radius [ArcheryK.arrowShaftRadius] (3.5 mm).
  /// If the outer edge of the shaft touches a higher scoring line, the higher
  /// ring is awarded: `rEff = max(0, r - arrowShaftRadius)`.
  static ShotScore calculate({
    required double localX,
    required double localY,
    required bool hitBoss,
    required double distance,
    bool applyLineCutter = true,
  }) {
    if (!hitBoss) {
      return ShotScore(
        ring: 0,
        isX: false,
        hitBoss: false,
        distance: distance,
        localX: localX,
        localY: localY,
        r: double.infinity,
      );
    }

    final double r = math.sqrt(localX * localX + localY * localY);
    final double rEff = applyLineCutter
        ? math.max(0.0, r - ArcheryK.arrowShaftRadius)
        : r;

    // Boss hit outside the outermost 1-ring (radius 0.61 m) = 0 points
    if (rEff > ArcheryK.faceRadius) {
      return ShotScore(
        ring: 0,
        isX: false,
        hitBoss: true,
        distance: distance,
        localX: localX,
        localY: localY,
        r: r,
      );
    }

    // Rings 10 to 1 (each 0.061 m wide)
    final int ring = (10 - (rEff / ArcheryK.ringWidth).floor()).clamp(1, 10);

    // Inner X ring check (radius 0.0305 m)
    final bool isX = rEff <= ArcheryK.xRingRadius;

    return ShotScore(
      ring: ring,
      isX: isX,
      hitBoss: true,
      distance: distance,
      localX: localX,
      localY: localY,
      r: r,
    );
  }
}
