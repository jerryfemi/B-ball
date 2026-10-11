import 'package:flutter/material.dart';

import '../telemetry/shot_telemetry.dart';

/// Game modes supported by the basketball engine.
enum MatchGameMode {
  solo,
  passAndPlay1v1,
}

/// Phases within a turn-based 1v1 match cycle.
enum MatchTurnPhase {
  /// Active 60-second round where the current player shoots live.
  playingTurn,

  /// Spectating the opponent's recorded round trajectory before shooting.
  watchingOpponentReplay,

  /// Intermission between turns/rounds (shows stats & turn handoff).
  turnComplete,

  /// Final match conclusion displaying the Winner Podium.
  matchComplete,
}

/// State and recorded history for an individual match participant.
class PlayerMatchState {
  final String id;
  final String name;
  final Color accentColor;
  final List<int> roundScores;
  final List<RoundTelemetry> roundTelemetries;

  PlayerMatchState({
    required this.id,
    required this.name,
    required this.accentColor,
    List<int>? roundScores,
    List<RoundTelemetry>? roundTelemetries,
  })  : roundScores = roundScores ?? [],
        roundTelemetries = roundTelemetries ?? [];

  int get totalScore => roundScores.fold(0, (acc, s) => acc + s);

  RoundTelemetry? get latestTelemetry =>
      roundTelemetries.isNotEmpty ? roundTelemetries.last : null;
}

/// Orchestrates multi-round 1v1 turn progression and match telemetry.
class MatchSession {
  final MatchGameMode mode;
  final int totalRounds;
  int currentRoundIndex; // 0-indexed (0 = Round 1, 1 = Round 2)
  int activePlayerIndex; // 0 = Player 1 ("YOU"), 1 = Player 2 ("THEM")
  final PlayerMatchState player1;
  final PlayerMatchState player2;
  MatchTurnPhase phase;

  MatchSession({
    this.mode = MatchGameMode.passAndPlay1v1,
    this.totalRounds = 2,
    this.currentRoundIndex = 0,
    this.activePlayerIndex = 0,
    PlayerMatchState? player1,
    PlayerMatchState? player2,
    this.phase = MatchTurnPhase.playingTurn,
  })  : player1 = player1 ??
            PlayerMatchState(
              id: 'p1',
              name: 'You',
              accentColor: const Color(0xFF22C55E),
            ),
        player2 = player2 ??
            PlayerMatchState(
              id: 'p2',
              name: 'Them',
              accentColor: const Color(0xFF38BDF8),
            );

  int get currentRoundNumber => currentRoundIndex + 1;
  bool get isFinalRound => currentRoundNumber >= totalRounds;

  PlayerMatchState get activePlayer =>
      activePlayerIndex == 0 ? player1 : player2;

  PlayerMatchState get opponentPlayer =>
      activePlayerIndex == 0 ? player2 : player1;

  /// Returns the winning player, or null if the match is tied.
  PlayerMatchState? get overallWinner {
    if (player1.totalScore > player2.totalScore) return player1;
    if (player2.totalScore > player1.totalScore) return player2;
    return null;
  }

  bool get isTie => player1.totalScore == player2.totalScore;
}
