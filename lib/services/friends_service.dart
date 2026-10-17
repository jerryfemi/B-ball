import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../models/player_descriptor.dart';
import 'auth_service.dart';

/// Service managing social friends list, user discovery, and 1v1 conversation bindings.
class FriendsService {
  final AuthService? authService;

  FriendsService({this.authService}) {
    _initLocalCache();
  }
  FriendsService._internal() : authService = null {
    _initLocalCache();
  }
  static final FriendsService instance = FriendsService._internal();

  AuthService get _effectiveAuthService =>
      authService ?? AuthService.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prefFriendsCacheKey = 'bball_cached_friends_json';

  final ValueNotifier<List<FriendProfile>> friendsNotifier =
      ValueNotifier<List<FriendProfile>>([]);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<void> _initLocalCache() async {
    final cached = await getCachedFriends();
    friendsNotifier.value = cached;
  }

  /// Publishes or refreshes the current player's public profile in Firestore
  /// so friends can look them up by display name or UID.
  Future<void> publishMyProfile(UserProfile profile) async {
    try {
      await _usersRef.doc(profile.uid).set({
        'uid': profile.uid,
        'displayName': profile.displayName,
        'displayNameLower': profile.displayName.toLowerCase().trim(),
        'avatarEmoji': profile.avatarEmoji,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        // The user doc holds the friends list and high score — it must never
        // auto-expire. Actively clear any TTL left by older builds.
        'expireAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[FriendsService] Notice: could not publish public profile: $e',
      );
    }
  }

  /// Streams real-time list of friends, backed by Firestore user doc and local reactive notifier.
  Stream<List<FriendProfile>> streamFriends(String myUid) {
    if (myUid.isEmpty) {
      return friendsNotifier.value.isNotEmpty
          ? Stream.value(friendsNotifier.value)
          : Stream.value(const []);
    }

    return _usersRef
        .doc(myUid)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final rawFriends = data['friends'] as List<dynamic>?;
            if (rawFriends != null) {
              final list = rawFriends
                  .map((e) => FriendProfile.fromMap(e as Map<String, dynamic>))
                  .toList();
              list.sort(
                (a, b) =>
                    b.lastActiveTimestamp.compareTo(a.lastActiveTimestamp),
              );
              friendsNotifier.value = list;
              unawaited(_cacheFriendsLocally(list));
              return list;
            }
          }
          return friendsNotifier.value;
        })
        .handleError((error) {
          debugPrint('[FriendsService] Fallback to local friends list: $error');
          return friendsNotifier.value;
        });
  }

  /// Adds a friend to the user's social network with instant local reactivity.
  Future<void> addFriend(String myUid, FriendProfile friend) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedFriend = friend.copyWith(
      addedAt: friend.addedAt > 0 ? friend.addedAt : now,
      lastActiveTimestamp: now,
    );

    // 1. Instant local reactive update
    final currentList = [...friendsNotifier.value];
    final updatedList = [
      updatedFriend,
      ...currentList.where((f) => f.uid != friend.uid),
    ];
    friendsNotifier.value = updatedList;
    await _cacheFriendsLocally(updatedList);

    // 2. Persist to canonical Firestore user document array (single source of truth)
    if (myUid.isNotEmpty) {
      try {
        await _usersRef.doc(myUid).set({
          'friends': updatedList.map((f) => f.toMap()).toList(),
          'updatedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[FriendsService] Firestore save friends notice: $e');
      }
    }
  }

  /// Removes a friend from the user's friend list.
  Future<void> removeFriend(String myUid, String friendUid) async {
    final updatedList = friendsNotifier.value
        .where((f) => f.uid != friendUid)
        .toList();
    friendsNotifier.value = updatedList;
    await _cacheFriendsLocally(updatedList);

    if (myUid.isNotEmpty) {
      try {
        await _usersRef.doc(myUid).set({
          'friends': updatedList.map((f) => f.toMap()).toList(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Updates the linked active match or interaction timestamp for a friend.
  Future<void> updateFriendMatch({
    required String myUid,
    required String friendUid,
    required String? matchId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentList = [...friendsNotifier.value];
    final idx = currentList.indexWhere((f) => f.uid == friendUid);
    if (idx != -1) {
      currentList[idx] = currentList[idx].copyWith(
        activeMatchId: matchId,
        lastActiveTimestamp: now,
      );
      friendsNotifier.value = currentList;
      await _cacheFriendsLocally(currentList);
    }

    if (myUid.isNotEmpty) {
      try {
        await _usersRef.doc(myUid).set({
          'friends': friendsNotifier.value.map((f) => f.toMap()).toList(),
          'updatedAt': now,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Searches for potential friends by username or player tag.
  Future<List<FriendProfile>> searchUsers(
    String query,
    String excludeMyUid,
  ) async {
    final clean = query.trim().toLowerCase();
    if (clean.length < 2) return const [];

    try {
      // 1. Exact UID match
      final uidDoc = await _usersRef.doc(query.trim()).get();
      if (uidDoc.exists && uidDoc.id != excludeMyUid) {
        final data = uidDoc.data()!;
        return [
          FriendProfile(
            uid: uidDoc.id,
            displayName: data['displayName'] as String? ?? 'Player',
            avatarEmoji:
                data['avatarEmoji'] as String? ??
                PlayerDescriptor.defaultAvatar,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
      }

      // 2. Prefix search on displayNameLower
      final querySnapshot = await _usersRef
          .where('displayNameLower', isGreaterThanOrEqualTo: clean)
          .where('displayNameLower', isLessThanOrEqualTo: '$clean\uf8ff')
          .limit(8)
          .get();

      return querySnapshot.docs.where((doc) => doc.id != excludeMyUid).map((
        doc,
      ) {
        final data = doc.data();
        return FriendProfile(
          uid: doc.id,
          displayName: data['displayName'] as String? ?? 'Player',
          avatarEmoji:
              data['avatarEmoji'] as String? ??
              PlayerDescriptor.defaultAvatar,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }).toList();
    } catch (e) {
      debugPrint('[FriendsService] Search users error: $e');
      return const [];
    }
  }

  /// Sends a friend invite from the current player to [targetUid].
  Future<void> sendFriendInvite({
    required String targetUid,
    required UserProfile myProfile,
  }) async {
    final invite = FriendInvite(
      senderUid: myProfile.uid,
      senderName: myProfile.displayName,
      senderAvatar: myProfile.avatarEmoji,
      status: 'pending',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _usersRef
        .doc(targetUid)
        .collection('invites')
        .doc(myProfile.uid)
        .set(invite.toMap());
  }

  /// Streams incoming friend invites for the current player.
  /// Automatically finalizes reciprocal acceptances if encountered.
  Stream<List<FriendInvite>> streamIncomingInvites(String myUid) {
    if (myUid.isEmpty) return Stream.value(const []);
    return _usersRef
        .doc(myUid)
        .collection('invites')
        .snapshots()
        .map((snap) {
          final list = <FriendInvite>[];
          for (final doc in snap.docs) {
            final inv = FriendInvite.fromMap(doc.data(), doc.id);
            if (inv.status == 'accepted') {
              // Reciprocal confirmation from other player: add them to my friends list
              final friend = FriendProfile(
                uid: inv.senderUid,
                displayName: inv.senderName,
                avatarEmoji: inv.senderAvatar,
                addedAt: DateTime.now().millisecondsSinceEpoch,
              );
              unawaited(addFriend(myUid, friend));
              unawaited(doc.reference.delete().catchError((_) {}));
            } else {
              list.add(inv);
            }
          }
          return list;
        })
        .handleError((e) {
          debugPrint('[FriendsService] Stream invites notice: $e');
          return const <FriendInvite>[];
        });
  }

  /// Accepts an incoming friend invite, adds them to my friends list,
  /// notifies the sender so they also reciprocate, and deletes the invite.
  Future<void> acceptFriendInvite(
    String myUid,
    FriendInvite invite, {
    UserProfile? myProfile,
  }) async {
    final effectiveProfile = myProfile ?? _effectiveAuthService.currentUser;
    final friend = FriendProfile(
      uid: invite.senderUid,
      displayName: invite.senderName,
      avatarEmoji: invite.senderAvatar,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await addFriend(myUid, friend);

    // Order matters: the reciprocal "accepted" note must be written while the
    // original pending invite still exists in MY inbox — Firestore rules check
    // for it, so nobody can forge an "accepted" invite into someone's inbox.
    if (effectiveProfile != null) {
      try {
        final reciprocate = FriendInvite(
          senderUid: myUid,
          senderName: effectiveProfile.displayName,
          senderAvatar: effectiveProfile.avatarEmoji,
          status: 'accepted',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await _usersRef
            .doc(invite.senderUid)
            .collection('invites')
            .doc(myUid)
            .set(reciprocate.toMap());
      } catch (e) {
        debugPrint('[FriendsService] Reciprocate friend acceptance notice: $e');
      }
    }

    try {
      await _usersRef
          .doc(myUid)
          .collection('invites')
          .doc(invite.senderUid)
          .delete();
    } catch (_) {}
  }

  /// Declines and discards an incoming friend invite.
  Future<void> declineFriendInvite(String myUid, String senderUid) async {
    try {
      await _usersRef.doc(myUid).collection('invites').doc(senderUid).delete();
    } catch (_) {}
  }

  Future<void> _cacheFriendsLocally(List<FriendProfile> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = friends.map((f) => f.toMap()).toList();
      await prefs.setString(_prefFriendsCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<FriendProfile>> getCachedFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefFriendsCacheKey);
      if (str == null || str.isEmpty) return const [];
      final decoded = jsonDecode(str) as List<dynamic>;
      return decoded
          .map((e) => FriendProfile.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String getConversationId(String uid1, String uid2) =>
      (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';

  /// How many recent direct messages a conversation view loads.
  static const int directChatWindow = 100;

  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      _firestore.collection('conversations');

  /// Sends a direct banter/chat message between two friends.
  ///
  /// Each message is its own document in `conversations/{convId}/messages`,
  /// mirroring how match chat works. The root `conversations/{convId}` doc only
  /// carries lightweight metadata for inbox badges, so it can never approach
  /// Firestore's 1 MB document cap and badge listeners never download history.
  Future<void> sendDirectMessage({
    required String fromUid,
    required String toUid,
    required CloudChatMessage message,
  }) async {
    final convId = getConversationId(fromUid, toUid);
    final convRef = _conversationsRef.doc(convId);
    final ttl7Days = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );

    try {
      // Root first: the messages rule checks `participants` on this doc.
      await convRef.set({
        'participants': [fromUid, toUid],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'lastMsgSenderUid': fromUid,
        'lastMsgTimestamp': message.timestamp,
        'lastMsgText': message.text,
        'expireAt': ttl7Days,
      }, SetOptions(merge: true));

      await convRef.collection('messages').doc(message.id).set({
        ...message.toMap(),
        'expireAt': ttl7Days,
      });
    } catch (e) {
      debugPrint('[FriendsService] Send direct message error: $e');
    }
  }

  /// Streams direct conversation banter between two players in real time.
  ///
  /// Reads the latest [directChatWindow] messages from the `messages`
  /// subcollection. Conversations created by older builds still keep their
  /// messages in a root `chat` array; those are merged in (de-duplicated by id)
  /// until the 7-day conversation TTL retires them.
  Stream<List<CloudChatMessage>> streamDirectChat({
    required String myUid,
    required String friendUid,
  }) {
    final convRef = _conversationsRef.doc(getConversationId(myUid, friendUid));

    List<CloudChatMessage> legacy = const [];
    List<CloudChatMessage> current = const [];
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? rootSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? msgSub;
    late final StreamController<List<CloudChatMessage>> controller;

    void emit() {
      if (controller.isClosed) return;
      final byId = <String, CloudChatMessage>{};
      for (final m in legacy) {
        byId[m.id] = m;
      }
      for (final m in current) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      controller.add(merged);
    }

    controller = StreamController<List<CloudChatMessage>>(
      onListen: () {
        rootSub = convRef.snapshots().listen(
          (doc) {
            final rawChat = doc.data()?['chat'] as List<dynamic>?;
            legacy = rawChat == null
                ? const []
                : rawChat
                      .map((e) =>
                          CloudChatMessage.fromMap(e as Map<String, dynamic>))
                      .toList();
            emit();
          },
          onError: (Object e) {
            debugPrint('[FriendsService] Stream direct chat root error: $e');
            emit();
          },
        );
        msgSub = convRef
            .collection('messages')
            .orderBy('timestamp')
            .limitToLast(directChatWindow)
            .snapshots()
            .listen(
              (snap) {
                current = snap.docs
                    .map((d) => CloudChatMessage.fromMap(d.data()))
                    .toList();
                emit();
              },
              onError: (Object e) {
                debugPrint('[FriendsService] Stream direct chat error: $e');
                emit();
              },
            );
      },
      onCancel: () async {
        await rootSub?.cancel();
        await msgSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Streams metadata for all direct conversations involving [myUid].
  ///
  /// Reads only root metadata fields; the legacy `chat` array is consulted
  /// solely as a fallback for conversations written by older builds.
  Stream<List<DirectConversationSummary>> streamUserConversations(String myUid) {
    if (myUid.isEmpty) return Stream.value(const []);
    return _conversationsRef
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final participants = (data['participants'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final otherUid = participants.firstWhere(
                (p) => p != myUid,
                orElse: () => '',
              );
              CloudChatMessage? legacyLast;
              final rawChat = data['chat'] as List<dynamic>?;
              if (rawChat != null && rawChat.isNotEmpty) {
                legacyLast = CloudChatMessage.fromMap(
                  rawChat.last as Map<String, dynamic>,
                );
              }
              final lastSenderUid = data['lastMsgSenderUid'] as String? ??
                  legacyLast?.senderUid ??
                  '';
              final lastTimestamp =
                  (data['lastMsgTimestamp'] as num?)?.toInt() ??
                      legacyLast?.timestamp ??
                      (data['updatedAt'] as num?)?.toInt() ??
                      0;
              return DirectConversationSummary(
                id: doc.id,
                friendUid: otherUid,
                lastSenderUid: lastSenderUid,
                lastTimestamp: lastTimestamp,
                lastMessageText:
                    data['lastMsgText'] as String? ?? legacyLast?.text,
              );
            }).toList())
        .handleError((e) {
          debugPrint('[FriendsService] Stream user conversations error: $e');
          return const <DirectConversationSummary>[];
        });
  }
}

/// Lightweight summary of a direct friend conversation for notification badging.
class DirectConversationSummary {
  final String id;
  final String friendUid;
  final String lastSenderUid;
  final int lastTimestamp;
  final String? lastMessageText;

  const DirectConversationSummary({
    required this.id,
    required this.friendUid,
    required this.lastSenderUid,
    required this.lastTimestamp,
    this.lastMessageText,
  });
}
