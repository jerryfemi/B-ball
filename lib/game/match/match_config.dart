import '../../models/cloud_match.dart';
import '../../models/friend_profile.dart';
import '../../models/player_descriptor.dart';

/// Immutable configuration parameters for a 1v1 turn-based match.
class MatchConfig {
  /// Total rounds per match (options: 2, 3, or 4; defaults to 2).
  final int totalRounds;

  /// Duration of each round in seconds (e.g. 30, 45, or 60; defaults to 60).
  final int roundDurationSeconds;

  /// Display name for Player 1 (defaults to 'You').
  final String player1Name;

  /// Display name for Player 2 (defaults to 'Them').
  final String player2Name;

  /// Emoji avatar for Player 1 (defaults to '🏀').
  final String player1Avatar;

  /// Emoji avatar for Player 2 (defaults to '🎯').
  final String player2Avatar;

  /// Optional specific opponent UID when challenging a friend directly.
  final String? player2Uid;

  /// Optional FriendProfile reference when challenging a friend directly.
  final FriendProfile? opponentFriend;

  /// Optional pre-created CloudMatch if room was generated upfront in dialog.
  final CloudMatch? precreatedMatch;

  const MatchConfig({
    this.totalRounds = 2,
    this.roundDurationSeconds = 60,
    this.player1Name = 'You',
    this.player2Name = 'Them',
    this.player1Avatar = PlayerDescriptor.defaultAvatar,
    this.player2Avatar = 'assets/avatars/dunk_heads (2).webp',
    this.player2Uid,
    this.opponentFriend,
    this.precreatedMatch,
  });

  MatchConfig copyWith({
    int? totalRounds,
    int? roundDurationSeconds,
    String? player1Name,
    String? player2Name,
    String? player1Avatar,
    String? player2Avatar,
    String? player2Uid,
    FriendProfile? opponentFriend,
    CloudMatch? precreatedMatch,
  }) {
    return MatchConfig(
      totalRounds: totalRounds ?? this.totalRounds,
      roundDurationSeconds: roundDurationSeconds ?? this.roundDurationSeconds,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
      player1Avatar: player1Avatar ?? this.player1Avatar,
      player2Avatar: player2Avatar ?? this.player2Avatar,
      player2Uid: player2Uid ?? this.player2Uid,
      opponentFriend: opponentFriend ?? this.opponentFriend,
      precreatedMatch: precreatedMatch ?? this.precreatedMatch,
    );
  }
}
