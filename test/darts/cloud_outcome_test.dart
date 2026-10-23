import 'package:b_ball/models/cloud_match.dart';
import 'package:flutter_test/flutter_test.dart';

CloudMatch dartsMatch(CloudPlayer p1, CloudPlayer p2) => CloudMatch(
      id: 'D1',
      joinCode: 'D1',
      game: 'darts',
      status: MatchStatus.completed,
      createdAt: 0,
      updatedAt: 0,
      playerIds: [p1.uid, p2.uid],
      player1: p1,
      player2: p2,
      totalRounds: 20,
      roundDurationSeconds: 90,
      currentRound: 6,
      activeTurnPlayerUid: '',
    );

RoundSummaryStats used(int round, int darts) => RoundSummaryStats(
      roundIndex: round,
      score: 0,
      madeShots: darts,
      totalShots: darts,
      swishes: 0,
      bestStreak: 0,
    );

void main() {
  group('Darts outcome in CloudMatch (Step 19)', () {
    test('the player who reaches exactly zero wins', () {
      const p1 = CloudPlayer(uid: 'a', displayName: 'A', avatarEmoji: '🎯', roundScores: [180, 121]);
      const p2 = CloudPlayer(uid: 'b', displayName: 'B', avatarEmoji: '🎯', roundScores: [180, 100]);
      expect(dartsMatch(p1, p2).outcome, MatchOutcome.player1Won);
    });

    test('both check out in the same round: fewer darts wins', () {
      final p1 = CloudPlayer(
        uid: 'a',
        displayName: 'A',
        avatarEmoji: '🎯',
        roundScores: const [180, 121],
        roundSummaries: [used(1, 3), used(2, 3)],
      );
      final p2 = CloudPlayer(
        uid: 'b',
        displayName: 'B',
        avatarEmoji: '🎯',
        roundScores: const [180, 121],
        roundSummaries: [used(1, 3), used(2, 2)],
      );
      expect(dartsMatch(p1, p2).outcome, MatchOutcome.player2Won);
    });

    test('after the round cap, lower remaining wins', () {
      const p1 = CloudPlayer(uid: 'a', displayName: 'A', avatarEmoji: '🎯', roundScores: [100, 100]);
      const p2 = CloudPlayer(uid: 'b', displayName: 'B', avatarEmoji: '🎯', roundScores: [100, 150]);
      expect(dartsMatch(p1, p2).outcome, MatchOutcome.player2Won);
    });
  });
}
