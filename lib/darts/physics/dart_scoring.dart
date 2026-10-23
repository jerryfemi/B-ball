import 'dart:math' as math;
import '../darts_constants.dart';

/// Immutable representation of a scored dart impact.
class DartHit {
  /// Horizontal impact offset from the board center in millimeters.
  /// Positive is to the right (towards 3 o'clock / segment 6).
  final double x;

  /// Vertical impact offset from the board center in millimeters.
  /// Positive is upwards (towards 12 o'clock / segment 20).
  final double y;

  /// Hit segment number:
  /// - `0`: Complete miss outside the double ring.
  /// - `1`–`20`: Standard radial segments.
  /// - `25`: Outer or inner bull.
  final int segment;

  /// Score multiplier:
  /// - `0`: Miss.
  /// - `1`: Single segment or outer bull (25).
  /// - `2`: Double segment or inner bull (50).
  /// - `3`: Treble segment.
  final int multiplier;

  /// Total scored points awarded for this hit.
  final int points;

  /// Human-readable score display label:
  /// e.g. `'T20'`, `'D16'`, `'S5'`, `'25'`, `'BULL'`, `'MISS'`.
  final String label;

  /// True if this hit landed in the treble ring.
  final bool isTreble;

  /// True if this hit landed in either the inner or outer bullseye.
  final bool isBull;

  /// True if this hit landed in the double ring (or inner bull).
  final bool isDouble;

  /// True if this hit landed in the 50-point inner bullseye.
  final bool isInnerBull;

  /// True if this hit was a complete miss (0 points).
  final bool isMiss;

  /// Radial distance from the board center in millimeters.
  final double r;

  /// Clockwise angle in degrees [0, 360) from 12 o'clock.
  final double angleDeg;

