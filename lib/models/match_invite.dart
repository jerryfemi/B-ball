import 'package:cloud_firestore/cloud_firestore.dart';

import 'player_descriptor.dart';

/// Status state of a 1v1 match invitation / challenge.
enum MatchInviteStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired;

  String get key => name;

  static MatchInviteStatus fromKey(String? key) {
    if (key == null) return MatchInviteStatus.pending;
    for (final val in MatchInviteStatus.values) {
      if (val.name == key) return val;
    }
    return MatchInviteStatus.pending;
  }
}

/// Represents a real-time 1v1 match challenge dispatched to an opponent.
class MatchInvite {
  final String matchId;
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final String recipientUid;
  final String recipientName;
  final String recipientAvatar;
  final int totalRounds;
  final int roundDurationSeconds;
  final String difficulty;
  final MatchInviteStatus status;
  final int createdAt;

  /// Which game the challenge is for ('basketball', 'archery', …).
  final String game;

  const MatchInvite({
    required this.matchId,
    required this.hostUid,
    required this.hostName,
    required this.hostAvatar,
    required this.recipientUid,
    required this.recipientName,
    required this.recipientAvatar,
    this.totalRounds = 2,
    this.roundDurationSeconds = 60,
    this.difficulty = 'medium',
    this.status = MatchInviteStatus.pending,
    required this.createdAt,
    this.game = 'basketball',
  });

  bool get isArchery => game == 'archery';

  bool get isPending => status == MatchInviteStatus.pending;
  bool get isAccepted => status == MatchInviteStatus.accepted;
  bool get isDeclined => status == MatchInviteStatus.declined;
  bool get isCancelled => status == MatchInviteStatus.cancelled;

  MatchInvite copyWith({
    String? matchId,
    String? hostUid,
    String? hostName,
    String? hostAvatar,
    String? recipientUid,
    String? recipientName,
    String? recipientAvatar,
    int? totalRounds,
    int? roundDurationSeconds,
    String? difficulty,
    MatchInviteStatus? status,
    int? createdAt,
    String? game,
  }) {
    return MatchInvite(
      matchId: matchId ?? this.matchId,
      hostUid: hostUid ?? this.hostUid,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      recipientUid: recipientUid ?? this.recipientUid,
      recipientName: recipientName ?? this.recipientName,
      recipientAvatar: recipientAvatar ?? this.recipientAvatar,
      totalRounds: totalRounds ?? this.totalRounds,
      roundDurationSeconds: roundDurationSeconds ?? this.roundDurationSeconds,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      game: game ?? this.game,
    );
  }

  Map<String, dynamic> toMap() => {
    'matchId': matchId,
    'hostUid': hostUid,
    'hostName': hostName,
    'hostAvatar': hostAvatar,
    'recipientUid': recipientUid,
    'recipientName': recipientName,
    'recipientAvatar': recipientAvatar,
    'totalRounds': totalRounds,
    'roundDurationSeconds': roundDurationSeconds,
    'difficulty': difficulty,
    'status': status.key,
    'createdAt': createdAt,
    'game': game,
  };

  factory MatchInvite.fromMap(Map<String, dynamic> map, [String? id]) =>
      MatchInvite(
        matchId: map['matchId'] as String? ?? id ?? '',
        hostUid: map['hostUid'] as String? ?? '',
        hostName: map['hostName'] as String? ?? 'Host',
        hostAvatar:
            map['hostAvatar'] as String? ?? PlayerDescriptor.defaultAvatar,
        recipientUid: map['recipientUid'] as String? ?? '',
        recipientName: map['recipientName'] as String? ?? 'Friend',
        recipientAvatar:
            map['recipientAvatar'] as String? ??
            PlayerDescriptor.defaultAvatar,
        totalRounds: (map['totalRounds'] as num?)?.toInt() ?? 2,
        roundDurationSeconds:
            (map['roundDurationSeconds'] as num?)?.toInt() ?? 60,
        difficulty: map['difficulty'] as String? ?? 'medium',
        status: MatchInviteStatus.fromKey(map['status'] as String?),
        createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
        game: (map['game'] as String?)?.isNotEmpty == true
            ? map['game'] as String
            : 'basketball',
      );

  factory MatchInvite.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MatchInvite.fromMap(doc.data() ?? {}, doc.id);
  }
}
