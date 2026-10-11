import 'package:b_ball/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile Tests', () {
    test('serialization and deserialization preserves all fields', () {
      const profile = UserProfile(
        uid: 'user_test_123',
        displayName: 'GhostShooter',
        avatarEmoji: '⚡',
        isAnonymous: true,
      );

      final json = profile.toJson();
      final reconstructed = UserProfile.fromJson(json);

      expect(reconstructed.uid, equals('user_test_123'));
      expect(reconstructed.displayName, equals('GhostShooter'));
      expect(reconstructed.avatarEmoji, equals('⚡'));
      expect(reconstructed.isAnonymous, isTrue);
    });

    test('copyWith updates specified fields only', () {
      const original = UserProfile(
        uid: 'uid_initial',
        displayName: 'Player1',
        avatarEmoji: '🏀',
        isAnonymous: true,
      );

      final updated = original.copyWith(
        displayName: 'Champion',
        avatarEmoji: '👑',
      );

      expect(updated.uid, equals('uid_initial'));
      expect(updated.displayName, equals('Champion'));
      expect(updated.avatarEmoji, equals('👑'));
      expect(updated.isAnonymous, isTrue);
    });
  });
}
