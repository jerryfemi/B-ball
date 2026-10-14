import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/physics/shot_difficulty.dart';
import '../game/telemetry/shot_telemetry.dart';
import 'player_descriptor.dart';

/// Status state of a remote cloud match.
enum MatchStatus {
  /// Waiting for player 2 to join via 6-digit code or URL.
  waitingForOpponent,

  /// In progress; players alternating turns.
  active,

  /// All rounds completed; final winner podium reached.
  completed,

  /// Cancelled or expired.
  abandoned,

  /// Fallback for forward compatibility with newer clients.
  unknown;

  String get key => name;

  static MatchStatus fromKey(String? key) {
    if (key == null) return MatchStatus.active;
    for (final val in MatchStatus.values) {
      if (val.name == key) return val;
    }
    return MatchStatus.unknown;
  }
}

/// Final outcome evaluation of a completed match.
enum MatchOutcome { inProgress, player1Won, player2Won, tie }

/// Compact per-round shooting statistics preserved across all rounds for the podium.
class RoundSummaryStats {
  final int roundIndex;
  final int score;
  final int madeShots;
  final int totalShots;
  final int swishes;
  final int bestStreak;

  const RoundSummaryStats({
    required this.roundIndex,
    required this.score,
    required this.madeShots,
    required this.totalShots,
    required this.swishes,
    required this.bestStreak,
  });

  factory RoundSummaryStats.fromTelemetry(
    int roundIndex,
    RoundTelemetry telemetry,
  ) {
    int streak = 0;
    int maxStreak = 0;
    for (final s in telemetry.shots) {
      if (s.isMake) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else {
        streak = 0;
      }
    }
    return RoundSummaryStats(
      roundIndex: roundIndex,
      score: telemetry.roundScore,
      madeShots: telemetry.madeShots,
      totalShots: telemetry.totalShots,
      swishes: telemetry.shots.where((s) => s.isSwish).length,
      bestStreak: maxStreak,
    );
  }

  Map<String, dynamic> toMap() => {
    'r': roundIndex,
    's': score,
    'm': madeShots,
    't': totalShots,
    'sw': swishes,
    'st': bestStreak,
  };

  factory RoundSummaryStats.fromMap(Map<String, dynamic> map) =>
      RoundSummaryStats(
        roundIndex: (map['r'] as num?)?.toInt() ?? 1,
        score: (map['s'] as num?)?.toInt() ?? 0,
        madeShots: (map['m'] as num?)?.toInt() ?? 0,
        totalShots: (map['t'] as num?)?.toInt() ?? 0,
        swishes: (map['sw'] as num?)?.toInt() ?? 0,
        bestStreak: (map['st'] as num?)?.toInt() ?? 0,
      );
}

/// Participant metadata and round performance in a cloud match.
class CloudPlayer implements PlayerDescriptor {
  final String uid;
  @override
  final String displayName;
  final String avatarEmoji;
  final List<int> roundScores;
  final List<RoundSummaryStats> roundSummaries;

  @override
  String get id => uid;

  @override
  String get avatar => avatarEmoji;

  const CloudPlayer({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.roundScores,
    this.roundSummaries = const [],
  });

  int get totalScore => roundScores.fold(0, (acc, s) => acc + s);

  /// Total successful shots made across all played rounds.
  int get totalMadeShots =>
      roundSummaries.fold(0, (acc, s) => acc + s.madeShots);

  /// Total shot attempts taken across all played rounds.
  int get totalAttemptedShots =>
      roundSummaries.fold(0, (acc, s) => acc + s.totalShots);

  /// Overall match shooting accuracy percentage (0.0 to 100.0).
  double get overallAccuracy => totalAttemptedShots > 0
      ? (totalMadeShots / totalAttemptedShots * 100.0)
      : 0.0;

  /// Total clean swishes scored across all played rounds.
  int get totalSwishes => roundSummaries.fold(0, (acc, s) => acc + s.swishes);

  /// Longest consecutive shot streak achieved during any round in the match.
  int get bestStreakAcrossMatch => roundSummaries.fold(
    0,
    (acc, s) => s.bestStreak > acc ? s.bestStreak : acc,
  );

