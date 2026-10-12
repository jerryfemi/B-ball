import 'package:b_ball/game/telemetry/shot_telemetry.dart';
import 'package:b_ball/models/cloud_match.dart';
import 'package:b_ball/services/firestore_match_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudMatch Model Tests', () {
    test('serialization and deserialization roundtrip preserves full match state', () {
      const p1 = CloudPlayer(
        uid: 'user_1',
        displayName: 'Jeremy',
        avatarEmoji: '🔥',
        roundScores: [24, 18],
      );

      const p2 = CloudPlayer(
        uid: 'user_2',
        displayName: 'Opponent',
        avatarEmoji: '⚡',
        roundScores: [20, 22],
      );

      const chatMsg = CloudChatMessage(
        id: 'msg_1',
        senderUid: 'user_1',
        senderName: 'Jeremy',
        senderAvatar: '🔥',
        text: 'Nice shot! 🏀',
        timestamp: 1740000000000,
      );

      final match = CloudMatch(
        id: 'match_xyz',
        joinCode: 'K892AB',
        status: MatchStatus.active,
        createdAt: 1739999000000,
        updatedAt: 1740000000000,
        playerIds: ['user_1', 'user_2'],
        player1: p1,
        player2: p2,
        totalRounds: 3,
        roundDurationSeconds: 60,
        currentRound: 2,
        activeTurnPlayerUid: 'user_2',
        chat: [chatMsg],
      );

      final map = match.toMap();
      final restored = CloudMatch.fromMap(map, 'match_xyz');

      expect(restored.id, equals('match_xyz'));
      expect(restored.joinCode, equals('K892AB'));
      expect(restored.status, equals(MatchStatus.active));
      expect(restored.player1.displayName, equals('Jeremy'));
      expect(restored.player1.totalScore, equals(42));
      expect(restored.player2?.totalScore, equals(42));
      expect(restored.isMyTurn('user_2'), isTrue);
      expect(restored.isMyTurn('user_1'), isFalse);
      expect(restored.chat.length, equals(1));
      expect(restored.chat.first.text, equals('Nice shot! 🏀'));
    });

    test('winner evaluation returns correct UID upon completion', () {
      const p1 = CloudPlayer(
        uid: 'user_1',
        displayName: 'Jeremy',
        avatarEmoji: '🔥',
        roundScores: [30, 25], // total 55
      );

      const p2 = CloudPlayer(
        uid: 'user_2',
        displayName: 'Opponent',
        avatarEmoji: '⚡',
        roundScores: [20, 20], // total 40
      );

      final completedMatch = CloudMatch(
        id: 'match_123',
        joinCode: 'XYZ123',
        status: MatchStatus.completed,
        createdAt: 0,
        updatedAt: 0,
        playerIds: ['user_1', 'user_2'],
        player1: p1,
        player2: p2,
        totalRounds: 2,
        roundDurationSeconds: 60,
        currentRound: 2,
        activeTurnPlayerUid: '',
      );

      expect(completedMatch.winnerUid, equals('user_1'));
    });

    test('generateJoinCode generates cryptographically secure 6-character codes without ambiguous chars', () {
      final code1 = FirestoreMatchService.generateJoinCode();
      final code2 = FirestoreMatchService.generateJoinCode();

      expect(code1.length, equals(6));
      expect(code2.length, equals(6));
      expect(code1, isNot(equals(code2)));

      // No ambiguous chars: 0, O, 1, I
      final ambiguousPattern = RegExp(r'[0O1I]');
      expect(ambiguousPattern.hasMatch(code1), isFalse);
      expect(ambiguousPattern.hasMatch(code2), isFalse);
    });

    test('RoundSummaryStats computes swishes and best streak correctly from telemetry', () {
      final shots = [
        const RecordedShot(timestampMs: 100, startX: 0, startY: 1, startZ: -4, vx: 0, vy: 5, vz: 3, backspin: 14, isMake: true, isSwish: true, points: 2),
        const RecordedShot(timestampMs: 500, startX: 0, startY: 1, startZ: -4, vx: 0, vy: 5, vz: 3, backspin: 14, isMake: true, isSwish: false, points: 2),
        const RecordedShot(timestampMs: 900, startX: 0, startY: 1, startZ: -4, vx: 0, vy: 5, vz: 3, backspin: 14, isMake: false, points: 0),
        const RecordedShot(timestampMs: 1200, startX: 0, startY: 1, startZ: -4, vx: 0, vy: 5, vz: 3, backspin: 14, isMake: true, isSwish: true, points: 3),
      ];

      final telemetry = RoundTelemetry(
        roundScore: 7,
        madeShots: 3,
        totalShots: 4,
        shots: shots,
      );

      final stats = RoundSummaryStats.fromTelemetry(1, telemetry);
      expect(stats.roundIndex, equals(1));
      expect(stats.score, equals(7));
      expect(stats.madeShots, equals(3));
      expect(stats.totalShots, equals(4));
      expect(stats.swishes, equals(2));
      expect(stats.bestStreak, equals(2));

      final serialized = stats.toMap();
      final restored = RoundSummaryStats.fromMap(serialized);
      expect(restored.score, equals(7));
      expect(restored.swishes, equals(2));
    });

    test('CloudPlayer aggregates multi-round stats accurately for the podium', () {
      const round1 = RoundSummaryStats(roundIndex: 1, score: 20, madeShots: 8, totalShots: 10, swishes: 3, bestStreak: 4);
      const round2 = RoundSummaryStats(roundIndex: 2, score: 25, madeShots: 10, totalShots: 15, swishes: 5, bestStreak: 7);

      const player = CloudPlayer(
        uid: 'user_1',
        displayName: 'Jeremy',
        avatarEmoji: '🔥',
        roundScores: [20, 25],
        roundSummaries: [round1, round2],
      );

      expect(player.totalScore, equals(45));
      expect(player.totalMadeShots, equals(18));
      expect(player.totalAttemptedShots, equals(25));
      expect(player.overallAccuracy, closeTo(72.0, 0.01));
      expect(player.totalSwishes, equals(8));
      expect(player.bestStreakAcrossMatch, equals(7));
    });

    test('MatchOutcome identifies ties and winners explicitly', () {
      const p1 = CloudPlayer(uid: 'u1', displayName: 'P1', avatarEmoji: '🏀', roundScores: [20, 20]);
      const p2 = CloudPlayer(uid: 'u2', displayName: 'P2', avatarEmoji: '🎯', roundScores: [20, 20]);

      final tiedMatch = CloudMatch(
        id: 'tie_123',
        joinCode: 'TIE123',
        status: MatchStatus.completed,
        createdAt: 0,
        updatedAt: 0,
        playerIds: ['u1', 'u2'],
        player1: p1,
        player2: p2,
        totalRounds: 2,
        roundDurationSeconds: 60,
        currentRound: 2,
        activeTurnPlayerUid: '',
      );

      expect(tiedMatch.outcome, equals(MatchOutcome.tie));
      expect(tiedMatch.winnerUid, isNull);
    });
  });
}
