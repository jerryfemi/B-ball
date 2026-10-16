import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../game/match/match_config.dart';
import '../game/telemetry/shot_telemetry.dart';
import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../models/live_reaction_event.dart';
import '../models/match_invite.dart';
import 'auth_service.dart';
import 'friends_service.dart';
import 'update/update_platform.dart';

/// Exception thrown when no match document exists for the requested join code.
class MatchNotFoundException implements Exception {
  final String message;
  const MatchNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when a match room has been closed, cancelled, or concluded by the host.
class MatchClosedException implements Exception {
  final String message;
  const MatchClosedException([this.message = 'This room has already been closed by the host.']);

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
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

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
    if (!isDeviceOnline()) {
      throw const AuthRequiredException(
        'Internet connection required to create an online 1v1 match.',
      );
    }

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

    final friend = config.opponentFriend;

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
      difficulty: config.difficulty,
      currentRound: 1,
      // If Player 1 already shot, active turn awaits Player 2 upon joining/challenge
      activeTurnPlayerUid: player1Profile.uid,
      latestTelemetry: initialRoundTelemetry,
      latestTelemetryRound: hasCompletedFirstTurn ? 1 : null,
      latestTelemetryShooterUid:
          hasCompletedFirstTurn ? player1Profile.uid : null,
      chat: const [],
    );

