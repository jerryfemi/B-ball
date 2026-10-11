import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../game/match/match_config.dart';
import '../game/telemetry/shot_telemetry.dart';
import '../models/cloud_match.dart';
import 'auth_service.dart';

/// Exception thrown when no match document exists for the requested join code.
class MatchNotFoundException implements Exception {
  final String message;
  const MatchNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when a match room is already filled or concluded.
class MatchAlreadyFullException implements Exception {
  final String message;
  const MatchAlreadyFullException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when a user attempts to join a match they host.
class SelfJoinException implements Exception {
  final String message;
  const SelfJoinException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when an action is submitted out of turn.
class NotYourTurnException implements Exception {
  final String message;
  const NotYourTurnException(this.message);

  @override
  String toString() => message;
}

/// Central Firestore service managing remote match rooms, turn sync,
/// telemetry handoff, and in-game chat threads.
class FirestoreMatchService {
  FirestoreMatchService._internal();
  static final FirestoreMatchService instance = FirestoreMatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection('matches');

  /// Generates a cryptographically secure 6-character alphanumeric join code (e.g. "B8K29A").
  /// Excludes visually ambiguous characters (0/O, 1/I).
  static String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates a new match room in Firestore where the document ID IS the 6-character join code.
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
    // Ensure the host is authenticated with Firebase before creating a cloud match
    await AuthService.instance.ensureAuthenticated();

    final joinCode = generateJoinCode();
    final docRef = _matchesRef.doc(joinCode);
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
      id: joinCode,
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
    debugPrint('[FirestoreMatchService] Created match with docId/code $joinCode');
    return match;
  }

  /// Atomically joins a match via 6-digit code or direct URL code using a transaction.
  /// 
  /// Performs a direct document lookup on `matches/{joinCode}` rather than a collection query,
  /// preserving strict privacy rules and preventing enumeration.
  Future<CloudMatch> joinMatchByCode({
    required String joinCode,
    required UserProfile player2Profile,
  }) async {
    // Ensure the joining player is authenticated with Firebase
    await AuthService.instance.ensureAuthenticated();

    final cleanCode = joinCode.trim().toUpperCase();
    final docRef = _matchesRef.doc(cleanCode);

    return await _firestore.runTransaction<CloudMatch>((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw MatchNotFoundException('No match found with code $cleanCode.');
      }

      final match = CloudMatch.fromFirestore(snapshot);

      // Prevent joining one's own match
      if (match.player1.uid == player2Profile.uid) {
        throw const SelfJoinException('You cannot join a match hosted by yourself.');
      }

      // Ensure room is waiting and not already full
      if (match.status != MatchStatus.waitingForOpponent || match.player2 != null) {
        throw const MatchAlreadyFullException('This match is already in progress or completed.');
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

      transaction.update(docRef, {
        'player2': player2.toMap(),
        'playerIds': updatedPlayerIds,
        'status': MatchStatus.active.key,
        'activeTurnPlayerUid': nextActiveUid,
        'updatedAt': now,
      });

      debugPrint('[FirestoreMatchService] Joined match $cleanCode atomically');
      return match.copyWith(
        player2: player2,
        playerIds: updatedPlayerIds,
        status: MatchStatus.active,
        activeTurnPlayerUid: nextActiveUid,
        updatedAt: now,
      );
    });
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
    if (!snapshot.exists) {
      throw MatchNotFoundException('Cannot submit turn: match $matchId not found.');
    }

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
      matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return matches;
    });
  }
}
