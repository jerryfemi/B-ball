import 'package:flutter/foundation.dart';
import '../camera/camera_rig.dart';
import '../physics/target_scoring.dart';
import 'archery_rules.dart';

/// Who is shooting the current set.
enum ArcheryShooter { you, opponent }

/// What the live status pill shows in online play.
enum ArcheryLiveStatus {
  /// Solo, or nothing to say.
  none,

  /// Online room created, nobody has joined yet (you may shoot set 1).
  waitingToJoin,

  /// Your turn: shot clock running.
  yourShot,

  /// Sending your finished set.
  submitting,

  /// Opponent's turn, waiting for their next arrow.
  waitingForShot,

  /// Opponent pressed to aim.
  opponentDrawing,

  /// Nothing heard from the opponent for a while.
  reconnecting,

  /// Opponent went quiet long enough to claim the win.
  opponentGone,
}

/// Immutable archery match state: the single source of truth for scores and
/// sets, in solo (vs bot) and online play. The Flame game only reports shots.
@immutable
class ArcheryMatchState {
  static const int arrowsPerSet = ArcheryRules.arrowsPerSet;

  final ShotPhase phase;
  final int setIndex;

  /// Your arrows in the current set.
  final List<ShotScore> setShots;

  /// The opponent's (bot's or player's) arrows in the current set.
  final List<ShotScore> opponentShots;

  /// Set totals of every finished set (same length for both archers).
  final List<int> userSetTotals;
  final List<int> opponentSetTotals;

  final double windDisplay;

  /// True from the moment a set's result is in until the next set starts.
  final bool setOver;
  final bool matchOver;
  final int matchSeed;

  // ── Online ──
  final bool online;
  final ArcheryShooter shooter;
  final ArcheryLiveStatus liveStatus;
  final String joinCode;

  /// Bumped whenever a new turn starts, to replay the turn banner.
  final int bannerId;

  /// Set when the match ended by forfeit: +1 you won, −1 they won.
  final int? forfeitWinner;

  const ArcheryMatchState({
    required this.phase,
    required this.setIndex,
    required this.setShots,
    required this.opponentShots,
    required this.userSetTotals,
    required this.opponentSetTotals,
    required this.windDisplay,
    required this.setOver,
    required this.matchOver,
    required this.matchSeed,
    this.online = false,
    this.shooter = ArcheryShooter.you,
    this.liveStatus = ArcheryLiveStatus.none,
    this.joinCode = '',
    this.bannerId = 0,
    this.forfeitWinner,
  });

  factory ArcheryMatchState.initial({required int seed}) => ArcheryMatchState(
        phase: ShotPhase.atLine,
        setIndex: 0,
        setShots: const [],
        opponentShots: const [],
        userSetTotals: const [],
        opponentSetTotals: const [],
        windDisplay: 0.0,
        setOver: false,
        matchOver: false,
        matchSeed: seed,
      );

  int get userSetScore => setShots.fold(0, (sum, s) => sum + s.points);
  int get opponentSetScore => opponentShots.fold(0, (sum, s) => sum + s.points);

  int get userPoints => ArcheryRules.setPoints(userSetTotals, opponentSetTotals).you;
  int get opponentPoints =>
      ArcheryRules.setPoints(userSetTotals, opponentSetTotals).them;

  /// +1 you won, −1 they won, 0 draw; null while the match is running.
  int? get winner {
    if (!matchOver) return null;
    return forfeitWinner ?? ArcheryRules.winner(userSetTotals, opponentSetTotals);
  }

  /// Arrows already shot in the current set by whoever is shooting
  /// (also the index of their next arrow).
  int get arrowIndex => (online && shooter == ArcheryShooter.opponent)
      ? opponentShots.length
      : setShots.length;

  bool get isMyTurn => !online || shooter == ArcheryShooter.you;

  ArcheryMatchState copyWith({
    ShotPhase? phase,
    int? setIndex,
    List<ShotScore>? setShots,
    List<ShotScore>? opponentShots,
    List<int>? userSetTotals,
    List<int>? opponentSetTotals,
    double? windDisplay,
    bool? setOver,
    bool? matchOver,
    int? matchSeed,
    bool? online,
    ArcheryShooter? shooter,
    ArcheryLiveStatus? liveStatus,
    String? joinCode,
    int? bannerId,
    int? forfeitWinner,
  }) {
    return ArcheryMatchState(
      phase: phase ?? this.phase,
      setIndex: setIndex ?? this.setIndex,
      setShots: setShots ?? this.setShots,
      opponentShots: opponentShots ?? this.opponentShots,
      userSetTotals: userSetTotals ?? this.userSetTotals,
      opponentSetTotals: opponentSetTotals ?? this.opponentSetTotals,
      windDisplay: windDisplay ?? this.windDisplay,
      setOver: setOver ?? this.setOver,
      matchOver: matchOver ?? this.matchOver,
      matchSeed: matchSeed ?? this.matchSeed,
      online: online ?? this.online,
      shooter: shooter ?? this.shooter,
      liveStatus: liveStatus ?? this.liveStatus,
      joinCode: joinCode ?? this.joinCode,
      bannerId: bannerId ?? this.bannerId,
      forfeitWinner: forfeitWinner ?? this.forfeitWinner,
    );
  }
}
