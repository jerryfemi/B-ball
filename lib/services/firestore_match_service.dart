import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../game/match/match_config.dart';
import '../game/telemetry/shot_telemetry.dart';
import '../models/cloud_match.dart';
import 'auth_service.dart';
import 'friends_service.dart';

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

/// Exception thrown when a match room is not currently active.
class MatchNotActiveException implements Exception {
  final String message;
  const MatchNotActiveException(this.message);

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

/// Exception thrown when a turn is submitted for a round that does not match the room clock.
class RoundMismatchException implements Exception {
  final String message;
  const RoundMismatchException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when the user is not a participant of the match.
class NotParticipantException implements Exception {
  final String message;
  const NotParticipantException(this.message);

  @override
  String toString() => message;
}

/// Central Firestore service managing remote match rooms, turn sync,
/// telemetry handoff, and in-game chat threads.
class FirestoreMatchService {
  final AuthService? authService;
  final FriendsService? friendsService;

  FirestoreMatchService({
    this.authService,
    this.friendsService,
  });

  FirestoreMatchService._internal()
      : authService = null,
        friendsService = null;

  static final FirestoreMatchService instance =
      FirestoreMatchService._internal();

  AuthService get _effectiveAuthService =>
      authService ?? AuthService.instance;
  FriendsService get _effectiveFriendsService =>
      friendsService ?? FriendsService.instance;

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
    await _effectiveAuthService.ensureAuthenticated();

    final joinCode = generateJoinCode();
    final docRef = _matchesRef.doc(joinCode);
    final now = DateTime.now().millisecondsSinceEpoch;

    final hasCompletedFirstTurn =
        initialRoundTelemetry != null && initialRoundScore != null;

    final initialSummaries = hasCompletedFirstTurn
        ? [RoundSummaryStats.fromTelemetry(1, initialRoundTelemetry)]
        : <RoundSummaryStats>[];

