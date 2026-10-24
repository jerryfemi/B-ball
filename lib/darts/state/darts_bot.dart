import 'dart:math' as math;
import '../darts_constants.dart';
import '../physics/dart_scoring.dart';

/// Immutable representation of the bot's calculated aiming target on the dartboard.
class BotAim {
  /// Horizontal aim coordinate in board millimeters (+right).
  final double x;

  /// Vertical aim coordinate in board millimeters (+up).
  final double y;

  /// Human-readable target label: e.g. `'T20'`, `'D16'`, `'S5'`, `'25'`, `'BULL'`.
  final String label;

  /// Total points this target is worth if hit exactly.
  final int points;

  /// Radial segment number (1–20, 25 for bull).
  final int segment;

  /// Ring multiplier (1 = single/outer bull, 2 = double/inner bull, 3 = treble).
  final int multiplier;

  const BotAim({
    required this.x,
    required this.y,
    required this.label,
    required this.points,
    required this.segment,
    required this.multiplier,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BotAim &&
        other.label == label &&
        other.points == points &&
        other.segment == segment &&
        other.multiplier == multiplier &&
        (other.x - x).abs() < 1e-4 &&
        (other.y - y).abs() < 1e-4;
  }

  @override
  int get hashCode => Object.hash(x, y, label, points, segment, multiplier);

  @override
  String toString() =>
      'BotAim($label: $points pts @ (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}) mm)';
}

/// Pure Dart bot opponent decision and seeded accuracy model.
///
/// Follows DARTS_PLAN.md §1.4:
/// - Remaining > 60: aim T20 (60 points).
/// - Remaining <= 60: pick the target that finishes exactly with best hit chance:
///   1. Fat single (1..20, r ≈ 135 mm)
///   2. Outer bull (25)
///   3. Double (2..40 even)
///   4. Treble (3..60 divisible by 3)
///   5. Inner bull (50)
/// - No 1-dart finish possible: aim the fat single leaving <= 40 (prefer <= 20).
/// - Accuracy: 2D Gaussian scatter with σ = [DartsK.botSigmaMm], seeded via Box–Muller transform
///   matching the Archery botShot pattern.
abstract final class DartsBot {
  /// Determines the optimal aiming target point given the player's [remaining] score.
  ///
  /// Guarantees that the intended target is never worth more than [remaining].
  static BotAim aimFor(int remaining) {
    if (remaining <= 0) {
      return const BotAim(
        x: 0.0,
        y: 0.0,
        label: 'BULL',
        points: 50,
        segment: 25,
        multiplier: 2,
      );
    }

    // 1. Above 60 points: always aim T20
    if (remaining > 60) {
      final coords = DartScoring.targetCoordinates(segment: 20, multiplier: 3);
      return BotAim(
        x: coords.x,
        y: coords.y,
        label: 'T20',
        points: 60,
        segment: 20,
        multiplier: 3,
      );
    }

    // 2. remaining <= 60: pick the target that finishes exactly with the best hit chance
    // Priority order: fat single (1..20) > outer bull (25) > double > treble > inner bull (50)

    // 2a. Fat single (1..20)
    if (remaining >= 1 && remaining <= 20) {
      final coords = DartScoring.targetCoordinates(segment: remaining, multiplier: 1);
      return BotAim(
        x: coords.x,
        y: coords.y,
        label: 'S$remaining',
        points: remaining,
        segment: remaining,
        multiplier: 1,
      );
    }

    // 2b. Outer bull (25)
    if (remaining == 25) {
      final coords = DartScoring.targetCoordinates(segment: 25, multiplier: 1);
      return BotAim(
        x: coords.x,
        y: coords.y,
        label: '25',
        points: 25,
        segment: 25,
        multiplier: 1,
      );
    }

    // 2c. Double (2..40 even)
    if (remaining <= 40 && remaining % 2 == 0) {
      final int seg = remaining ~/ 2;
      if (seg >= 1 && seg <= 20) {
        final coords = DartScoring.targetCoordinates(segment: seg, multiplier: 2);
        return BotAim(
          x: coords.x,
          y: coords.y,
          label: 'D$seg',
          points: remaining,
          segment: seg,
          multiplier: 2,
        );
      }
    }

    // 2d. Treble (3..60 divisible by 3)
    if (remaining <= 60 && remaining % 3 == 0) {
      final int seg = remaining ~/ 3;
      if (seg >= 1 && seg <= 20) {
        final coords = DartScoring.targetCoordinates(segment: seg, multiplier: 3);
        return BotAim(
          x: coords.x,
          y: coords.y,
          label: 'T$seg',
          points: remaining,
          segment: seg,
          multiplier: 3,
        );
      }
    }

    // 2e. Inner bull (50)
    if (remaining == 50) {
      final coords = DartScoring.targetCoordinates(segment: 25, multiplier: 2);
      return BotAim(
        x: coords.x,
        y: coords.y,
        label: 'BULL',
        points: 50,
        segment: 25,
        multiplier: 2,
      );
    }

    // 3. No finish possible this dart
    // Aim the fat single that leaves <= 40 (prefer <= 20); never aim a target > remaining.
    int bestSingle = -1;

    // Preference A: leaves <= 20 (and >= 1, guaranteeing single-finish chance on next dart)
    for (int s = 20; s >= 1; s--) {
      if (s < remaining && (remaining - s) <= 20) {
        bestSingle = s;
        break;
      }
    }

    // Preference B: leaves <= 40
    if (bestSingle == -1) {
      for (int s = 20; s >= 1; s--) {
        if (s < remaining && (remaining - s) <= 40) {
          bestSingle = s;
          break;
        }
      }
    }

    // Fallback: highest single < remaining
    if (bestSingle == -1) {
      for (int s = 20; s >= 1; s--) {
        if (s < remaining) {
          bestSingle = s;
          break;
        }
      }
    }

    final coords = DartScoring.targetCoordinates(segment: bestSingle, multiplier: 1);
    return BotAim(
      x: coords.x,
      y: coords.y,
      label: 'S$bestSingle',
      points: bestSingle,
      segment: bestSingle,
      multiplier: 1,
    );
  }

  /// Generates a deterministic simulated bot dart throw.
  ///
  /// - [seed]: Base match seed (e.g. from [DartsRules.seedFromMatchId]).
  /// - [round]: 1-based round index.
  /// - [dartIndex]: 0, 1, or 2 (dart number within this turn).
  /// - [remaining]: Current points remaining before this throw.
  ///
  /// Uses a Box–Muller 2D Gaussian scatter with σ = [DartsK.botSigmaMm].
  static DartHit dart(int seed, int round, int dartIndex, int remaining) {
    int h = seed;
    h = (h * 31 + round) & 0x7FFFFFFF;
    h = (h * 31 + dartIndex) & 0x7FFFFFFF;
    h = (h * 31 + 0xB07) & 0x7FFFFFFF;
    final rng = math.Random(h);

    // Box–Muller transform: Rayleigh radius from u1, angle from u2
    final double u1 = math.max(rng.nextDouble(), 1e-9);
    final double u2 = rng.nextDouble();
    final double r = DartsK.botSigmaMm * math.sqrt(-2.0 * math.log(u1));
    final double a = 2.0 * math.pi * u2;
    final double dx = r * math.cos(a);
    final double dy = r * math.sin(a);

    final BotAim aim = aimFor(remaining);
    return DartScoring.score(aim.x + dx, aim.y + dy);
  }
}