  CloudPlayer copyWith({
    String? uid,
    String? displayName,
    String? avatarEmoji,
    List<int>? roundScores,
    List<RoundSummaryStats>? roundSummaries,
  }) {
    return CloudPlayer(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      roundScores: roundScores ?? this.roundScores,
      roundSummaries: roundSummaries ?? this.roundSummaries,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'avatarEmoji': avatarEmoji,
    'roundScores': roundScores,
    'roundSummaries': roundSummaries.map((s) => s.toMap()).toList(),
  };

  factory CloudPlayer.fromMap(Map<String, dynamic> map) => CloudPlayer(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Player',
    avatarEmoji:
        map['avatarEmoji'] as String? ?? PlayerDescriptor.defaultAvatar,
    roundScores:
        (map['roundScores'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [],
    roundSummaries:
        (map['roundSummaries'] as List<dynamic>?)
            ?.map((e) => RoundSummaryStats.fromMap(e as Map<String, dynamic>))
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

  factory CloudChatMessage.fromMap(Map<String, dynamic> map) =>
      CloudChatMessage(
        id: map['id'] as String? ?? '',
        senderUid: map['senderUid'] as String? ?? '',
        senderName: map['senderName'] as String? ?? 'Player',
        senderAvatar:
            map['senderAvatar'] as String? ??
            PlayerDescriptor.defaultAvatar,
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
  final ShotDifficulty difficulty;
  final int currentRound;

  /// UID of the player whose turn it is to shoot.
  final String activeTurnPlayerUid;

  /// Cached telemetry from the most recently submitted turn (for ghost replay).
  final RoundTelemetry? latestTelemetry;
  final int? latestTelemetryRound;
  final String? latestTelemetryShooterUid;

  /// Real-time chat banter feed stored inside the match document.
  final List<CloudChatMessage> chat;

  /// Live round score of the currently active shooter in real-time.
  final int? liveShooterScore;
  final String? liveShooterUid;

  /// Lightweight latest chat metadata mirrored on root doc for inbox/badge counters.
  final String? lastChatSenderUid;
  final int? lastChatTimestamp;
  final String? lastChatText;

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
    this.difficulty = ShotDifficulty.easy,
    required this.currentRound,
    required this.activeTurnPlayerUid,
    this.latestTelemetry,
    this.latestTelemetryRound,
    this.latestTelemetryShooterUid,
    this.chat = const [],
    this.liveShooterScore,
    this.liveShooterUid,
    this.lastChatSenderUid,
    this.lastChatTimestamp,
    this.lastChatText,
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

  /// Returns whether this match has an unread chat message for [myUid] relative to [lastReadMs].
  bool hasUnreadChat(String myUid, int lastReadMs) {
    if (lastChatSenderUid == null || lastChatSenderUid == myUid) return false;
    final msgTimestamp = lastChatTimestamp ?? 0;
    return msgTimestamp > lastReadMs;
  }

  /// Evaluates overall match outcome with explicit enum support.
  MatchOutcome get outcome {
    if (status != MatchStatus.completed || player2 == null) {
      return MatchOutcome.inProgress;
    }
    if (player1.totalScore > player2!.totalScore) {
      return MatchOutcome.player1Won;
    }
    if (player2!.totalScore > player1.totalScore) {
      return MatchOutcome.player2Won;
    }
    return MatchOutcome.tie;
  }

  /// UID of the match winner, or null if tie or in progress.
  String? get winnerUid {
    switch (outcome) {
      case MatchOutcome.player1Won:
        return player1.uid;
      case MatchOutcome.player2Won:
        return player2?.uid;
      case MatchOutcome.inProgress:
      case MatchOutcome.tie:
        return null;
    }
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
    ShotDifficulty? difficulty,
    int? currentRound,
    String? activeTurnPlayerUid,
    RoundTelemetry? latestTelemetry,
    int? latestTelemetryRound,
    String? latestTelemetryShooterUid,
    List<CloudChatMessage>? chat,
    int? liveShooterScore,
    String? liveShooterUid,
    String? lastChatSenderUid,
    int? lastChatTimestamp,
    String? lastChatText,
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
      difficulty: difficulty ?? this.difficulty,
      currentRound: currentRound ?? this.currentRound,
      activeTurnPlayerUid: activeTurnPlayerUid ?? this.activeTurnPlayerUid,
      latestTelemetry: latestTelemetry ?? this.latestTelemetry,
      latestTelemetryRound: latestTelemetryRound ?? this.latestTelemetryRound,
      latestTelemetryShooterUid:
          latestTelemetryShooterUid ?? this.latestTelemetryShooterUid,
      chat: chat ?? this.chat,
      liveShooterScore: liveShooterScore ?? this.liveShooterScore,
      liveShooterUid: liveShooterUid ?? this.liveShooterUid,
      lastChatSenderUid: lastChatSenderUid ?? this.lastChatSenderUid,
      lastChatTimestamp: lastChatTimestamp ?? this.lastChatTimestamp,
      lastChatText: lastChatText ?? this.lastChatText,
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
    'difficulty': difficulty.name,
    'currentRound': currentRound,
    'activeTurnPlayerUid': activeTurnPlayerUid,
    'latestTelemetry': latestTelemetry?.toJson(),
    'latestTelemetryRound': latestTelemetryRound,
    'latestTelemetryShooterUid': latestTelemetryShooterUid,
    'chat': chat.map((c) => c.toMap()).toList(),
    if (lastChatSenderUid != null) 'lastChatSenderUid': lastChatSenderUid,
    if (lastChatTimestamp != null) 'lastChatTimestamp': lastChatTimestamp,
    if (lastChatText != null) 'lastChatText': lastChatText,
  };

  /// Safely deserializes document map, resilient against corrupted or partial documents.
  factory CloudMatch.fromMap(Map<String, dynamic> map, String docId) {
    try {
      return CloudMatch(
        id: docId,
        joinCode: map['joinCode'] as String? ?? docId,
        status: MatchStatus.fromKey(map['status'] as String?),
        createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
        playerIds:
            (map['playerIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        player1: CloudPlayer.fromMap(
          map['player1'] as Map<String, dynamic>? ?? {},
        ),
        player2: map['player2'] != null
            ? CloudPlayer.fromMap(map['player2'] as Map<String, dynamic>)
            : null,
        totalRounds: (map['totalRounds'] as num?)?.toInt() ?? 2,
        roundDurationSeconds:
            (map['roundDurationSeconds'] as num?)?.toInt() ?? 60,
        difficulty: ShotDifficulty.values.firstWhere(
          (d) => d.name == map['difficulty'],
          orElse: () => ShotDifficulty.easy,
        ),
        currentRound: (map['currentRound'] as num?)?.toInt() ?? 1,
        activeTurnPlayerUid: map['activeTurnPlayerUid'] as String? ?? '',
        latestTelemetry: map['latestTelemetry'] != null
            ? RoundTelemetry.fromJson(
                map['latestTelemetry'] as Map<String, dynamic>,
              )
            : null,
        latestTelemetryRound: (map['latestTelemetryRound'] as num?)?.toInt(),
        latestTelemetryShooterUid: map['latestTelemetryShooterUid'] as String?,
        chat:
            (map['chat'] as List<dynamic>?)
                ?.map(
                  (e) => CloudChatMessage.fromMap(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        liveShooterScore: (map['liveShooterScore'] as num?)?.toInt(),
        liveShooterUid: map['liveShooterUid'] as String?,
        lastChatSenderUid: map['lastChatSenderUid'] as String?,
        lastChatTimestamp: (map['lastChatTimestamp'] as num?)?.toInt(),
        lastChatText: map['lastChatText'] as String?,
      );
    } catch (e) {
      // Return safe fallback rather than crashing the inbox
      return CloudMatch(
        id: docId,
        joinCode: docId,
        status: MatchStatus.unknown,
        createdAt: 0,
        updatedAt: 0,
        playerIds: const [],
        player1: const CloudPlayer(
          uid: '',
          displayName: 'Unknown',
          avatarEmoji: PlayerDescriptor.defaultAvatar,
          roundScores: [],
        ),
        totalRounds: 2,
        roundDurationSeconds: 60,
        currentRound: 1,
        activeTurnPlayerUid: '',
      );
    }
  }

  factory CloudMatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CloudMatch.fromMap(doc.data() ?? {}, doc.id);
  }
}
