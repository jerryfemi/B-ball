/// Lightweight profile representation of an in-game friend.
class FriendProfile {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final int addedAt;
  final int lastActiveTimestamp;
  final String? activeMatchId;
  final int h2hWins;
  final int h2hLosses;

  const FriendProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.addedAt,
    this.lastActiveTimestamp = 0,
    this.activeMatchId,
    this.h2hWins = 0,
    this.h2hLosses = 0,
  });

  FriendProfile copyWith({
    String? uid,
    String? displayName,
    String? avatarEmoji,
    int? addedAt,
    int? lastActiveTimestamp,
    String? activeMatchId,
    int? h2hWins,
    int? h2hLosses,
  }) {
    return FriendProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      addedAt: addedAt ?? this.addedAt,
      lastActiveTimestamp: lastActiveTimestamp ?? this.lastActiveTimestamp,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      h2hWins: h2hWins ?? this.h2hWins,
      h2hLosses: h2hLosses ?? this.h2hLosses,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'avatarEmoji': avatarEmoji,
    'addedAt': addedAt,
    'lastActiveTimestamp': lastActiveTimestamp,
    'activeMatchId': activeMatchId,
    'h2hWins': h2hWins,
    'h2hLosses': h2hLosses,
  };

  factory FriendProfile.fromMap(Map<String, dynamic> map) => FriendProfile(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Friend',
    avatarEmoji: map['avatarEmoji'] as String? ?? '🏀',
    addedAt: (map['addedAt'] as num?)?.toInt() ?? 0,
    lastActiveTimestamp: (map['lastActiveTimestamp'] as num?)?.toInt() ?? 0,
    activeMatchId: map['activeMatchId'] as String?,
    h2hWins: (map['h2hWins'] as num?)?.toInt() ?? 0,
    h2hLosses: (map['h2hLosses'] as num?)?.toInt() ?? 0,
  );
}

/// Represents an incoming or outgoing friend invitation.
class FriendInvite {
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final String status;
  final int timestamp;

  const FriendInvite({
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    this.status = 'pending',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'status': status,
    'timestamp': timestamp,
  };

  factory FriendInvite.fromMap(Map<String, dynamic> map, String docId) =>
      FriendInvite(
        senderUid: (map['senderUid'] as String?) ?? docId,
        senderName: (map['senderName'] as String?) ?? 'Player',
        senderAvatar: (map['senderAvatar'] as String?) ?? '🏀',
        status: (map['status'] as String?) ?? 'pending',
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      );
}
