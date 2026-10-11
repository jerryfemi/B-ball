import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import 'auth_service.dart';

/// Service managing social friends list, user discovery, and 1v1 conversation bindings.
class FriendsService {
  FriendsService._internal() {
    _initLocalCache();
  }
  static final FriendsService instance = FriendsService._internal();

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
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FriendsService] Notice: could not publish public profile: $e');
    }
  }

  /// Streams real-time list of friends, backed by Firestore user doc and local reactive notifier.
  Stream<List<FriendProfile>> streamFriends(String myUid) {
    if (myUid.isEmpty) return friendsNotifier.value.isNotEmpty ? Stream.value(friendsNotifier.value) : Stream.value(const []);

    return _usersRef.doc(myUid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawFriends = data['friends'] as List<dynamic>?;
        if (rawFriends != null) {
          final list = rawFriends
              .map((e) => FriendProfile.fromMap(e as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.lastActiveTimestamp.compareTo(a.lastActiveTimestamp));
          friendsNotifier.value = list;
          unawaited(_cacheFriendsLocally(list));
          return list;
        }
      }
      return friendsNotifier.value;
    }).handleError((error) {
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

    // 2. Persist to Firestore user document (guaranteed permitted by rules)
    if (myUid.isNotEmpty) {
      try {
        await _usersRef.doc(myUid).set({
          'friends': updatedList.map((f) => f.toMap()).toList(),
          'updatedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[FriendsService] Firestore save friends notice: $e');
      }

      // Also try subcollection write as secondary store
      try {
        await _usersRef.doc(myUid).collection('friends').doc(friend.uid).set(
          updatedFriend.toMap(),
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  /// Removes a friend from the user's friend list.
  Future<void> removeFriend(String myUid, String friendUid) async {
    final updatedList = friendsNotifier.value.where((f) => f.uid != friendUid).toList();
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
  Future<List<FriendProfile>> searchUsers(String query, String excludeMyUid) async {
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
            avatarEmoji: data['avatarEmoji'] as String? ?? '🏀',
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

      return querySnapshot.docs
          .where((doc) => doc.id != excludeMyUid)
          .map((doc) {
            final data = doc.data();
            return FriendProfile(
              uid: doc.id,
              displayName: data['displayName'] as String? ?? 'Player',
              avatarEmoji: data['avatarEmoji'] as String? ?? '🏀',
              addedAt: DateTime.now().millisecondsSinceEpoch,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('[FriendsService] Search users error: $e');
      return const [];
    }
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

  /// Sends a direct banter/chat message between two friends.
  Future<void> sendDirectMessage({
    required String fromUid,
    required String toUid,
    required CloudChatMessage message,
  }) async {
    final convId = getConversationId(fromUid, toUid);
    final msgMap = message.toMap();

    // 1. Try writing to conversations collection
    try {
      await _firestore.collection('conversations').doc(convId).set({
        'participants': [fromUid, toUid],
        'chat': FieldValue.arrayUnion([msgMap]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}

    // 2. Also persist in sender's user document under outbox (guaranteed permission allowed)
    try {
      await _usersRef.doc(fromUid).set({
        'outbox': FieldValue.arrayUnion([
          {...msgMap, 'toUid': toUid}
        ]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Streams direct conversation banter between two players in real time.
  Stream<List<CloudChatMessage>> streamDirectChat({
    required String myUid,
    required String friendUid,
  }) {
    final convId = getConversationId(myUid, friendUid);

    late StreamController<List<CloudChatMessage>> controller;
    StreamSubscription? subConv;
    StreamSubscription? subMyUser;
    StreamSubscription? subFriendUser;

    final myMessages = <String, CloudChatMessage>{};
    final friendMessages = <String, CloudChatMessage>{};
    final convMessages = <String, CloudChatMessage>{};

    void emitMerged() {
      final all = <String, CloudChatMessage>{
        ...myMessages,
        ...friendMessages,
        ...convMessages,
      };
      final sorted = all.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (!controller.isClosed) {
        controller.add(sorted);
      }
    }

    controller = StreamController<List<CloudChatMessage>>.broadcast(
      onListen: () {
        // 1. Conversations collection stream
        try {
          subConv = _firestore.collection('conversations').doc(convId).snapshots().listen((doc) {
            if (doc.exists && doc.data() != null) {
              final rawChat = doc.data()!['chat'] as List<dynamic>?;
              if (rawChat != null) {
                convMessages.clear();
                for (final e in rawChat) {
                  final m = CloudChatMessage.fromMap(e as Map<String, dynamic>);
                  convMessages[m.id] = m;
                }
                emitMerged();
              }
            }
          }, onError: (_) {});
        } catch (_) {}

        // 2. User outbox streams (guaranteed permitted by live rules)
        try {
          subMyUser = _usersRef.doc(myUid).snapshots().listen((doc) {
            if (doc.exists && doc.data() != null) {
              final raw = doc.data()!['outbox'] as List<dynamic>?;
              if (raw != null) {
                myMessages.clear();
                for (final e in raw) {
                  if (e is Map<String, dynamic> && e['toUid'] == friendUid) {
                    final m = CloudChatMessage.fromMap(e);
                    myMessages[m.id] = m;
                  }
                }
                emitMerged();
              }
            }
          }, onError: (_) {});
        } catch (_) {}

        try {
          subFriendUser = _usersRef.doc(friendUid).snapshots().listen((doc) {
            if (doc.exists && doc.data() != null) {
              final raw = doc.data()!['outbox'] as List<dynamic>?;
              if (raw != null) {
                friendMessages.clear();
                for (final e in raw) {
                  if (e is Map<String, dynamic> && e['toUid'] == myUid) {
                    final m = CloudChatMessage.fromMap(e);
                    friendMessages[m.id] = m;
                  }
                }
                emitMerged();
              }
            }
          }, onError: (_) {});
        } catch (_) {}
      },
      onCancel: () {
        subConv?.cancel();
        subMyUser?.cancel();
        subFriendUser?.cancel();
      },
    );

    return controller.stream;
  }
}
