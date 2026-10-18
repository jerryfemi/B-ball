import 'package:flutter/material.dart';

import '../../models/cloud_match.dart';
import '../../models/player_descriptor.dart';
import '../telemetry/shot_telemetry.dart';
import 'match_config.dart';

export 'match_config.dart';

/// Game modes supported by the basketball engine.
enum MatchGameMode { solo, passAndPlay1v1, onlineCloud1v1 }

/// Phases within a turn-based 1v1 match cycle.
enum MatchTurnPhase {
  /// Active round where the current player shoots live.
  playingTurn,

  /// Spectating the opponent's recorded round trajectory before shooting.
  watchingOpponentReplay,

  /// Spectating the opponent shooting in real time via live ghost telemetry.
  watchingLiveOpponent,

  /// Intermission between turns/rounds (shows stats & turn handoff).
  turnComplete,

  /// Waiting for opponent to submit their round in an asynchronous match.
  waitingForOpponentTurn,

  /// Final match conclusion displaying the Winner Podium.
  matchComplete,
}

/// State and recorded history for an individual match participant.
class PlayerMatchState implements PlayerDescriptor {
  @override
  final String id;
  final String name;
  @override
  final String avatar;
  final Color accentColor;
  final List<int> roundScores;
  final List<RoundTelemetry> roundTelemetries;

  /// Compact per-round stats saved in the cloud match (made/attempted shots,
  /// swishes, best streak). Full shot telemetry only exists locally for the
  /// rounds this device recorded, so the opponent's (and any history view's)
  /// podium stats come from these instead.
  final List<RoundSummaryStats> roundSummaries;

  @override
  String get displayName => name;

  PlayerMatchState({
    required this.id,
    required this.name,
    this.avatar = PlayerDescriptor.defaultAvatar,
    required this.accentColor,
    List<int>? roundScores,
    List<RoundTelemetry>? roundTelemetries,
    List<RoundSummaryStats>? roundSummaries,
  }) : roundScores = roundScores ?? [],
       roundTelemetries = roundTelemetries ?? [],
       roundSummaries = roundSummaries ?? [];

  PlayerMatchState copyWith({
    String? id,
    String? name,
    String? avatar,
    Color? accentColor,
    List<int>? roundScores,
    List<RoundTelemetry>? roundTelemetries,
    List<RoundSummaryStats>? roundSummaries,
  }) {
    return PlayerMatchState(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      accentColor: accentColor ?? this.accentColor,
      roundScores: roundScores ?? this.roundScores,
      roundTelemetries: roundTelemetries ?? this.roundTelemetries,
      roundSummaries: roundSummaries ?? this.roundSummaries,
    );
  }

  int get totalScore => roundScores.fold(0, (acc, s) => acc + s);

  /// Prefer the cloud summaries whenever they cover more rounds than the
  /// locally recorded telemetry (always true for the opponent and for
  /// matches reopened from history).
  bool get _useSummaries => roundSummaries.length > roundTelemetries.length;

  /// Total successful shots made across all played rounds.
  int get totalMadeShots => _useSummaries
      ? roundSummaries.fold(0, (acc, s) => acc + s.madeShots)
      : roundTelemetries.fold(0, (acc, t) => acc + t.madeShots);

  /// Total shot attempts taken across all played rounds.
  int get totalAttemptedShots => _useSummaries
      ? roundSummaries.fold(0, (acc, s) => acc + s.totalShots)
      : roundTelemetries.fold(0, (acc, t) => acc + t.totalShots);

  /// Overall match shooting accuracy percentage (0.0 to 100.0).
  double get overallAccuracy => totalAttemptedShots > 0
      ? (totalMadeShots / totalAttemptedShots * 100.0)
      : 0.0;

  /// Total clean swishes scored across all played rounds.
  int get totalSwishes => _useSummaries
      ? roundSummaries.fold(0, (acc, s) => acc + s.swishes)
      : roundTelemetries.fold(
          0,
          (acc, t) => acc + t.shots.where((s) => s.isSwish).length,
        );

