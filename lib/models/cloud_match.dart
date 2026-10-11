import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/telemetry/shot_telemetry.dart';

/// Status state of a remote cloud match.
enum MatchStatus {
  /// Waiting for player 2 to join via 6-digit code or URL.
  waitingForOpponent,

  /// In progress; players alternating turns.
  active,

  /// All rounds completed; final winner podium reached.
  completed,

  /// Cancelled or expired.
  abandoned;

  String get key => name;

  static MatchStatus fromKey(String? key) {
    return MatchStatus.values.firstWhere(
      (e) => e.name == key,
      orElse: () => MatchStatus.active,
    );
  }
}

/// Participant metadata and round performance in a cloud match.
class CloudPlayer {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final List<int> roundScores;

  const CloudPlayer({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.roundScores,
  });

  int get totalScore => roundScores.fold(0, (acc, s) => acc + s);

  CloudPlayer copyWith({
    String? uid,
    String? displayName,
    String? avatarEmoji,
    List<int>? roundScores,
  }) {
    return CloudPlayer(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      roundScores: roundScores ?? this.roundScores,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'avatarEmoji': avatarEmoji,
    'roundScores': roundScores,
  };

  factory CloudPlayer.fromMap(Map<String, dynamic> map) => CloudPlayer(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Player',
    avatarEmoji: map['avatarEmoji'] as String? ?? '🏀',
    roundScores: (map['roundScores'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [],
  );
}

/// In-game chat banter message attached to a cloud match.
class CloudChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final String text;
  final int timestamp;

  const CloudChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderUid': senderUid,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'text': text,
    'timestamp': timestamp,
  };

  factory CloudChatMessage.fromMap(Map<String, dynamic> map) => CloudChatMessage(
    id: map['id'] as String? ?? '',
    senderUid: map['senderUid'] as String? ?? '',
    senderName: map['senderName'] as String? ?? 'Player',
    senderAvatar: map['senderAvatar'] as String? ?? '🏀',
    text: map['text'] as String? ?? '',
    timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
  );
}

/// Complete Firestore document representation of an asynchronous 1v1 match.
class CloudMatch {
  final String id;
  final String joinCode;
  final MatchStatus status;
  final int createdAt;
  final int updatedAt;
  final List<String> playerIds;

  final CloudPlayer player1;
  final CloudPlayer? player2;

  final int totalRounds;
  final int roundDurationSeconds;
  final int currentRound;

  /// UID of the player whose turn it is to shoot.
  final String activeTurnPlayerUid;

  /// Cached telemetry from the most recently submitted turn (for ghost replay).
  final RoundTelemetry? latestTelemetry;
  final int? latestTelemetryRound;
  final String? latestTelemetryShooterUid;

  /// Real-time chat banter feed stored inside the match document.
  final List<CloudChatMessage> chat;

  const CloudMatch({
    required this.id,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.playerIds,
    required this.player1,
    this.player2,
    required this.totalRounds,
    required this.roundDurationSeconds,
    required this.currentRound,
    required this.activeTurnPlayerUid,
    this.latestTelemetry,
    this.latestTelemetryRound,
    this.latestTelemetryShooterUid,
    this.chat = const [],
  });

  bool isMyTurn(String myUid) => activeTurnPlayerUid == myUid;
  bool isParticipant(String myUid) => playerIds.contains(myUid);

  CloudPlayer? myPlayer(String myUid) {
    if (player1.uid == myUid) return player1;
    if (player2?.uid == myUid) return player2;
    return null;
  }

  CloudPlayer? opponentPlayer(String myUid) {
    if (player1.uid == myUid) return player2;
    if (player2?.uid == myUid) return player1;
    return null;
  }

  String? get winnerUid {
    if (status != MatchStatus.completed || player2 == null) return null;
    if (player1.totalScore > player2!.totalScore) return player1.uid;
    if (player2!.totalScore > player1.totalScore) return player2!.uid;
    return null; // Tie
  }

  CloudMatch copyWith({
    String? id,
    String? joinCode,
    MatchStatus? status,
    int? createdAt,
    int? updatedAt,
    List<String>? playerIds,
    CloudPlayer? player1,
    CloudPlayer? player2,
    int? totalRounds,
    int? roundDurationSeconds,
    int? currentRound,
    String? activeTurnPlayerUid,
    RoundTelemetry? latestTelemetry,
    int? latestTelemetryRound,
    String? latestTelemetryShooterUid,
    List<CloudChatMessage>? chat,
  }) {
    return CloudMatch(
      id: id ?? this.id,
      joinCode: joinCode ?? this.joinCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      playerIds: playerIds ?? this.playerIds,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      totalRounds: totalRounds ?? this.totalRounds,
      roundDurationSeconds: roundDurationSeconds ?? this.roundDurationSeconds,
      currentRound: currentRound ?? this.currentRound,
      activeTurnPlayerUid: activeTurnPlayerUid ?? this.activeTurnPlayerUid,
      latestTelemetry: latestTelemetry ?? this.latestTelemetry,
      latestTelemetryRound: latestTelemetryRound ?? this.latestTelemetryRound,
      latestTelemetryShooterUid: latestTelemetryShooterUid ?? this.latestTelemetryShooterUid,
      chat: chat ?? this.chat,
    );
  }

  Map<String, dynamic> toMap() => {
    'joinCode': joinCode,
    'status': status.key,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'playerIds': playerIds,
    'player1': player1.toMap(),
    'player2': player2?.toMap(),
    'totalRounds': totalRounds,
    'roundDurationSeconds': roundDurationSeconds,
    'currentRound': currentRound,
    'activeTurnPlayerUid': activeTurnPlayerUid,
    'latestTelemetry': latestTelemetry?.toJson(),
    'latestTelemetryRound': latestTelemetryRound,
    'latestTelemetryShooterUid': latestTelemetryShooterUid,
    'chat': chat.map((c) => c.toMap()).toList(),
  };

  factory CloudMatch.fromMap(Map<String, dynamic> map, String docId) {
    return CloudMatch(
      id: docId,
      joinCode: map['joinCode'] as String? ?? '',
      status: MatchStatus.fromKey(map['status'] as String?),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      playerIds: (map['playerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      player1: CloudPlayer.fromMap(map['player1'] as Map<String, dynamic>? ?? {}),
      player2: map['player2'] != null
          ? CloudPlayer.fromMap(map['player2'] as Map<String, dynamic>)
          : null,
      totalRounds: (map['totalRounds'] as num?)?.toInt() ?? 2,
      roundDurationSeconds: (map['roundDurationSeconds'] as num?)?.toInt() ?? 60,
      currentRound: (map['currentRound'] as num?)?.toInt() ?? 1,
      activeTurnPlayerUid: map['activeTurnPlayerUid'] as String? ?? '',
      latestTelemetry: map['latestTelemetry'] != null
          ? RoundTelemetry.fromJson(map['latestTelemetry'] as Map<String, dynamic>)
          : null,
      latestTelemetryRound: (map['latestTelemetryRound'] as num?)?.toInt(),
      latestTelemetryShooterUid: map['latestTelemetryShooterUid'] as String?,
      chat: (map['chat'] as List<dynamic>?)
              ?.map((e) => CloudChatMessage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory CloudMatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CloudMatch.fromMap(doc.data() ?? {}, doc.id);
  }
}
