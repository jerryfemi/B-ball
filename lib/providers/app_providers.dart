import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_match_service.dart';
import '../services/friends_service.dart';

// ==========================================
// 1. Core Services Providers
// ==========================================

/// Core authentication service provider.
final authServiceProvider = Provider<AuthService>((ref) => AuthService.instance);

/// Core social friends service provider.
final friendsServiceProvider = Provider<FriendsService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FriendsService(authService: authService);
});

/// Central Firestore match service provider.
final matchServiceProvider = Provider<FirestoreMatchService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final friendsService = ref.watch(friendsServiceProvider);
  return FirestoreMatchService(
    authService: authService,
    friendsService: friendsService,
  );
});

// ==========================================
// 2. Reactive Auth State Stream Provider
// ==========================================

/// Emits the active [UserProfile] whenever the user signs in or modifies their avatar/name.
final currentUserProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final controller = StreamController<UserProfile?>();

  controller.add(authService.currentUser);

  void listener() {
    if (!controller.isClosed) {
      controller.add(authService.currentUser);
    }
  }

  authService.currentUserNotifier.addListener(listener);

  ref.onDispose(() {
    authService.currentUserNotifier.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

// ==========================================
// 3. User Matches Stream Provider
// ==========================================

/// Streams all remote matches (active and completed) for the authenticated player.
final userMatchesProvider = StreamProvider.autoDispose<List<CloudMatch>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <CloudMatch>[]);
  }
  final matchService = ref.watch(matchServiceProvider);
  return matchService.streamUserMatches(user.uid);
});

// ==========================================
// 4. Social Friends & Invites Stream Providers
// ==========================================

/// Streams the real-time social friends list for the authenticated player.
final friendsListProvider = StreamProvider.autoDispose<List<FriendProfile>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <FriendProfile>[]);
  }
  final friendsService = ref.watch(friendsServiceProvider);
  return friendsService.streamFriends(user.uid);
});

/// Streams pending incoming friend invites.
final incomingInvitesProvider = StreamProvider.autoDispose<List<FriendInvite>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <FriendInvite>[]);
  }
  final friendsService = ref.watch(friendsServiceProvider);
  return friendsService.streamIncomingInvites(user.uid);
});

// ==========================================
// 5. Computed Notification Alerts Provider
// ==========================================

/// Computes the total pending action alerts (invites + turns waiting + unread banter)
/// for displaying on player badges and hubs, excluding any actively displayed match.
final userAlertsCountProvider = Provider.autoDispose.family<int, String?>((ref, activeMatchId) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) return 0;

  final invites = ref.watch(incomingInvitesProvider).value ?? const [];
  final matches = ref.watch(userMatchesProvider).value ?? const [];

  final turnsWaiting = matches
      .where(
        (m) =>
            m.isMyTurn(user.uid) &&
            m.status != MatchStatus.completed &&
            (activeMatchId == null || m.id != activeMatchId),
      )
      .length;

  final chatAlerts = matches.where((m) {
    if (activeMatchId != null && m.id == activeMatchId) return false;
    if (m.chat.isEmpty) return false;
    final lastMsg = m.chat.last;
    return lastMsg.senderUid != user.uid;
  }).length;

  return turnsWaiting + invites.length + chatAlerts;
});

/// Streams a specific match by ID.
final singleMatchProvider = StreamProvider.autoDispose.family<CloudMatch?, String>((ref, matchId) {
  if (matchId.isEmpty) return Stream.value(null);
  final matchService = ref.watch(matchServiceProvider);
  return matchService.streamMatch(matchId);
});

/// Streams direct banter messages between the user and a friend.
final directChatProvider = StreamProvider.autoDispose.family<
    List<CloudChatMessage>,
    ({String myUid, String friendUid})>((ref, arg) {
  if (arg.myUid.isEmpty || arg.friendUid.isEmpty) {
    return Stream.value(const <CloudChatMessage>[]);
  }
  final friendsService = ref.watch(friendsServiceProvider);
  return friendsService.streamDirectChat(
    myUid: arg.myUid,
    friendUid: arg.friendUid,
  );
});
