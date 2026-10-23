import 'dart:math' as math;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import 'darts_bot.dart';
import 'darts_match_state.dart';
import 'darts_rules.dart';

/// Events and state access required by the Flame game and UI layers.
abstract interface class DartsGameEvents {
  /// Base match seed for deterministic physics / bot.
  int get matchSeed;

  /// Current 1-based round index (1..20).
  int get round;

  /// Dart index within the current turn (0, 1, or 2).
  int get dartIndex;

  /// True if it is currently your turn to throw.
  bool get isMyTurn;

  /// Reports a landed dart for the current thrower.
  /// Evaluates bust, checkout, and turn over, updating match state.
  DartTurnResult dartLanded(DartHit hit);

  /// Generates and executes the bot's next dart for this turn in solo play.
  /// Returns the landed [DartHit], or null if the bot's turn is already over.
  DartHit? botNextDart();

  /// Advances to the next turn or clears turn-over state.
  void nextTurn();

  /// Resets the match to round 1 with a new random seed.
  void restartMatch();
}

/// Riverpod notifier that owns match scoring rules, turn flow, and state.
class DartsMatchNotifier extends Notifier<DartsMatchState>
    implements DartsGameEvents {
  @override
  DartsMatchState build() => DartsMatchState.initial(seed: _newSeed());

  static int _newSeed() => math.Random().nextInt(1 << 30) + 1;

  @override
  int get matchSeed => state.matchSeed;

  @override
  int get round => state.round;

  @override
  int get dartIndex => state.dartIndex;

  @override
  bool get isMyTurn => state.isMyTurn;

  @override
  DartTurnResult dartLanded(DartHit hit) {
    if (state.matchOver) {
      return const DartTurnResult(
        newTurnTotal: 0,
        bust: false,
        checkout: false,
        turnOver: true,
        remainingAfter: 0,
        dartsUsed: 0,
      );
    }

    final bool isYou = state.thrower == DartsThrower.you;
    final int turnStartRem = isYou ? state.yourRemaining : state.theirRemaining;
    final List<int> turnSoFar = state.turnDarts.map((d) => d.points).toList();

    final DartTurnResult res = DartsRules.applyDart(
      turnStartRem,
      turnSoFar,
      hit.points,
    );

    final List<DartHit> newTurnDarts = [...state.turnDarts, hit];

    if (res.bust) {
      // Bust: turn scores 0, ends turn immediately
      if (isYou) {
        state = state.copyWith(
          yourTurns: [...state.yourTurns, 0],
          yourLastDarts: res.dartsUsed,
          turnDarts: const [],
          thrower: DartsThrower.opponent,
          bustFlash: state.bustFlash + 1,
          turnOver: true,
          bannerId: state.bannerId + 1,
        );
      } else {
        final List<int> newTheirTurns = [...state.theirTurns, 0];
        _finalizeRoundAfterOpponent(
          newTheirTurns: newTheirTurns,
          theirLastDarts: res.dartsUsed,
          bust: true,
        );
      }
      return res;
    }

    if (res.checkout) {
      // Checkout: reaches exactly 0, ends turn immediately
      if (isYou) {
        state = state.copyWith(
          yourTurns: [...state.yourTurns, res.newTurnTotal],
          yourLastDarts: res.dartsUsed,
          turnDarts: const [],
          thrower: DartsThrower.opponent,
          turnOver: true,
          bannerId: state.bannerId + 1,
        );
      } else {
        final List<int> newTheirTurns = [...state.theirTurns, res.newTurnTotal];
        _finalizeRoundAfterOpponent(
          newTheirTurns: newTheirTurns,
          theirLastDarts: res.dartsUsed,
          bust: false,
        );
      }
      return res;
    }

    if (res.turnOver) {
      // 3rd dart thrown: turn complete
      if (isYou) {
        state = state.copyWith(
          yourTurns: [...state.yourTurns, res.newTurnTotal],
          yourLastDarts: res.dartsUsed,
          turnDarts: const [],
          thrower: DartsThrower.opponent,
          turnOver: true,
          bannerId: state.bannerId + 1,
        );
      } else {
        final List<int> newTheirTurns = [...state.theirTurns, res.newTurnTotal];
        _finalizeRoundAfterOpponent(
          newTheirTurns: newTheirTurns,
          theirLastDarts: res.dartsUsed,
          bust: false,
        );
      }
      return res;
    }

    // Turn still active (dart 1 or 2, neither bust nor checkout)
    state = state.copyWith(
      turnDarts: newTurnDarts,
      turnOver: false,
    );
    return res;
  }

  /// Evaluates round completion after Player 2 (opponent / bot) finishes a turn.
  void _finalizeRoundAfterOpponent({
    required List<int> newTheirTurns,
    required int theirLastDarts,
    required bool bust,
  }) {
    final bool over = DartsRules.isMatchOver(
      state.yourTurns,
      newTheirTurns,
      p1LastDarts: state.yourLastDarts,
      p2LastDarts: theirLastDarts,
    );

    if (over) {
      state = state.copyWith(
        theirTurns: newTheirTurns,
        theirLastDarts: theirLastDarts,
        turnDarts: const [],
        bustFlash: bust ? state.bustFlash + 1 : state.bustFlash,
        turnOver: true,
        matchOver: true,
      );
    } else {
      state = state.copyWith(
        round: state.round + 1,
        thrower: DartsThrower.you,
        theirTurns: newTheirTurns,
        theirLastDarts: theirLastDarts,
        turnDarts: const [],
        bustFlash: bust ? state.bustFlash + 1 : state.bustFlash,
        turnOver: false,
        bannerId: state.bannerId + 1,
      );
    }
  }

  @override
  DartHit? botNextDart() {
    if (state.online || state.matchOver) return null;
    if (state.thrower != DartsThrower.opponent) return null;

    final int dIndex = state.turnDarts.length;
    if (dIndex >= DartsK.dartsPerTurn) return null;

    final int startRem = state.theirRemaining;
    final int turnSum = state.turnDarts.fold(0, (s, d) => s + d.points);
    final int curRem = startRem - turnSum;

    final DartHit hit = DartsBot.dart(
      state.matchSeed,
      state.round,
      dIndex,
      curRem,
    );

    dartLanded(hit);
    return hit;
  }

  @override
  void nextTurn() {
    if (state.matchOver || state.online) return;
    if (state.turnOver) {
      state = state.copyWith(turnOver: false);
    }
  }

  @override
  void restartMatch() {
    state = DartsMatchState.initial(seed: _newSeed());
  }

  // ── Online Play ──────────────────────────────────────────────────────────

  /// Switches to an online match using the match seed and room code.
  void startOnline({required int seed, required String joinCode}) {
    state = DartsMatchState.initial(seed: seed).copyWith(
      online: true,
      joinCode: joinCode,
    );
  }

  /// Sets up state for a specific online turn from Firestore match snapshot.
  void beginOnlineTurn({
    required int round,
    required DartsThrower thrower,
    required List<DartHit> turnDarts,
    required List<int> yourTurns,
    required List<int> theirTurns,
  }) {
    state = state.copyWith(
      round: round,
      thrower: thrower,
      turnDarts: turnDarts,
      yourTurns: yourTurns,
      theirTurns: theirTurns,
      turnOver: false,
      bannerId: state.bannerId + 1,
    );
  }

  /// Both players finished the round in online play.
  void showOnlineRoundResult({
    required List<int> yourTurns,
    required List<int> theirTurns,
    required bool matchOver,
  }) {
    state = state.copyWith(
      yourTurns: yourTurns,
      theirTurns: theirTurns,
      turnOver: true,
      matchOver: matchOver,
      liveStatus: DartsLiveStatus.none,
    );
  }

  /// Match ended by forfeit (+1 you won, -1 opponent won).
  void endOnlineByForfeit(int winner) {
    state = state.copyWith(
      turnOver: true,
      matchOver: true,
      forfeitWinner: winner,
      liveStatus: DartsLiveStatus.none,
    );
  }

  /// Updates the live status pill during online play.
  void setLiveStatus(DartsLiveStatus status) {
    if (state.liveStatus == status) return;
    state = state.copyWith(liveStatus: status);
  }
}

final dartsMatchProvider =
    NotifierProvider<DartsMatchNotifier, DartsMatchState>(
  DartsMatchNotifier.new,
);