  const DartHit({
    required this.x,
    required this.y,
    required this.segment,
    required this.multiplier,
    required this.points,
    required this.label,
    required this.isTreble,
    required this.isBull,
    this.isDouble = false,
    this.isInnerBull = false,
    this.isMiss = false,
    this.r = 0.0,
    this.angleDeg = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'segment': segment,
    'multiplier': multiplier,
    'points': points,
    'label': label,
    'isTreble': isTreble,
    'isBull': isBull,
    'isDouble': isDouble,
    'isInnerBull': isInnerBull,
    'isMiss': isMiss,
    'r': r,
    'angleDeg': angleDeg,
  };

  factory DartHit.fromMap(Map<String, dynamic> map) {
    return DartHit(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      segment: map['segment'] as int,
      multiplier: map['multiplier'] as int,
      points: map['points'] as int,
      label: map['label'] as String,
      isTreble: map['isTreble'] as bool? ?? false,
      isBull: map['isBull'] as bool? ?? false,
      isDouble: map['isDouble'] as bool? ?? false,
      isInnerBull: map['isInnerBull'] as bool? ?? false,
      isMiss: map['isMiss'] as bool? ?? false,
      r: (map['r'] as num?)?.toDouble() ?? 0.0,
      angleDeg: (map['angleDeg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DartHit &&
        other.segment == segment &&
        other.multiplier == multiplier &&
        other.points == points &&
        other.label == label &&
        (other.x - x).abs() < 1e-4 &&
        (other.y - y).abs() < 1e-4;
  }

  @override
  int get hashCode => Object.hash(segment, multiplier, points, label);

  @override
  String toString() =>
      'DartHit($label: $points pts, seg: $segment ×$multiplier @ (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}) mm)';
}

/// Pure Dart scoring engine for regulation dartboards.
///
/// Converts a landing point `(x, y)` in millimeters into an immutable [DartHit].
///
/// Coordinate system:
/// - `(0, 0)` is the center of the bullseye.
/// - `+x` is to the right (3 o'clock / segment 6).
/// - `+y` is upwards (12 o'clock / segment 20).
abstract final class DartScoring {
  /// Computes the [DartHit] for a dart landing at ([x], [y]) in millimeters.
  static DartHit score(double x, double y) {
    final double r = math.sqrt(x * x + y * y);
    final double deg = calcAngleDeg(x, y);

    // 1. Inner Bullseye (50 points, double)
    if (r <= DartsK.innerBullR) {
      return DartHit(
        x: x,
        y: y,
        segment: 25,
        multiplier: 2,
        points: 50,
        label: 'BULL',
        isTreble: false,
        isBull: true,
        isDouble: true,
        isInnerBull: true,
        isMiss: false,
        r: r,
        angleDeg: deg,
      );
    }

    // 2. Outer Bullseye (25 points, single)
    if (r <= DartsK.outerBullR) {
      return DartHit(
        x: x,
        y: y,
        segment: 25,
        multiplier: 1,
        points: 25,
        label: '25',
        isTreble: false,
        isBull: true,
        isDouble: false,
        isInnerBull: false,
        isMiss: false,
        r: r,
        angleDeg: deg,
      );
    }

    // 3. Complete Miss (beyond the outer edge of the double ring)
    if (r > DartsK.doubleOutR) {
      return DartHit(
        x: x,
        y: y,
        segment: 0,
        multiplier: 0,
        points: 0,
        label: 'MISS',
        isTreble: false,
        isBull: false,
        isDouble: false,
        isInnerBull: false,
        isMiss: true,
        r: r,
        angleDeg: deg,
      );
    }

    // 4. Radial segment determination
    // Segment 20 is centered on 12 o'clock (0°), covering -9° to +9°.
    // Adding 9° maps segment 20 to [0°, 18°), segment 1 to [18°, 36°), etc.
    final double shiftedDeg = (deg + (DartsK.segmentAngleDeg / 2.0)) % 360.0;
    final int segmentIndex =
        (shiftedDeg / DartsK.segmentAngleDeg).floor() % DartsK.segmentOrder.length;
    final int segment = DartsK.segmentOrder[segmentIndex];

    // 5. Ring multiplier determination (inclusive of inner wire boundaries)
    final int multiplier;
    final String label;
    final bool isTreble;
    final bool isDouble;

    if (r >= DartsK.doubleInR && r <= DartsK.doubleOutR) {
      multiplier = 2;
      label = 'D$segment';
      isTreble = false;
      isDouble = true;
    } else if (r >= DartsK.trebleInR && r <= DartsK.trebleOutR) {
      multiplier = 3;
      label = 'T$segment';
      isTreble = true;
      isDouble = false;
    } else {
      multiplier = 1;
      label = 'S$segment';
      isTreble = false;
      isDouble = false;
    }

    return DartHit(
      x: x,
      y: y,
      segment: segment,
      multiplier: multiplier,
      points: segment * multiplier,
      label: label,
      isTreble: isTreble,
      isBull: false,
      isDouble: isDouble,
      isInnerBull: false,
      isMiss: false,
      r: r,
      angleDeg: deg,
    );
  }

  /// Calculates the clockwise angle in degrees [0, 360) from 12 o'clock.
  static double calcAngleDeg(double x, double y) {
    double deg = math.atan2(x, y) * 180.0 / math.pi;
    if (deg < 0.0) deg += 360.0;
    if (deg >= 360.0) deg -= 360.0;
    return deg;
  }

  /// Returns the nominal center point in millimeters for a given [segment] and [multiplier].
  ///
  /// - [multiplier] 3 → center of treble band ((99 + 107) / 2 = 103 mm).
  /// - [multiplier] 2 → center of double band ((162 + 170) / 2 = 166 mm).
  /// - [multiplier] 1 → outer fat single (default 135 mm).
  /// - [segment] 25 → (0, 0) for inner bull or 11 mm for outer bull.
  static ({double x, double y}) targetCoordinates({
    required int segment,
    int multiplier = 1,
    double? customR,
  }) {
    if (segment == 25) {
      if (multiplier == 2) return (x: 0.0, y: 0.0);
      return (x: 0.0, y: (DartsK.innerBullR + DartsK.outerBullR) / 2.0);
    }

    final double r = customR ??
        (multiplier == 3
            ? (DartsK.trebleInR + DartsK.trebleOutR) / 2.0
            : (multiplier == 2
                ? (DartsK.doubleInR + DartsK.doubleOutR) / 2.0
                : 135.0));

    final int index = DartsK.segmentOrder.indexOf(segment);
    if (index < 0) return (x: 0.0, y: 0.0);

    final double angleRad = index * (DartsK.segmentAngleDeg * math.pi / 180.0);
    return (x: r * math.sin(angleRad), y: r * math.cos(angleRad));
  }
}
