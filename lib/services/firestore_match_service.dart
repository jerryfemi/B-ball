import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../game/match/match_config.dart';
import '../game/telemetry/shot_telemetry.dart';
import '../models/cloud_match.dart';
import 'auth_service.dart';

/// Central Firestore service managing remote match rooms, turn sync,
/// telemetry handoff, and in-game chat threads.
class FirestoreMatchService {
  FirestoreMatchService._internal();
  static final FirestoreMatchService instance = FirestoreMatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection('matches');

  /// Generates an arcade-style 6-character alphanumeric join code (e.g. "B8K29A").
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No ambiguous 0/O, 1/I
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates a new match room in Firestore.
  /// 
  /// If [initialRoundTelemetry] and [initialRoundScore] are provided,
  /// Player 1 has already shot Round 1 locally, so the match enters
  /// waiting state ready for Player 2 to spectate and shoot.
  Future<CloudMatch> createMatch({
    required MatchConfig config,
    required UserProfile player1Profile,
    RoundTelemetry? initialRoundTelemetry,
    int? initialRoundScore,
    String? initialChatMessage,
  }) async {
    final docRef = _matchesRef.doc();
    final joinCode = _generateJoinCode();
    final now = DateTime.now().millisecondsSinceEpoch;

    final hasCompletedFirstTurn =
        initialRoundTelemetry != null && initialRoundScore != null;

    final player1 = CloudPlayer(
      uid: player1Profile.uid,
      displayName: player1Profile.displayName,
      avatarEmoji: player1Profile.avatarEmoji,
      roundScores: hasCompletedFirstTurn ? [initialRoundScore] : [],
    );

    final chat = <CloudChatMessage>[];
    if (initialChatMessage != null && initialChatMessage.trim().isNotEmpty) {
      chat.add(
        CloudChatMessage(
          id: '${now}_p1',
          senderUid: player1Profile.uid,
          senderName: player1Profile.displayName,
          senderAvatar: player1Profile.avatarEmoji,
          text: initialChatMessage.trim(),
          timestamp: now,
        ),
      );
    }

    final match = CloudMatch(
      id: docRef.id,
      joinCode: joinCode,
      status: MatchStatus.waitingForOpponent,
      createdAt: now,
      updatedAt: now,
      playerIds: [player1Profile.uid],
      player1: player1,
      player2: null,
      totalRounds: config.totalRounds,
      roundDurationSeconds: config.roundDurationSeconds,
      currentRound: 1,
      // If Player 1 already shot, active turn awaits Player 2 upon joining
      activeTurnPlayerUid: hasCompletedFirstTurn ? '' : player1Profile.uid,
      latestTelemetry: initialRoundTelemetry,
      latestTelemetryRound: hasCompletedFirstTurn ? 1 : null,
      latestTelemetryShooterUid:
          hasCompletedFirstTurn ? player1Profile.uid : null,
      chat: chat,
    );

    await docRef.set(match.toMap());
    debugPrint('[FirestoreMatchService] Created match ${docRef.id} (code: $joinCode)');
    return match;
  }

  /// Finds and joins a match via 6-digit join code or direct URL code.
  Future<CloudMatch?> joinMatchByCode({
    required String joinCode,
    required UserProfile player2Profile,
  }) async {
    final cleanCode = joinCode.trim().toUpperCase();
    final query = await _matchesRef
        .where('joinCode', isEqualTo: cleanCode)
        .where('status', isEqualTo: MatchStatus.waitingForOpponent.key)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      debugPrint('[FirestoreMatchService] No waiting match found with code: $cleanCode');
      return null;
    }

    final doc = query.docs.first;
    final match = CloudMatch.fromFirestore(doc);

    // Prevent joining one's own match as player 2
    if (match.player1.uid == player2Profile.uid) {
      debugPrint('[FirestoreMatchService] Cannot join own match as player 2');
      return match;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final player2 = CloudPlayer(
      uid: player2Profile.uid,
      displayName: player2Profile.displayName,
      avatarEmoji: player2Profile.avatarEmoji,
      roundScores: [],
    );

    final updatedPlayerIds = [...match.playerIds, player2Profile.uid];

    // Whichever player didn't shoot Round 1 yet takes the active turn
    final nextActiveUid = match.player1.roundScores.isNotEmpty
        ? player2Profile.uid
        : match.player1.uid;

    await doc.reference.update({
      'player2': player2.toMap(),
      'playerIds': updatedPlayerIds,
      'status': MatchStatus.active.key,
      'activeTurnPlayerUid': nextActiveUid,
      'updatedAt': now,
    });

    debugPrint('[FirestoreMatchService] Joined match ${doc.id}');
    return match.copyWith(
      player2: player2,
      playerIds: updatedPlayerIds,
      status: MatchStatus.active,
      activeTurnPlayerUid: nextActiveUid,
      updatedAt: now,
    );
  }

