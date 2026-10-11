import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b_ball/game/match/match_session.dart';
import 'package:b_ball/game/telemetry/shot_telemetry.dart';

void main() {
  group('MatchConfig tests', () {
    test('Default configuration values', () {
      const config = MatchConfig();
      expect(config.totalRounds, 2);
      expect(config.roundDurationSeconds, 60);
      expect(config.player1Name, 'You');
      expect(config.player2Name, 'Them');
      expect(config.player1Avatar, '🏀');
      expect(config.player2Avatar, '🎯');
    });

    test('copyWith works as expected', () {
      const config = MatchConfig();
      final updated = config.copyWith(
        totalRounds: 3,
        player1Name: 'Alex',
        player2Name: 'Sam',
        roundDurationSeconds: 30,
      );
      expect(updated.totalRounds, 3);
      expect(updated.roundDurationSeconds, 30);
      expect(updated.player1Name, 'Alex');
      expect(updated.player2Name, 'Sam');
      expect(updated.player1Avatar, '🏀');
    });
  });

  group('MatchSession Multi-Round tests', () {
    test('Configured with 3 rounds', () {
      const config = MatchConfig(
        totalRounds: 3,
        player1Name: 'Jordan',
        player2Name: 'Kobe',
        player1Avatar: '👑',
        player2Avatar: '⚡',
      );
      final session = MatchSession(config: config);

      expect(session.totalRounds, 3);
      expect(session.currentRoundNumber, 1);
      expect(session.isFinalRound, false);
      expect(session.player1.name, 'Jordan');
      expect(session.player2.name, 'Kobe');
      expect(session.player1.avatar, '👑');
      expect(session.player2.avatar, '⚡');

      // Round 2
      session.currentRoundIndex = 1;
      expect(session.currentRoundNumber, 2);
      expect(session.isFinalRound, false);

      // Round 3
      session.currentRoundIndex = 2;
      expect(session.currentRoundNumber, 3);
      expect(session.isFinalRound, true);
    });

    test('Configured with 4 rounds and victory calculation', () {
      const config = MatchConfig(totalRounds: 4);
      final session = MatchSession(config: config);

      session.player1.roundScores.addAll([12, 15, 18, 20]); // total = 65
      session.player2.roundScores.addAll([10, 14, 15, 16]); // total = 55

      expect(session.player1.totalScore, 65);
      expect(session.player2.totalScore, 55);
      expect(session.overallWinner, session.player1);
      expect(session.isTie, false);
    });

    test('Tie detection across match', () {
      final session = MatchSession(config: const MatchConfig(totalRounds: 2));
      session.player1.roundScores.addAll([20, 25]); // 45
      session.player2.roundScores.addAll([22, 23]); // 45

      expect(session.isTie, true);
      expect(session.overallWinner, isNull);
    });

    test('PlayerMatchState analytics calculations', () {
      final player = PlayerMatchState(
        id: 'p1',
        name: 'Player',
        accentColor: const Color(0xFF22C55E),
      );

      final shotsRound1 = [
        RecordedShot(
          timestampMs: 1000,
          startX: 0,
          startY: 0,
          startZ: 0,
          vx: 0,
          vy: 0,
          vz: 0,
          backspin: 14,
          isMake: true,
          isSwish: true,
          points: 2,
        ),
        RecordedShot(
          timestampMs: 2000,
          startX: 0,
          startY: 0,
          startZ: 0,
          vx: 0,
          vy: 0,
          vz: 0,
          backspin: 14,
          isMake: false,
        ),
      ];

      final shotsRound2 = [
        RecordedShot(
          timestampMs: 1000,
          startX: 0,
          startY: 0,
          startZ: 0,
          vx: 0,
          vy: 0,
          vz: 0,
          backspin: 14,
          isMake: true,
          isSwish: false,
          points: 2,
        ),
        RecordedShot(
          timestampMs: 2000,
          startX: 0,
          startY: 0,
          startZ: 0,
          vx: 0,
          vy: 0,
          vz: 0,
          backspin: 14,
          isMake: true,
          isSwish: true,
          points: 3,
        ),
      ];

      player.roundTelemetries.add(RoundTelemetry(
        roundScore: 2,
        madeShots: 1,
        totalShots: 2,
        shots: shotsRound1,
      ));
      player.roundTelemetries.add(RoundTelemetry(
        roundScore: 5,
        madeShots: 2,
        totalShots: 2,
        shots: shotsRound2,
      ));

      expect(player.totalMadeShots, 3);
      expect(player.totalAttemptedShots, 4);
      expect(player.overallAccuracy, 75.0);
      expect(player.totalSwishes, 2);
      expect(player.bestStreakAcrossMatch, 2);
    });
  });
}