  /// Longest consecutive shot streak achieved during any round in the match.
  int get bestStreakAcrossMatch => _useSummaries
      ? roundSummaries.fold(
          0,
          (acc, s) => s.bestStreak > acc ? s.bestStreak : acc,
        )
      : roundTelemetries.fold(0, (acc, t) {
    int streak = 0;
    int maxS = 0;
    for (final s in t.shots) {
      if (s.isMake) {
        streak++;
        if (streak > maxS) maxS = streak;
      } else {
        streak = 0;
      }
    }
    return maxS > acc ? maxS : acc;
  });

  /// Returns aggregate score accumulated strictly before [roundIndex].
  int scoreUpToRound(int roundIndex) {
    int total = 0;
    for (int i = 0; i < roundIndex && i < roundScores.length; i++) {
      total += roundScores[i];
    }
    return total;
  }

  RoundTelemetry? get latestTelemetry =>
      roundTelemetries.isNotEmpty ? roundTelemetries.last : null;
}

/// Orchestrates multi-round 1v1 turn progression and match telemetry.
class MatchSession {
  final MatchGameMode mode;
  MatchConfig config;
  final int totalRounds;
  final String? cloudMatchId;
  final String? joinCode;
  bool isWaitingForOpponent;
  int currentRoundIndex; // 0-indexed (0 = Round 1, 1 = Round 2)
  int activePlayerIndex; // 0 = Player 1 ("YOU"), 1 = Player 2 ("THEM")
  PlayerMatchState player1;
  PlayerMatchState player2;
  MatchTurnPhase phase;
  final bool isHost;
  PlayerMatchState? forfeitWinner;

  /// True when the podium was reopened from the inbox's COMPLETED history:
  /// the match is long over, so no rematch/"waiting" actions are offered.
  bool isHistoryView = false;

  bool get isForfeit => forfeitWinner != null;

  /// Online matches always seat this device's player as [player1].
  bool get isOnline => cloudMatchId != null;

  /// Name to show for [p] on this device: "YOU" for me in online matches,
  /// otherwise the player's gamer tag.
  String displayNameFor(PlayerMatchState p) =>
      (isOnline && identical(p, player1)) ? 'YOU' : p.name;

  MatchSession({
    this.mode = MatchGameMode.passAndPlay1v1,
    this.cloudMatchId,
    this.joinCode,
    this.isWaitingForOpponent = false,
    this.isHost = true,
    MatchConfig? config,
    int? totalRounds,
    this.currentRoundIndex = 0,
    this.activePlayerIndex = 0,
    PlayerMatchState? player1,
    PlayerMatchState? player2,
    this.phase = MatchTurnPhase.playingTurn,
    this.forfeitWinner,
  }) : config = config ?? const MatchConfig(),
       totalRounds = totalRounds ?? (config?.totalRounds ?? 2),
       player1 =
           player1 ??
           PlayerMatchState(
             id: 'p1',
             name: (config?.player1Name.isNotEmpty ?? false)
                 ? config!.player1Name
                 : 'You',
             avatar:
                 config?.player1Avatar ?? PlayerDescriptor.defaultAvatar,
             accentColor: const Color(0xFF22C55E),
           ),
       player2 =
           player2 ??
           PlayerMatchState(
             id: 'p2',
             name: (config?.player2Name.isNotEmpty ?? false)
                 ? config!.player2Name
                 : 'Them',
             avatar:
                 config?.player2Avatar ?? 'assets/avatars/dunk_heads (2).webp',
             accentColor: const Color(0xFF38BDF8),
           );