  /// Submits completed turn telemetry and round score for the active player.
  /// 
  /// Automatically toggles turn handoff, advances round indexes,
  /// or concludes match if all rounds are completed.
  Future<void> submitTurn({
    required String matchId,
    required String shooterUid,
    required int roundScore,
    required RoundTelemetry telemetry,
    String? optionalChatMessage,
  }) async {
    final docRef = _matchesRef.doc(matchId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final match = CloudMatch.fromFirestore(snapshot);
    final now = DateTime.now().millisecondsSinceEpoch;

    final isP1 = match.player1.uid == shooterUid;
    final updatedP1Scores = [...match.player1.roundScores];
    final updatedP2Scores = [...(match.player2?.roundScores ?? <int>[])];

    if (isP1) {
      updatedP1Scores.add(roundScore);
    } else {
      updatedP2Scores.add(roundScore);
    }

    // Determine turn alternation and round advancement
    int nextRound = match.currentRound;
    String nextTurnUid;
    MatchStatus nextStatus = match.status;

    final bothPlayedThisRound =
        updatedP1Scores.length == nextRound && updatedP2Scores.length == nextRound;

    if (bothPlayedThisRound) {
      if (nextRound >= match.totalRounds) {
        // All rounds complete!
        nextStatus = MatchStatus.completed;
        nextTurnUid = '';
      } else {
        // Advance to next round, Player 1 starts the new round
        nextRound += 1;
        nextTurnUid = match.player1.uid;
      }
    } else {
      // Alternate turn to the opponent within the current round
      nextTurnUid = isP1 ? (match.player2?.uid ?? '') : match.player1.uid;
    }

    final updateData = <String, dynamic>{
      'currentRound': nextRound,
      'activeTurnPlayerUid': nextTurnUid,
      'status': nextStatus.key,
      'updatedAt': now,
      'latestTelemetry': telemetry.toJson(),
      'latestTelemetryRound': match.currentRound,
      'latestTelemetryShooterUid': shooterUid,
      if (isP1)
        'player1.roundScores': updatedP1Scores
      else
        'player2.roundScores': updatedP2Scores,
    };

    if (optionalChatMessage != null && optionalChatMessage.trim().isNotEmpty) {
      final senderProfile = isP1 ? match.player1 : match.player2;
      final newMsg = CloudChatMessage(
        id: '${now}_$shooterUid',
        senderUid: shooterUid,
        senderName: senderProfile?.displayName ?? 'Player',
        senderAvatar: senderProfile?.avatarEmoji ?? '🏀',
        text: optionalChatMessage.trim(),
        timestamp: now,
      );
      updateData['chat'] = FieldValue.arrayUnion([newMsg.toMap()]);
    }

    await docRef.update(updateData);
    debugPrint('[FirestoreMatchService] Submitted turn for $shooterUid in match $matchId');
  }

  /// Appends a chat message to the match's banter stream.
  Future<void> sendChatMessage({
    required String matchId,
    required CloudChatMessage message,
  }) async {
    final docRef = _matchesRef.doc(matchId);
    await docRef.update({
      'chat': FieldValue.arrayUnion([message.toMap()]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Streams real-time updates for an active match.
  Stream<CloudMatch?> streamMatch(String matchId) {
    return _matchesRef.doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CloudMatch.fromFirestore(doc);
    });
  }

  /// Streams active matches for the Match Inbox ("Your Turn" vs "Waiting for Opponent").
  Stream<List<CloudMatch>> streamUserMatches(String userUid) {
    return _matchesRef
        .where('playerIds', arrayContains: userUid)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => CloudMatch.fromFirestore(doc))
          .toList();
      // Sort in-memory by updatedAt descending
      matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return matches;
    });
  }
}
