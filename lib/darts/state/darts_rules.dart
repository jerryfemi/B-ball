import '../darts_constants.dart';

/// Immutable result of applying a single dart throw to a player's turn.
class DartTurnResult {
  /// Total turn score accumulated so far in this turn.
  /// If [bust] is true, this is 0.
  final int newTurnTotal;

  /// True if the dart took the player's remaining score below 0.
  /// When true, the turn scores 0 and resets to the turn-start remaining score.
  final bool bust;

  /// True if the dart reduced remaining score to exactly 0.
  final bool checkout;

  /// True if the turn is over (either via bust, checkout, or 3 darts thrown).
  final bool turnOver;

  /// Remaining match score after this dart is applied.
  final int remainingAfter;

  /// Number of darts thrown in this turn including this dart (1, 2, or 3).
  final int dartsUsed;

  const DartTurnResult({
    required this.newTurnTotal,
    required this.bust,
    required this.checkout,
    required this.turnOver,
    required this.remainingAfter,
    required this.dartsUsed,
  });

  @override
  String toString() =>
      'DartTurnResult(turnTotal: $newTurnTotal, remaining: $remainingAfter, '
      'bust: $bust, checkout: $checkout, turnOver: $turnOver, dartsUsed: $dartsUsed)';
}

/// Match rules shared by solo play, online play, and the Firestore turn transaction.
///
/// Follows GamePigeon Darts 301 rules:
/// - 301 starting score, straight in, straight out (no double needed to finish)
/// - 3 darts per turn
/// - Bust: dropping below 0 resets turn score to 0 and ends turn immediately
/// - Checkout: landing on exactly 0 ends turn immediately
/// - Equal turns: P1 always throws first; if P1 finishes, P2 still throws that round
/// - Round cap: 20 rounds max; tiebreaker is fewest darts used in checkout turn,
///   then lower remaining score, then draw.
///
/// Pure Dart (no Flutter/Flame imports).
abstract final class DartsRules {
  static const int startScore = DartsK.startScore;
  static const int dartsPerTurn = DartsK.dartsPerTurn;
  static const int maxRounds = DartsK.maxRounds;
  static const int shotClockSeconds = DartsK.shotClockSeconds;
  static const int onlineTurnSeconds = DartsK.onlineTurnSeconds;

  /// Calculates remaining points given a list of completed turn scores.
  static int remaining(List<int> turnScores) {
    final int total = turnScores.fold(0, (sum, score) => sum + score);
    return (startScore - total).clamp(0, startScore);
  }

  /// Evaluates a single dart throw against the current turn state.
  ///
  /// - [remainingAtTurnStart]: points remaining before this turn began (e.g. 301).
  /// - [turnSoFar]: points scored on earlier darts in this turn (0, 1, or 2 darts).
  /// - [points]: points scored on this dart.
  static DartTurnResult applyDart(
    int remainingAtTurnStart,
    List<int> turnSoFar,
    int points,
  ) {
    final int dartsUsed = turnSoFar.length + 1;
    final int previousTurnTotal = turnSoFar.fold(0, (s, p) => s + p);
    final int tentativeTurnTotal = previousTurnTotal + points;
    final int tentativeRemaining = remainingAtTurnStart - tentativeTurnTotal;

    // Case 1: Bust (score drops below 0)
    if (tentativeRemaining < 0) {
      return DartTurnResult(
        newTurnTotal: 0,
        bust: true,
        checkout: false,
        turnOver: true,
        remainingAfter: remainingAtTurnStart,
        dartsUsed: dartsUsed,
      );
    }

    // Case 2: Checkout (score reaches exactly 0)
    if (tentativeRemaining == 0) {
      return DartTurnResult(
        newTurnTotal: tentativeTurnTotal,
        bust: false,
        checkout: true,
        turnOver: true,
        remainingAfter: 0,
        dartsUsed: dartsUsed,
      );
    }

    // Case 3: Valid dart with remaining > 0
    final bool turnOver = dartsUsed >= dartsPerTurn;
    return DartTurnResult(
      newTurnTotal: tentativeTurnTotal,
      bust: false,
      checkout: false,
      turnOver: turnOver,
      remainingAfter: tentativeRemaining,
      dartsUsed: dartsUsed,
    );
  }

  /// True if the match has concluded.
  ///
  /// Under equal turns rule:
  /// - Both players must have thrown in the round ([p1Turns.length == p2Turns.length])
  ///   before evaluating match completion.
  /// - Match ends if either player reaches 0 or round 20 completes.
  static bool isMatchOver(
    List<int> p1Turns,
    List<int> p2Turns, {
    int p1LastDarts = 3,
    int p2LastDarts = 3,
  }) {
    // Round in progress: P1 threw, waiting for P2 to finish equal turns.
    if (p1Turns.length != p2Turns.length) return false;

    final int r1 = remaining(p1Turns);
    final int r2 = remaining(p2Turns);

    if (r1 == 0 || r2 == 0) return true;
    if (p1Turns.length >= maxRounds) return true;

    return false;
  }

  /// Determines the match winner once [isMatchOver] is true:
  /// - `+1`: Player 1 (you / host) wins
  /// - `-1`: Player 2 (opponent / bot) wins
  /// - `0`: Draw
  ///
  /// Tiebreak order:
  /// 1. Checkout vs non-checkout.
  /// 2. If both checkout in the same round: fewer darts used in checkout turn wins.
  /// 3. If round 20 cap reached: lower remaining score wins.
  /// 4. Otherwise: Draw (0).
  static int winner(
    List<int> p1Turns,
    List<int> p2Turns, {
    int p1LastDarts = 3,
    int p2LastDarts = 3,
  }) {
    final int r1 = remaining(p1Turns);
    final int r2 = remaining(p2Turns);

    // One player checked out
    if (r1 == 0 && r2 != 0) return 1;
    if (r2 == 0 && r1 != 0) return -1;

    // Both players checked out in the same round
    if (r1 == 0 && r2 == 0) {
      if (p1LastDarts < p2LastDarts) return 1;
      if (p2LastDarts < p1LastDarts) return -1;
      return 0; // Equal darts used in checkout turn
    }

    // Round cap reached: lower remaining total wins
    if (r1 < r2) return 1;
    if (r2 < r1) return -1;

    return 0; // Equal remaining totals
  }

  /// Deterministic per-match seed from the match ID.
  ///
  /// Copied from ArcheryRules: small multipliers only, exact in JS numbers
  /// on Flutter Web, so all platforms compute the identical seed.
  static int seedFromMatchId(String matchId) {
    int h = 17;
    for (final int c in matchId.trim().toUpperCase().codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h == 0 ? 1 : h;
  }
}
