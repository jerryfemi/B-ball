import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';

/// Lightweight profile representation for the local player.
class UserProfile {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final bool isAnonymous;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    this.isAnonymous = true,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? avatarEmoji,
    bool? isAnonymous,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'avatarEmoji': avatarEmoji,
    'isAnonymous': isAnonymous,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uid: json['uid'] as String,
    displayName: json['displayName'] as String? ?? 'Player',
    avatarEmoji: json['avatarEmoji'] as String? ?? '🏀',
    isAnonymous: json['isAnonymous'] as bool? ?? true,
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

  final ValueNotifier<UserProfile?> currentUserNotifier =
      ValueNotifier<UserProfile?>(null);

  UserProfile? get currentUser => currentUserNotifier.value;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initializes Firebase and performs silent guest authentication.
  /// 
  /// Guaranteed never to throw or block app startup. If offline or if the
  /// Firebase Anonymous provider is not yet activated in the console,
  /// falls back to a deterministic local guest UID seamlessly.
  Future<UserProfile> initialize() async {
    if (_initialized && currentUserNotifier.value != null) {
      return currentUserNotifier.value!;
    }

    final prefs = await SharedPreferences.getInstance();
    String savedName = prefs.getString(_prefKeyName) ?? 'Baller';
    String savedAvatar = prefs.getString(_prefKeyAvatar) ?? '🏀';
    String? localGuestUid = prefs.getString(_prefKeyUid);

    // 1. Initialize Firebase Core
    bool firebaseReady = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      firebaseReady = true;
    } catch (e) {
      debugPrint('[AuthService] Firebase initialization notice: $e');
    }

    // 2. Perform Silent Guest Authentication
    String activeUid;
    bool isAnon = true;

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
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            savedName = user.displayName!;
          } else {
            // Update Firebase user profile with cached nickname
            unawaited(user.updateDisplayName(savedName));
          }
          await prefs.setString(_prefKeyUid, activeUid);
          debugPrint('[AuthService] Silent guest signed in: $activeUid');
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
    );

    currentUserNotifier.value = profile;
    _initialized = true;

    // Listen to background auth changes
    if (firebaseReady) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && currentUserNotifier.value?.uid != user.uid) {
          currentUserNotifier.value = currentUserNotifier.value?.copyWith(
            uid: user.uid,
            displayName: user.displayName ?? currentUserNotifier.value?.displayName,
            isAnonymous: user.isAnonymous,
          );
        }
      });
    }

    return profile;
  }

  /// Updates player display name and avatar emoji locally and in Firebase.
  Future<void> updateProfile({
    String? displayName,
    String? avatarEmoji,
  }) async {
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

    currentUserNotifier.value = current.copyWith(
      displayName: newName,
      avatarEmoji: newAvatar,
    );
  }

  String _getOrCreateFallbackUid(SharedPreferences prefs, String? existing) {
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newUid = 'guest_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    prefs.setString(_prefKeyUid, newUid);
    return newUid;
  }
}
