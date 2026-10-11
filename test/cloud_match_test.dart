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
  });
}
