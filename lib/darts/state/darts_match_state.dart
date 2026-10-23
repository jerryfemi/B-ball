import 'package:flutter/foundation.dart';
import '../darts_constants.dart';
import '../physics/dart_scoring.dart';
import 'darts_rules.dart';

/// Who is throwing the current turn.
enum DartsThrower { you, opponent }

/// What the live status pill shows in online play.
enum DartsLiveStatus {
  /// Solo, or nothing to say.
  none,

  /// Online room created, waiting for opponent to join.
  waitingToJoin,

  /// Your turn: shot clock running.
  yourShot,

  /// Submitting your finished turn score to Firestore.
  submitting,

  /// Opponent's turn, waiting for their next dart.
  waitingForShot,

  /// Reconnecting / transient disconnection.
  reconnecting,

  /// Opponent disconnected long enough to claim forfeit win.
  opponentGone,
}

/// Immutable Darts 301 match state: the Single Source of Truth for scores,
/// rounds, and turns in solo (vs bot) and online play.
@immutable
class DartsMatchState {
  /// Current round number (1-indexed, 1..20).
  final int round;

  /// Current thrower whose turn it is.
  final DartsThrower thrower;

  /// Darts thrown so far in the current active turn (0, 1, 2, or 3).
  final List<DartHit> turnDarts;

  /// Finished turn totals for Player 1 (you / host).
  final List<int> yourTurns;

  /// Finished turn totals for Player 2 (opponent / bot / guest).
  final List<int> theirTurns;

  /// Number of darts used in Player 1's last completed turn (1, 2, or 3).
  final int yourLastDarts;

  /// Number of darts used in Player 2's last completed turn (1, 2, or 3).
  final int theirLastDarts;

  /// Incremented whenever a bust occurs to trigger the UI BUST flash animation.
  final int bustFlash;

  /// True when the current turn has completed (3 darts, bust, or checkout).
  final bool turnOver;

  /// True when the match has concluded.
  final bool matchOver;

  /// Base deterministic match seed.
  final int matchSeed;

  // ── Online Play Fields ───────────────────────────────────────────────────
  final bool online;
  final DartsLiveStatus liveStatus;
  final String joinCode;

  /// Bumped whenever a new turn starts, to replay the turn banner animation.
  final int bannerId;

  /// Set when the match ended by forfeit: +1 you won, -1 opponent won.
  final int? forfeitWinner;

  /// True when you open every round (solo, or player 1 / host online).
  /// Online, the guest (player 2) throws second.
  final bool youThrowFirst;

  const DartsMatchState({
    required this.round,
    required this.thrower,
    required this.turnDarts,
    required this.yourTurns,
    required this.theirTurns,
    required this.yourLastDarts,
    required this.theirLastDarts,
    required this.bustFlash,
    required this.turnOver,
    required this.matchOver,
    required this.matchSeed,
    this.online = false,
    this.liveStatus = DartsLiveStatus.none,
    this.joinCode = '',
    this.bannerId = 0,
    this.forfeitWinner,
    this.youThrowFirst = true,
  });

  factory DartsMatchState.initial({required int seed}) => DartsMatchState(
        round: 1,
        thrower: DartsThrower.you,
        turnDarts: const [],
        yourTurns: const [],
        theirTurns: const [],
        yourLastDarts: 3,
        theirLastDarts: 3,
        bustFlash: 0,
        turnOver: false,
        matchOver: false,
        matchSeed: seed,
        online: false,
        liveStatus: DartsLiveStatus.none,
        joinCode: '',
        bannerId: 0,
        forfeitWinner: null,
      );

  /// Points remaining for Player 1 (you) at the start of the current turn.
  int get yourRemaining => DartsRules.remaining(yourTurns);

  /// Points remaining for Player 2 (opponent) at the start of the current turn.
  int get theirRemaining => DartsRules.remaining(theirTurns);

  /// Running sum of points scored in the active turn.
  int get turnScore => turnDarts.fold(0, (sum, d) => sum + d.points);

  /// Points remaining for the active thrower before the current turn.
  int get turnStartRemaining =>
      thrower == DartsThrower.you ? yourRemaining : theirRemaining;

  /// Points remaining for the active thrower during the current turn.
  int get runningRemaining =>
      (turnStartRemaining - turnScore).clamp(0, DartsK.startScore);

  /// Index of the next dart to be thrown in this turn (0, 1, or 2).
  int get dartIndex => turnDarts.length;

  /// True if it is currently your turn to throw.
  bool get isMyTurn => thrower == DartsThrower.you;

  /// The player who throws second in every round (equal turns).
  DartsThrower get secondThrower =>
      youThrowFirst ? DartsThrower.opponent : DartsThrower.you;

  /// The second thrower is up and the first thrower has already checked
  /// out this round: they must check out too to tie.
  bool get isLastChance {
    if (thrower != secondThrower) return false;
    final int firstRemaining =
        thrower == DartsThrower.you ? theirRemaining : yourRemaining;
    return firstRemaining == 0;
  }

  /// +1 if Player 1 won, -1 if Player 2 won, 0 for draw; null while running.
  int? get winner {
    if (!matchOver) return null;
    return forfeitWinner ??
        DartsRules.winner(
          yourTurns,
          theirTurns,
          p1LastDarts: yourLastDarts,
          p2LastDarts: theirLastDarts,
        );
  }

  DartsMatchState copyWith({
    int? round,
    DartsThrower? thrower,
    List<DartHit>? turnDarts,
    List<int>? yourTurns,
    List<int>? theirTurns,
    int? yourLastDarts,
    int? theirLastDarts,
    int? bustFlash,
    bool? turnOver,
    bool? matchOver,
    int? matchSeed,
    bool? online,
    DartsLiveStatus? liveStatus,
    String? joinCode,
    int? bannerId,
    int? forfeitWinner,
    bool? youThrowFirst,
  }) {
    return DartsMatchState(
      round: round ?? this.round,
      thrower: thrower ?? this.thrower,
      turnDarts: turnDarts ?? this.turnDarts,
      yourTurns: yourTurns ?? this.yourTurns,
      theirTurns: theirTurns ?? this.theirTurns,
      yourLastDarts: yourLastDarts ?? this.yourLastDarts,
      theirLastDarts: theirLastDarts ?? this.theirLastDarts,
      bustFlash: bustFlash ?? this.bustFlash,
      turnOver: turnOver ?? this.turnOver,
      matchOver: matchOver ?? this.matchOver,
      matchSeed: matchSeed ?? this.matchSeed,
      online: online ?? this.online,
      liveStatus: liveStatus ?? this.liveStatus,
      joinCode: joinCode ?? this.joinCode,
      bannerId: bannerId ?? this.bannerId,
      forfeitWinner: forfeitWinner ?? this.forfeitWinner,
      youThrowFirst: youThrowFirst ?? this.youThrowFirst,
    );
  }
}
