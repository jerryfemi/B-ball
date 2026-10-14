import 'package:b_ball/models/match_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchInvite Model Tests', () {
    test('serialization and deserialization roundtrip preserves all challenge fields', () {
      const invite = MatchInvite(
        matchId: 'B8K29A',
        hostUid: 'host_123',
        hostName: 'HostPlayer',
        hostAvatar: 'assets/avatars/dunk_heads (1).webp',
        recipientUid: 'friend_456',
        recipientName: 'FriendPlayer',
        recipientAvatar: 'assets/avatars/dunk_heads (2).webp',
        totalRounds: 3,
        roundDurationSeconds: 60,
        difficulty: 'hard',
        status: MatchInviteStatus.pending,
        createdAt: 1740000000000,
      );

      final map = invite.toMap();
      final restored = MatchInvite.fromMap(map, 'B8K29A');

      expect(restored.matchId, equals('B8K29A'));
      expect(restored.hostUid, equals('host_123'));
      expect(restored.hostName, equals('HostPlayer'));
      expect(restored.recipientUid, equals('friend_456'));
      expect(restored.recipientName, equals('FriendPlayer'));
      expect(restored.totalRounds, equals(3));
      expect(restored.roundDurationSeconds, equals(60));
      expect(restored.difficulty, equals('hard'));
      expect(restored.status, equals(MatchInviteStatus.pending));
      expect(restored.isPending, isTrue);
      expect(restored.isAccepted, isFalse);
      expect(restored.createdAt, equals(1740000000000));
    });

    test('state transitions update status flags correctly', () {
      const invite = MatchInvite(
        matchId: 'X9Y8Z7',
        hostUid: 'host_1',
        hostName: 'Host',
        hostAvatar: '🏀',
        recipientUid: 'friend_2',
        recipientName: 'Friend',
        recipientAvatar: '🎯',
        createdAt: 1740000000000,
      );

      expect(invite.isPending, isTrue);

      final accepted = invite.copyWith(status: MatchInviteStatus.accepted);
      expect(accepted.isAccepted, isTrue);
      expect(accepted.isPending, isFalse);

      final declined = invite.copyWith(status: MatchInviteStatus.declined);
      expect(declined.isDeclined, isTrue);
      expect(declined.isPending, isFalse);

      final cancelled = invite.copyWith(status: MatchInviteStatus.cancelled);
      expect(cancelled.isCancelled, isTrue);
    });

    test('fromMap safely falls back when encountering missing or partial fields', () {
      final restored = MatchInvite.fromMap(const {}, 'FALLBACK_CODE');

      expect(restored.matchId, equals('FALLBACK_CODE'));
      expect(restored.hostName, equals('Host'));
      expect(restored.recipientName, equals('Friend'));
      expect(restored.totalRounds, equals(2));
      expect(restored.roundDurationSeconds, equals(60));
      expect(restored.difficulty, equals('medium'));
      expect(restored.status, equals(MatchInviteStatus.pending));
    });
  });
}