    final player1 = CloudPlayer(
      uid: player1Profile.uid,
      displayName: player1Profile.displayName,
      avatarEmoji: player1Profile.avatarEmoji,
      roundScores: hasCompletedFirstTurn ? [initialRoundScore] : [],
      roundSummaries: initialSummaries,
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

    final friend = config.opponentFriend;
    final CloudPlayer? player2 = friend != null
        ? CloudPlayer(
            uid: friend.uid,
            displayName: friend.displayName,
            avatarEmoji: friend.avatarEmoji,
            roundScores: const [],
            roundSummaries: const [],
          )
        : null;

    final playerIds = [
      player1Profile.uid,
      if (friend != null) friend.uid,
    ];

    final match = CloudMatch(
      id: joinCode,
      joinCode: joinCode,
      status: friend != null ? MatchStatus.active : MatchStatus.waitingForOpponent,
      createdAt: now,
      updatedAt: now,
      playerIds: playerIds,
      player1: player1,
      player2: player2,
      totalRounds: config.totalRounds,
      roundDurationSeconds: config.roundDurationSeconds,
      currentRound: 1,
      // If Player 1 already shot, active turn awaits Player 2 upon joining/challenge
      activeTurnPlayerUid: hasCompletedFirstTurn
          ? (friend != null ? friend.uid : '')
          : player1Profile.uid,
      latestTelemetry: initialRoundTelemetry,
      latestTelemetryRound: hasCompletedFirstTurn ? 1 : null,
      latestTelemetryShooterUid:
          hasCompletedFirstTurn ? player1Profile.uid : null,
      chat: chat,
    );

    await docRef.set(match.toMap());
    debugPrint('[FirestoreMatchService] Created match with docId/code $joinCode');

    if (friend != null) {
      try {
        await _effectiveFriendsService.updateFriendMatch(
          myUid: player1Profile.uid,
          friendUid: friend.uid,
          matchId: match.id,
        );
      } catch (e) {
        debugPrint('[FirestoreMatchService] Failed to link friend match: $e');
      }
    }

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
    await _effectiveAuthService.ensureAuthenticated();

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
        roundSummaries: [],
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

  /// Atomically and idempotently submits completed turn telemetry and round performance.
  /// 
  /// Executes inside a transaction, validates shooter turn, enforces round sequence,
  /// derives score directly from telemetry to prevent client tampering,
  /// records per-round summary statistics for the podium, and handles round/turn progression.
  Future<void> submitTurn({
    required String matchId,
    required String shooterUid,
    required int roundIndex,
    required RoundTelemetry telemetry,
    String? optionalChatMessage,
  }) async {
    final docRef = _matchesRef.doc(matchId);

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw MatchNotFoundException('Cannot submit turn: match $matchId not found.');
      }

      final match = CloudMatch.fromFirestore(snapshot);

      // Verify active match status
      if (match.status != MatchStatus.active &&
          match.status != MatchStatus.waitingForOpponent) {
        throw MatchNotActiveException('Match $matchId is not active (status: ${match.status.name}).');
      }

      // Verify active turn
      if (match.activeTurnPlayerUid != shooterUid) {
        throw const NotYourTurnException('It is not your turn to shoot in this match.');
      }

      // Verify round synchronization
      if (match.currentRound != roundIndex) {
        throw RoundMismatchException(
          'Round mismatch: expected round ${match.currentRound}, submitted $roundIndex.',
        );
      }

      final isP1 = match.player1.uid == shooterUid;
      final currentShooter = isP1 ? match.player1 : match.player2;
      if (currentShooter == null) {
        throw const NotParticipantException('Shooter is not a registered participant in this match.');
      }

      // Idempotency: if score already exists for this round, ignore duplicate write
      if (currentShooter.roundScores.length >= match.currentRound) {
        debugPrint(
          '[FirestoreMatchService] Duplicate turn submission ignored for $shooterUid in round $roundIndex',
        );
        return;
      }

      // Derive score directly from telemetry (anti-tamper)
      final verifiedScore = telemetry.roundScore;
      final roundStats = RoundSummaryStats.fromTelemetry(roundIndex, telemetry);

      final updatedP1Scores = [...match.player1.roundScores];
      final updatedP1Summaries = [...match.player1.roundSummaries];
      final updatedP2Scores = [...(match.player2?.roundScores ?? <int>[])];
      final updatedP2Summaries = [...(match.player2?.roundSummaries ?? <RoundSummaryStats>[])];

      if (isP1) {
        updatedP1Scores.add(verifiedScore);
        updatedP1Summaries.add(roundStats);
      } else {
        updatedP2Scores.add(verifiedScore);
        updatedP2Summaries.add(roundStats);
      }

      // Determine turn alternation and round advancement
      int nextRound = match.currentRound;
      String nextTurnUid;
      MatchStatus nextStatus = match.status;

      final bothPlayedThisRound =
          updatedP1Scores.length == nextRound && updatedP2Scores.length == nextRound;

      if (bothPlayedThisRound) {
        if (nextRound >= match.totalRounds) {
          // All configured rounds completed! Conclude match
          nextStatus = MatchStatus.completed;
          nextTurnUid = '';
        } else {
          // Advance to next round, Player 1 leads the new round
          nextRound += 1;
          nextTurnUid = match.player1.uid;
        }
      } else {
        // Alternate to the opponent within the current round
        nextTurnUid = isP1 ? (match.player2?.uid ?? '') : match.player1.uid;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final updateData = <String, dynamic>{
        'currentRound': nextRound,
        'activeTurnPlayerUid': nextTurnUid,
        'status': nextStatus.key,
        'updatedAt': now,
        'latestTelemetry': telemetry.toJson(),
        'latestTelemetryRound': match.currentRound,
        'latestTelemetryShooterUid': shooterUid,
        if (isP1) ...{
          'player1.roundScores': updatedP1Scores,
          'player1.roundSummaries': updatedP1Summaries.map((s) => s.toMap()).toList(),
        } else ...{
          'player2.roundScores': updatedP2Scores,
          'player2.roundSummaries': updatedP2Summaries.map((s) => s.toMap()).toList(),
        },
      };

      if (optionalChatMessage != null && optionalChatMessage.trim().isNotEmpty) {
        final newMsg = CloudChatMessage(
          id: '${now}_$shooterUid',
          senderUid: shooterUid,
          senderName: currentShooter.displayName,
          senderAvatar: currentShooter.avatarEmoji,
          text: optionalChatMessage.trim(),
          timestamp: now,
        );
        updateData['chat'] = FieldValue.arrayUnion([newMsg.toMap()]);
      }

      transaction.update(docRef, updateData);
      debugPrint('[FirestoreMatchService] Submitted turn atomically for $shooterUid (Round $roundIndex)');
    });
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

  /// Fetches a single match document by ID or join code.
  Future<CloudMatch?> getMatch(String matchId) async {
    final clean = matchId.trim().toUpperCase();
    final doc = await _matchesRef.doc(clean).get();
    if (!doc.exists) return null;
    return CloudMatch.fromFirestore(doc);
  }

  /// Evaporates (deletes) a match room document from Firestore to free up cloud storage
  /// and reduce unnecessary listener/read load once a match is completed and dismissed.
  Future<void> deleteMatch(String matchId) async {
    final clean = matchId.trim().toUpperCase();
    await _matchesRef.doc(clean).delete();
    _cachedUserMatches.removeWhere((key, list) {
      list.removeWhere((m) => m.id == clean);
      return false;
    });
  }

  final Map<String, List<CloudMatch>> _cachedUserMatches = {};

  /// Retrieves the most recent memory-cached matches for instant zero-latency UI rendering.
  List<CloudMatch> getCachedUserMatches(String userUid) =>
      _cachedUserMatches[userUid] ?? const [];

  /// Streams active matches for the Match Inbox ("Your Turn" vs "Waiting for Opponent").
  /// Firestore's native SDK automatically pools query listeners and emits current cache immediately.
  Stream<List<CloudMatch>> streamUserMatches(String userUid) {
    if (userUid.isEmpty) {
      return Stream.value(const <CloudMatch>[]);
    }
    return _matchesRef
        .where('playerIds', arrayContains: userUid)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => CloudMatch.fromFirestore(doc))
          .toList();
      matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _cachedUserMatches[userUid] = matches;
      return matches;
    });
  }
}