    final ttl7Days = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );

    await docRef.set({
      ...match.toMap(),
      'expireAt': ttl7Days,
    });

    // Write initial chat message to lightweight subcollection (decoupled from match telemetry)
    if (initialChatMessage != null && initialChatMessage.trim().isNotEmpty) {
      final chatMsg = CloudChatMessage(
        id: '${now}_p1',
        senderUid: player1Profile.uid,
        senderName: player1Profile.displayName,
        senderAvatar: player1Profile.avatarEmoji,
        text: initialChatMessage.trim(),
        timestamp: now,
      );
      await docRef.collection('messages').doc(chatMsg.id).set({
        ...chatMsg.toMap(),
        'expireAt': ttl7Days,
      });
    }
    debugPrint('[FirestoreMatchService] Created match with docId/code $joinCode');

    if (friend != null) {
      try {
        await sendMatchChallenge(
          match: match,
          hostProfile: player1Profile,
          friend: friend,
        );
      } catch (e) {
        debugPrint('[FirestoreMatchService] Failed to dispatch friend match challenge: $e');
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
    if (!isDeviceOnline()) {
      throw const AuthRequiredException(
        'Internet connection required to join an online 1v1 match.',
      );
    }

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

      // Check if room was closed, abandoned, or finished
      if (match.status == MatchStatus.abandoned || match.status == MatchStatus.declined) {
        throw const MatchClosedException('This room has been closed by the host.');
      }

      if (match.status == MatchStatus.completed || match.status == MatchStatus.forfeited) {
        throw const MatchClosedException('This match has already ended.');
      }

      // Ensure room is waiting and not already full
      if (match.status != MatchStatus.waitingForOpponent || match.player2 != null) {
        throw const MatchAlreadyFullException('This room is already in progress with another player.');
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

  /// Dispatches a real-time match challenge to [friend]'s incoming invites subcollection.
  Future<MatchInvite> sendMatchChallenge({
    required CloudMatch match,
    required UserProfile hostProfile,
    required FriendProfile friend,
  }) async {
    final invite = MatchInvite(
      matchId: match.id,
      hostUid: hostProfile.uid,
      hostName: hostProfile.displayName,
      hostAvatar: hostProfile.avatarEmoji,
      recipientUid: friend.uid,
      recipientName: friend.displayName,
      recipientAvatar: friend.avatarEmoji,
      totalRounds: match.totalRounds,
      roundDurationSeconds: match.roundDurationSeconds,
      difficulty: match.difficulty.name,
      status: MatchInviteStatus.pending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _usersRef
        .doc(friend.uid)
        .collection('match_invites')
        .doc(match.id)
        .set({
          ...invite.toMap(),
          'expireAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        });

    try {
      await _effectiveFriendsService.updateFriendMatch(
        myUid: hostProfile.uid,
        friendUid: friend.uid,
        matchId: match.id,
      );
    } catch (_) {}

    debugPrint('[FirestoreMatchService] Dispatched match challenge ${match.id} to ${friend.uid}');
    return invite;
  }

  /// Streams real-time list of pending match challenges received by [myUid].
  Stream<List<MatchInvite>> streamIncomingMatchChallenges(String myUid) {
    if (myUid.isEmpty) return Stream.value(const []);
    return _usersRef
        .doc(myUid)
        .collection('match_invites')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => MatchInvite.fromFirestore(d))
              .where((inv) => inv.isPending)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          debugPrint('[FirestoreMatchService] Stream incoming challenges error: $error');
          return const <MatchInvite>[];
        });
  }

  /// Accepts a match challenge, marks the invite accepted, and atomically joins the room.
  Future<CloudMatch> acceptMatchChallenge({
    required MatchInvite invite,
    required UserProfile recipientProfile,
  }) async {
    try {
      await _usersRef
          .doc(recipientProfile.uid)
          .collection('match_invites')
          .doc(invite.matchId)
          .update({
        'status': MatchInviteStatus.accepted.key,
      });
    } catch (e) {
      debugPrint('[FirestoreMatchService] Notice: could not mark invite accepted: $e');
    }

    return await joinMatchByCode(
      joinCode: invite.matchId,
      player2Profile: recipientProfile,
    );
  }

  /// Declines an incoming match challenge.
  Future<void> declineMatchChallenge({
    required String myUid,
    required String matchId,
    String? hostUid,
  }) async {
    try {
      await _usersRef
          .doc(myUid)
          .collection('match_invites')
          .doc(matchId)
          .update({
        'status': MatchInviteStatus.declined.key,
      });

      // Mark the match itself as explicitly declined
      await _matchesRef.doc(matchId).update({
        'status': MatchStatus.declined.key,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (hostUid != null && hostUid.isNotEmpty) {
        try {
          await _effectiveFriendsService.updateFriendMatch(
            myUid: myUid,
            friendUid: hostUid,
            matchId: null,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[FirestoreMatchService] Error declining match challenge: $e');
    }
  }

  /// Cancels an outgoing match challenge dispatched to a friend.
  Future<void> cancelMatchChallenge({
    required String friendUid,
    required String matchId,
  }) async {
    try {
      await _usersRef
          .doc(friendUid)
          .collection('match_invites')
          .doc(matchId)
          .update({
        'status': MatchInviteStatus.cancelled.key,
      });
    } catch (e) {
      debugPrint('[FirestoreMatchService] Error cancelling match challenge: $e');
    }
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

    await _firestore.runTransaction((transaction) async {
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
      final ttl7Days = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      );
      final updateData = <String, dynamic>{
        'currentRound': nextRound,
        'activeTurnPlayerUid': nextTurnUid,
        'status': nextStatus.key,
        'updatedAt': now,
        'expireAt': ttl7Days,
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

      transaction.update(docRef, updateData);
      debugPrint('[FirestoreMatchService] Submitted turn atomically for $shooterUid (Round $roundIndex)');
    });

    // Write optional chat message to lightweight subcollection (outside transaction for efficiency)
    if (optionalChatMessage != null && optionalChatMessage.trim().isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ttl7Days = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      );
      final newMsg = CloudChatMessage(
        id: '${now}_$shooterUid',
        senderUid: shooterUid,
        senderName: 'Player',
        senderAvatar: '',
        text: optionalChatMessage.trim(),
        timestamp: now,
      );
      await docRef.collection('messages').doc(newMsg.id).set({
        ...newMsg.toMap(),
        'expireAt': ttl7Days,
      });
      await docRef.update({
        'updatedAt': now,
        'lastChatSenderUid': shooterUid,
        'lastChatTimestamp': now,
        'lastChatText': optionalChatMessage.trim(),
        'expireAt': ttl7Days,
      });
    }
  }

  /// Appends a chat message to the match's lightweight subcollection.
  ///
  /// Chat messages are now stored in `matches/{id}/messages/{msgId}` instead
  /// of the root document's `chat` array. This prevents re-downloading
  /// heavy shot telemetry on every chat message.
  Future<void> sendChatMessage({
    required String matchId,
    required CloudChatMessage message,
  }) async {
    final docRef = _matchesRef.doc(matchId);
    final ttl7Days = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );
    await docRef.collection('messages').doc(message.id).set({
      ...message.toMap(),
      'expireAt': ttl7Days,
    });
    // Touch updatedAt and mirror lightweight chat metadata on root for notification badges
    await docRef.update({
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'lastChatSenderUid': message.senderUid,
      'lastChatTimestamp': message.timestamp,
      'lastChatText': message.text,
      'expireAt': ttl7Days,
    });
  }

  /// Streams real-time chat messages from the match's messages subcollection.
  Stream<List<CloudChatMessage>> streamMatchChat(String matchId) {
    if (matchId.isEmpty) return Stream.value(const <CloudChatMessage>[]);
    return _matchesRef
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CloudChatMessage.fromMap(doc.data()))
            .toList())
        .handleError((e) {
      debugPrint('[FirestoreMatchService] Stream match chat error: $e');
      return const <CloudChatMessage>[];
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

  /// Leaves or dismisses a match from the current player's inbox.
  /// Removes the player's UID from `playerIds` and marks the match as abandoned if not completed.
  Future<void> leaveOrDismissMatch({
    required String matchId,
    required String myUid,
  }) async {
    final clean = matchId.trim().toUpperCase();
    try {
      final doc = await _matchesRef.doc(clean).get();
      if (!doc.exists) return;
      final data = doc.data();
      final currentStatus = data?['status'] as String?;
      final isAlreadyDone = currentStatus == MatchStatus.completed.key ||
          currentStatus == MatchStatus.abandoned.key;

      if (isAlreadyDone) {
        // Just remove user from playerIds so it disappears from their inbox stream
        await _matchesRef.doc(clean).update({
          'playerIds': FieldValue.arrayRemove([myUid]),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Mark abandoned and remove user
        await _matchesRef.doc(clean).update({
          'playerIds': FieldValue.arrayRemove([myUid]),
          'status': MatchStatus.abandoned.key,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      _cachedUserMatches.forEach((key, list) {
        list.removeWhere((m) => m.id == clean);
      });
    } catch (e) {
      debugPrint('[FirestoreMatchService] Error leaving/dismissing match $clean: $e');
    }
  }

  /// Atomically marks a match completed and records winnerUid when opponent abandons or times out.
  Future<void> claimForfeitVictory({
    required String matchId,
    required String winnerUid,
  }) async {
    final clean = matchId.trim().toUpperCase();
    try {
      await _matchesRef.doc(clean).update({
        'status': MatchStatus.completed.key,
        'winnerUid': winnerUid,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[FirestoreMatchService] Forfeit victory claimed for $clean by $winnerUid');
    } catch (e) {
      debugPrint('[FirestoreMatchService] Error claiming forfeit victory for $clean: $e');
    }
  }

  /// Gracefully forfeits / resigns an active match.
  ///
  /// Marks document as [MatchStatus.forfeited], designates [forfeitedBy], and names [winnerUid].
  Future<void> forfeitMatch({
    required String matchId,
    required String forfeiterUid,
    required String winnerUid,
  }) async {
    final clean = matchId.trim().toUpperCase();
    try {
      await _matchesRef.doc(clean).update({
        'status': MatchStatus.forfeited.key,
        'forfeitedBy': forfeiterUid,
        'winnerUid': winnerUid,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint(
        '[FirestoreMatchService] Match $clean forfeited by $forfeiterUid; winner: $winnerUid',
      );
    } catch (e) {
      debugPrint('[FirestoreMatchService] Error forfeiting match $clean: $e');
    }
  }

  final Map<String, List<CloudMatch>> _cachedUserMatches = {};

  /// Retrieves the most recent memory-cached matches for instant zero-latency UI rendering.
  List<CloudMatch> getCachedUserMatches(String userUid) =>
      _cachedUserMatches[userUid] ?? const [];

  /// Streams active matches for the Match Inbox ("Your Turn" vs "Waiting for Opponent").
  ///
  /// Query is now bounded: only active/waiting matches are streamed, with a
  /// hard limit of 20 documents to prevent downloading hundreds of historical matches.
  /// Completed matches can still be fetched on-demand via [getMatch].
  Stream<List<CloudMatch>> streamUserMatches(String userUid) {
    if (userUid.isEmpty) {
      return Stream.value(const <CloudMatch>[]);
    }
    return _matchesRef
        .where('playerIds', arrayContains: userUid)
        .where('status', whereIn: [
          MatchStatus.active.key,
          MatchStatus.waitingForOpponent.key,
          MatchStatus.completed.key,
        ])
        .limit(20)
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

  /// Broadcasts a live shot impulse micro-packet to the `live_shots` subcollection.
  ///
  /// This micro-packet (~150 bytes) conveys launch coordinates, 3D velocity vectors,
  /// backspin, and make metadata so spectators can simulate the deterministic trajectory locally.
  Future<void> broadcastLiveShot({
    required String matchId,
    required RecordedShot shot,
    required String shooterUid,
    required int shotIndex,
  }) async {
    final cleanId = matchId.trim().toUpperCase();
    final docRef = _matchesRef.doc(cleanId).collection('live_shots');
    final shotId = '${shot.timestampMs}_${shooterUid}_$shotIndex';
    try {
      await docRef.doc(shotId).set({
        'id': shotId,
        'shooterUid': shooterUid,
        'shotIndex': shotIndex,
        'shot': shot.toJson(),
        'timestamp': shot.timestampMs,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'expireAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });
    } catch (e) {
      debugPrint('[FirestoreMatchService] broadcastLiveShot error: $e');
    }
  }

  /// Streams real-time live shots broadcast by the active shooter.
  ///
  /// Uses Firestore document changes (`DocumentChangeType.added`) filtered by timestamp
  /// to ensure only newly launched shots are received and spawned as ghost balls.
  Stream<RecordedShot> streamLiveShots(String matchId, {int? sinceTimestampMs}) {
    if (matchId.isEmpty) return const Stream.empty();
    final cleanId = matchId.trim().toUpperCase();
    final start = sinceTimestampMs ?? (DateTime.now().millisecondsSinceEpoch - 1500);

    return _matchesRef
        .doc(cleanId)
        .collection('live_shots')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .snapshots()
        .expand((snap) => snap.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) {
          final data = change.doc.data();
          final shotMap = data?['shot'] as Map<String, dynamic>?;
          if (shotMap == null) return null;

          final createdAt = (data?['createdAt'] as num?)?.toInt() ?? 0;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          // Filter out bursts of stale shots older than 3 seconds (e.g. from background tab resume)
          if (createdAt > 0 && (nowMs - createdAt > 3000)) {
            return null;
          }

          return RecordedShot.fromJson(shotMap);
        })
        .where((shot) => shot != null)
        .cast<RecordedShot>()
        .handleError((e) {
          debugPrint('[FirestoreMatchService] streamLiveShots error: $e');
        });
  }

  /// Broadcasts a courtside reaction (floating emoji or text banter) to the `live_reactions` subcollection.
  Future<void> sendLiveReaction({
    required String matchId,
    required LiveReactionEvent reaction,
  }) async {
    final cleanId = matchId.trim().toUpperCase();
    try {
      final docRef = _matchesRef.doc(cleanId).collection('live_reactions');
      await docRef.doc(reaction.id).set(reaction.toMap());
    } catch (e) {
      debugPrint('[FirestoreMatchService] sendLiveReaction error: $e');
    }
  }

  /// Streams real-time floating reactions & banter events occurring during the match.
  Stream<LiveReactionEvent> streamLiveReactions(String matchId, {int? sinceTimestampMs}) {
    if (matchId.isEmpty) return const Stream.empty();
    final cleanId = matchId.trim().toUpperCase();
    final start = sinceTimestampMs ?? (DateTime.now().millisecondsSinceEpoch - 2000);

    return _matchesRef
        .doc(cleanId)
        .collection('live_reactions')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .snapshots()
        .expand((snap) => snap.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) {
          final data = change.doc.data();
          if (data == null) return null;
          return LiveReactionEvent.fromMap(data, change.doc.id);
        })
        .where((reaction) => reaction != null)
        .cast<LiveReactionEvent>()
        .handleError((e) {
          debugPrint('[FirestoreMatchService] streamLiveReactions error: $e');
        });
  }

  /// Updates the live round score on the root match document so spectators see exact score agreement.
  Future<void> updateLiveShooterScore({
    required String matchId,
    required int currentRoundScore,
    required String shooterUid,
  }) async {
    final cleanId = matchId.trim().toUpperCase();
    try {
      await _matchesRef.doc(cleanId).update({
        'liveShooterScore': currentRoundScore,
        'liveShooterUid': shooterUid,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[FirestoreMatchService] updateLiveShooterScore error: $e');
    }
  }
}
