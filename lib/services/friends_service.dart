import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/friend_profile.dart';
import 'auth_service.dart';

/// Service managing social friends list, user discovery, and 1v1 conversation bindings.
class FriendsService {
  FriendsService._internal();
  static final FriendsService instance = FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prefFriendsCacheKey = 'bball_cached_friends_json';

  CollectionReference<Map<String, dynamic>> _userFriendsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

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

  /// Streams real-time list of friends, falling back to local cache if offline.
  Stream<List<FriendProfile>> streamFriends(String myUid) {
    if (myUid.isEmpty) return Stream.value(const []);

    return _userFriendsRef(myUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => FriendProfile.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => b.lastActiveTimestamp.compareTo(a.lastActiveTimestamp));
          unawaited(_cacheFriendsLocally(list));
          return list;
        })
        .handleError((error) {
          debugPrint('[FriendsService] Stream error, loading cached friends: $error');
          return getCachedFriends();
        });
  }

  /// Adds a friend to the user's social network.
  Future<void> addFriend(String myUid, FriendProfile friend) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedFriend = friend.copyWith(
      addedAt: friend.addedAt > 0 ? friend.addedAt : now,
      lastActiveTimestamp: now,
    );

    try {
      await _userFriendsRef(myUid).doc(friend.uid).set(
        updatedFriend.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FriendsService] Firestore addFriend error: $e');
    }

    final cached = await getCachedFriends();
    final updatedList = [
      updatedFriend,
      ...cached.where((f) => f.uid != friend.uid),
    ];
    await _cacheFriendsLocally(updatedList);
  }

  /// Removes a friend from the user's friend list.
  Future<void> removeFriend(String myUid, String friendUid) async {
    try {
      await _userFriendsRef(myUid).doc(friendUid).delete();
    } catch (e) {
      debugPrint('[FriendsService] Firestore removeFriend error: $e');
    }

    final cached = await getCachedFriends();
    await _cacheFriendsLocally(cached.where((f) => f.uid != friendUid).toList());
  }

  /// Updates the linked active match or interaction timestamp for a friend.
  Future<void> updateFriendMatch({
    required String myUid,
    required String friendUid,
    required String? matchId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _userFriendsRef(myUid).doc(friendUid).set({
        'activeMatchId': matchId,
        'lastActiveTimestamp': now,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FriendsService] Could not update friend match status: $e');
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
}