  /// Constructs an active [MatchSession] from a synced [CloudMatch].
  factory MatchSession.fromCloudMatch(CloudMatch cloudMatch, String myUid) {
    final isP1 = cloudMatch.player1.uid == myUid;
    final myPlayer = isP1
        ? cloudMatch.player1
        : (cloudMatch.player2 ??
              const CloudPlayer(
                uid: '',
                displayName: 'You',
                avatarEmoji: PlayerDescriptor.defaultAvatar,
                roundScores: [],
              ));
    final oppPlayer = isP1
        ? (cloudMatch.player2 ??
              const CloudPlayer(
                uid: '',
                displayName: 'Opponent',
                avatarEmoji: 'assets/avatars/dunk_heads (2).webp',
                roundScores: [],
              ))
        : cloudMatch.player1;

    final hasOpponentTelemetry =
        cloudMatch.latestTelemetry != null &&
        cloudMatch.latestTelemetryShooterUid != myUid;

    final p1State = PlayerMatchState(
      id: myPlayer.uid.isNotEmpty ? myPlayer.uid : 'you',
      name: myPlayer.displayName,
      avatar: myPlayer.avatarEmoji,
      accentColor: const Color(0xFF00FFCC),
      roundScores: [...myPlayer.roundScores],
      roundSummaries: [...myPlayer.roundSummaries],
    );

    final p2State = PlayerMatchState(
      id: oppPlayer.uid.isNotEmpty ? oppPlayer.uid : 'them',
      name: oppPlayer.displayName,
      avatar: oppPlayer.avatarEmoji,
      accentColor: const Color(0xFF38BDF8),
      roundScores: [...oppPlayer.roundScores],
      roundSummaries: [...oppPlayer.roundSummaries],
      roundTelemetries: hasOpponentTelemetry
          ? [cloudMatch.latestTelemetry!]
          : [],
    );

    final isWaiting = isP1 && cloudMatch.player2 == null;
    final isMyTurn = cloudMatch.isMyTurn(myUid);

    // Restore an explicit winner (forfeits / abandoned-claims) so the podium
    // crowns the right player even when the score line says otherwise.
    PlayerMatchState? restoredWinner;
    final isDecidedByForfeit =
        cloudMatch.status == MatchStatus.forfeited ||
        (cloudMatch.customWinnerUid?.isNotEmpty ?? false);
    final storedWinnerUid = isDecidedByForfeit ? cloudMatch.winnerUid : null;
    if (storedWinnerUid != null && storedWinnerUid.isNotEmpty) {
      if (storedWinnerUid == p1State.id) {
        restoredWinner = p1State;
      } else if (storedWinnerUid == p2State.id) {
        restoredWinner = p2State;
      }
    }

    final MatchTurnPhase initialPhase;
    if (cloudMatch.isFinished) {
      initialPhase = MatchTurnPhase.matchComplete;
    } else if (isMyTurn) {
      if (hasOpponentTelemetry) {
        initialPhase = MatchTurnPhase.watchingOpponentReplay;
      } else {
        initialPhase = MatchTurnPhase.playingTurn;
      }
    } else {
      if (isWaiting) {
        initialPhase = MatchTurnPhase.waitingForOpponentTurn;
      } else {
        initialPhase = MatchTurnPhase.watchingLiveOpponent;
      }
    }

    return MatchSession(
      mode: MatchGameMode.onlineCloud1v1,
      cloudMatchId: cloudMatch.id,
      joinCode: cloudMatch.joinCode,
      isWaitingForOpponent: isWaiting,
      isHost: isP1,
      totalRounds: cloudMatch.totalRounds,
      currentRoundIndex: (cloudMatch.currentRound - 1).clamp(
        0,
        cloudMatch.totalRounds - 1,
      ),
      activePlayerIndex: isMyTurn ? 0 : 1,
      phase: initialPhase,
      player1: p1State,
      player2: p2State,
      forfeitWinner: restoredWinner,
      config: MatchConfig(
        totalRounds: cloudMatch.totalRounds,
        roundDurationSeconds: cloudMatch.roundDurationSeconds,
        difficulty: cloudMatch.difficulty,
        player1Name: myPlayer.displayName,
        player1Avatar: myPlayer.avatarEmoji,
        player2Name: oppPlayer.displayName,
        player2Avatar: oppPlayer.avatarEmoji,
      ),
    );
  }

  int get currentRoundNumber => currentRoundIndex + 1;
  bool get isFinalRound => currentRoundNumber >= totalRounds;

  PlayerMatchState get activePlayer =>
      activePlayerIndex == 0 ? player1 : player2;

  PlayerMatchState get opponentPlayer =>
      activePlayerIndex == 0 ? player2 : player1;

  /// Returns the winning player, or null if the match is tied.
  PlayerMatchState? get overallWinner {
    if (forfeitWinner != null) return forfeitWinner;
    if (player1.totalScore > player2.totalScore) return player1;
    if (player2.totalScore > player1.totalScore) return player2;
    return null;
  }

  bool get isTie =>
      forfeitWinner == null && player1.totalScore == player2.totalScore;
}
