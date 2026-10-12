import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'friends_service.dart';

/// Exception thrown when an online feature is attempted without valid Firebase authentication.
class AuthRequiredException implements Exception {
  final String message;
  const AuthRequiredException(this.message);

  @override
  String toString() => message;
}

/// Lightweight profile representation for the local player.
class UserProfile {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final bool isAnonymous;
  final bool isFirebaseVerified;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    this.isAnonymous = true,
    this.isFirebaseVerified = false,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? avatarEmoji,
    bool? isAnonymous,
    bool? isFirebaseVerified,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isFirebaseVerified: isFirebaseVerified ?? this.isFirebaseVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'avatarEmoji': avatarEmoji,
    'isAnonymous': isAnonymous,
    'isFirebaseVerified': isFirebaseVerified,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uid: json['uid'] as String,
    displayName: json['displayName'] as String? ?? 'Player',
    avatarEmoji:
        json['avatarEmoji'] as String? ?? 'assets/avatars/dunk_heads (1).webp',
    isAnonymous: json['isAnonymous'] as bool? ?? true,
    isFirebaseVerified: json['isFirebaseVerified'] as bool? ?? false,
  );
}

/// Service handling silent background guest authentication,
/// local profile persistence, and reactive auth state updates.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const String _prefKeyUid = 'bball_local_guest_uid';
  static const String _prefKeyName = 'bball_player_name';
  static const String _prefKeyAvatar = 'bball_player_avatar';

  /// Real avatar assets available in the game
  static const List<String> avatarImageOptions = [
    'assets/avatars/dunk_heads (1).webp',
    'assets/avatars/dunk_heads (2).webp',
    'assets/avatars/dunk_heads (3).webp',
    'assets/avatars/dunk_heads (4).webp',
    'assets/avatars/dunk_heads (5).webp',
    'assets/avatars/dunk_heads (6).webp',
    'assets/avatars/dunk_heads (7).webp',
    'assets/avatars/dunk_heads (8).webp',
    'assets/avatars/dunk_heads (9).webp',
    'assets/avatars/dunk_heads (10).webp',
    'assets/avatars/dunk_heads (11).webp',
    'assets/avatars/dunk_heads (12).webp',
    'assets/avatars/dunk_heads (13).webp',
    'assets/avatars/dunk_heads (14).webp',
    'assets/avatars/dunk_heads (15).webp',
  ];

  static String getRandomAvatar() {
    final rand = Random();
    return avatarImageOptions[rand.nextInt(avatarImageOptions.length)];
  }

  final ValueNotifier<UserProfile?> currentUserNotifier =
      ValueNotifier<UserProfile?>(null);

  UserProfile? get currentUser => currentUserNotifier.value;

  /// Whether the user is confirmed and authenticated with Firebase Auth.
  bool get isAuthenticatedWithFirebase =>
      FirebaseAuth.instance.currentUser != null;

  Future<UserProfile>? _initFuture;

  /// Initializes Firebase and performs silent guest authentication.
  ///
  /// Caches the initialization Future so concurrent calls await the exact
  /// same operation, preventing duplicate anonymous user creation.
  Future<UserProfile> initialize() {
    return _initFuture ??= _doInitialize();
  }

  /// Generates a unique basketball gamer tag (e.g. "Baller#4829", "Hooper#7182").
  static String generateUniqueGamerTag() {
    const monikers = [
      'Baller',
      'Hooper',
      'Rookie',
      'Bucket',
      'Playmaker',
      'Dunker',
      'Swish',
    ];
    final rand = Random();
    final moniker = monikers[rand.nextInt(monikers.length)];
    final code = rand.nextInt(9000) + 1000;
    return '$moniker#$code';
  }

  Future<UserProfile> _doInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawName = prefs.getString(_prefKeyName);
    String savedName;
    if (rawName == null || rawName.isEmpty || rawName == 'Baller') {
      savedName = generateUniqueGamerTag();
      await prefs.setString(_prefKeyName, savedName);
    } else {
      savedName = rawName;
    }
    final rawAvatar = prefs.getString(_prefKeyAvatar);
    String savedAvatar;
    if (rawAvatar == null || !rawAvatar.startsWith('assets/')) {
      savedAvatar = getRandomAvatar();
      await prefs.setString(_prefKeyAvatar, savedAvatar);
    } else {
      savedAvatar = rawAvatar;
    }
    String? localGuestUid = prefs.getString(_prefKeyUid);

    // 1. Ensure Firebase Core is ready
    bool firebaseReady = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      firebaseReady = true;
    } catch (e) {
      debugPrint('[AuthService] Firebase Core initialization notice: $e');
    }

    // 2. Perform Silent Guest Authentication
    String activeUid;
    bool isAnon = true;
    bool isVerified = false;

    if (firebaseReady) {
      try {
        final auth = FirebaseAuth.instance;
        User? user = auth.currentUser;

        if (user == null) {
          debugPrint('[AuthService] Performing silent anonymous sign-in...');
          final cred = await auth.signInAnonymously();
          user = cred.user;
        }

        if (user != null) {
          activeUid = user.uid;
          isAnon = user.isAnonymous;
          isVerified = true;

          if (user.displayName != null &&
              user.displayName!.isNotEmpty &&
              user.displayName != 'Baller') {
            savedName = user.displayName!;
            await prefs.setString(_prefKeyName, savedName);
          } else {
            unawaited(user.updateDisplayName(savedName));
          }
          await prefs.setString(_prefKeyUid, activeUid);
          debugPrint(
            '[AuthService] Silent guest signed in: $activeUid ($savedName)',
          );
        } else {
          activeUid = _getOrCreateFallbackUid(prefs, localGuestUid);
        }
      } catch (e) {
        debugPrint(
          '[AuthService] Silent sign-in fallback active (Tip: ensure Anonymous auth is enabled in Firebase Console): $e',
        );
        activeUid = _getOrCreateFallbackUid(prefs, localGuestUid);
      }
    } else {
      activeUid = _getOrCreateFallbackUid(prefs, localGuestUid);
    }

    final profile = UserProfile(
      uid: activeUid,
      displayName: savedName,
      avatarEmoji: savedAvatar,
      isAnonymous: isAnon,
      isFirebaseVerified: isVerified,
    );

    currentUserNotifier.value = profile;
    if (isVerified) {
      unawaited(FriendsService.instance.publishMyProfile(profile));
    }

    // Listen to background auth changes
    if (firebaseReady) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && currentUserNotifier.value?.uid != user.uid) {
          currentUserNotifier.value = currentUserNotifier.value?.copyWith(
            uid: user.uid,
            displayName:
                user.displayName ?? currentUserNotifier.value?.displayName,
            isAnonymous: user.isAnonymous,
            isFirebaseVerified: true,
          );
        }
      });
    }

    return profile;
  }

  /// Ensures a valid Firebase user exists before performing online operations.
  /// Throws [AuthRequiredException] if unauthenticated and offline.
  Future<User> ensureAuthenticated() async {
    await initialize();
    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    if (user != null) return user;

    try {
      final cred = await auth.signInAnonymously();
      if (cred.user != null) {
        currentUserNotifier.value = currentUserNotifier.value?.copyWith(
          uid: cred.user!.uid,
          isFirebaseVerified: true,
        );
        return cred.user!;
      }
    } catch (e) {
      throw AuthRequiredException(
        'Online multiplayer requires an active internet connection ($e).',
      );
    }

    throw const AuthRequiredException(
      'Unable to establish anonymous session with Firebase.',
    );
  }

  /// Updates player display name and avatar emoji locally and in Firebase.
  Future<void> updateProfile({String? displayName, String? avatarEmoji}) async {
    final current = currentUserNotifier.value;
    if (current == null) return;

    final newName = displayName ?? current.displayName;
    final newAvatar = avatarEmoji ?? current.avatarEmoji;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyName, newName);
    await prefs.setString(_prefKeyAvatar, newAvatar);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && displayName != null) {
        await user.updateDisplayName(newName);
      }
    } catch (_) {}

    final updated = current.copyWith(
      displayName: newName,
      avatarEmoji: newAvatar,
    );
    currentUserNotifier.value = updated;
    unawaited(FriendsService.instance.publishMyProfile(updated));
  }

  /// Links the anonymous guest account with a permanent credential (Google, Email, etc.)
  Future<UserCredential?> linkWithCredential(AuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final cred = await user.linkWithCredential(credential);
    currentUserNotifier.value = currentUserNotifier.value?.copyWith(
      isAnonymous: cred.user?.isAnonymous ?? false,
      isFirebaseVerified: true,
    );
    return cred;
  }

  String _getOrCreateFallbackUid(SharedPreferences prefs, String? existing) {
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newUid =
        'guest_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    prefs.setString(_prefKeyUid, newUid);
    return newUid;
  }
}
