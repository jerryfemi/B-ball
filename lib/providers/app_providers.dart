import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../models/match_invite.dart';
import '../services/auth_service.dart';
import '../services/chat_read_receipt_service.dart';
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

/// Streams pending incoming 1v1 match challenges dispatched by friends.
final incomingMatchChallengesProvider = StreamProvider.autoDispose<List<MatchInvite>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <MatchInvite>[]);
  }
  final matchService = ref.watch(matchServiceProvider);
  return matchService.streamIncomingMatchChallenges(user.uid);
});

// ==========================================
// 5. Computed Notification Alerts Provider
// ==========================================

/// Local chat read receipts provider to trigger reactive unread badges.
final chatReadReceiptServiceProvider = Provider<ChatReadReceiptService>((ref) {
  return ChatReadReceiptService.instance;
});

/// Reactive stream that increments on any read receipt update, forcing consumers to re-evaluate.
final chatReadVersionProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>();
  int version = 0;
  void listener() {
    version++;
    if (!controller.isClosed) {
      controller.add(version);
    }
  }
  ChatReadReceiptService.instance.addListener(listener);
  ref.onDispose(() {
    ChatReadReceiptService.instance.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

/// Streams metadata for all direct conversations of the current user.
final userDirectConversationsProvider =
    StreamProvider.autoDispose<List<DirectConversationSummary>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) {
    return Stream.value(const <DirectConversationSummary>[]);
  }
  final friendsService = ref.watch(friendsServiceProvider);
  return friendsService.streamUserConversations(user.uid);
});

/// Priority alert type for the top scoreboard player avatar.
enum ScoreboardAlertType {
  none,
  turnWaiting,
  challenge,
  chat,
}

/// Comprehensive alert state detailing counts and current visual priority.
class ScoreboardAlertState {
  final ScoreboardAlertType alertType;
  final int totalCount;
  final int turnCount;
  final int challengeCount;
  final int chatCount;

  const ScoreboardAlertState({
    required this.alertType,
    required this.totalCount,
    required this.turnCount,
    required this.challengeCount,
    required this.chatCount,
  });

  static const empty = ScoreboardAlertState(
    alertType: ScoreboardAlertType.none,
    totalCount: 0,
    turnCount: 0,
    challengeCount: 0,
    chatCount: 0,
  );
}

/// Computes contextual alert breakdown with strict priority hierarchy:
/// Gameplay Turn (Cyan) > Friend Challenge (Amber) > Unread Chat (Red).
final scoreboardAlertStateProvider =
    Provider.autoDispose.family<ScoreboardAlertState, String?>((ref, activeMatchId) {
  ref.watch(chatReadVersionProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) return ScoreboardAlertState.empty;

  final readReceipts = ref.watch(chatReadReceiptServiceProvider);
  final invites = ref.watch(incomingInvitesProvider).value ?? const [];
  final challenges = ref.watch(incomingMatchChallengesProvider).value ?? const [];
  final matches = ref.watch(userMatchesProvider).value ?? const [];
  final conversations =
      ref.watch(userDirectConversationsProvider).value ?? const [];

  final turnCount = matches
      .where(
        (m) =>
            m.status == MatchStatus.active &&
            m.isMyTurn(user.uid) &&
            (activeMatchId == null || m.id != activeMatchId),
      )
      .length;

  final challengeCount = invites.length + challenges.length;

  // Unread match banter
  final unreadMatchChatCount = matches.where((m) {
    if (activeMatchId != null && m.id == activeMatchId) return false;
    final lastRead = readReceipts.getMatchLastRead(m.id);
    return m.hasUnreadChat(user.uid, lastRead);
  }).length;

  // Unread direct banter
  final unreadDirectChatCount = conversations.where((c) {
    if (c.lastSenderUid == user.uid || c.friendUid.isEmpty) return false;
    final lastRead = readReceipts.getFriendChatLastRead(c.friendUid);
    return c.lastTimestamp > lastRead;
  }).length;

  final chatCount = unreadMatchChatCount + unreadDirectChatCount;
  final totalCount = turnCount + challengeCount + chatCount;

  ScoreboardAlertType alertType = ScoreboardAlertType.none;
  if (turnCount > 0) {
    alertType = ScoreboardAlertType.turnWaiting;
  } else if (challengeCount > 0) {
    alertType = ScoreboardAlertType.challenge;
  } else if (chatCount > 0) {
    alertType = ScoreboardAlertType.chat;
  }

  return ScoreboardAlertState(
    alertType: alertType,
    totalCount: totalCount,
    turnCount: turnCount,
    challengeCount: challengeCount,
    chatCount: chatCount,
  );
});

/// Computes the total pending action alerts (invites + turns waiting + unread banter)
/// for displaying on player badges and hubs, excluding any actively displayed match.
final userAlertsCountProvider =
    Provider.autoDispose.family<int, String?>((ref, activeMatchId) {
  return ref.watch(scoreboardAlertStateProvider(activeMatchId)).totalCount;
});

/// Total badge count for the FRIENDS button in MatchInboxSheet (invites + challenges + unread DMs).
final friendsBadgeCountProvider = Provider.autoDispose<int>((ref) {
  ref.watch(chatReadVersionProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty) return 0;

  final readReceipts = ref.watch(chatReadReceiptServiceProvider);
  final invites = ref.watch(incomingInvitesProvider).value ?? const [];
  final challenges = ref.watch(incomingMatchChallengesProvider).value ?? const [];
  final conversations =
      ref.watch(userDirectConversationsProvider).value ?? const [];

  final unreadDirectChats = conversations.where((c) {
    if (c.lastSenderUid == user.uid || c.friendUid.isEmpty) return false;
    final lastRead = readReceipts.getFriendChatLastRead(c.friendUid);
    return c.lastTimestamp > lastRead;
  }).length;

  return invites.length + challenges.length + unreadDirectChats;
});

/// Determines if a specific friend has sent an unread direct banter message.
final friendHasUnreadMessageProvider =
    Provider.autoDispose.family<bool, String>((ref, friendUid) {
  ref.watch(chatReadVersionProvider);
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.uid.isEmpty || friendUid.isEmpty) return false;

  final readReceipts = ref.watch(chatReadReceiptServiceProvider);
  final conversations =
      ref.watch(userDirectConversationsProvider).value ?? const [];

  final conv = conversations.firstWhere(
    (c) => c.friendUid == friendUid,
    orElse: () => const DirectConversationSummary(
      id: '',
      friendUid: '',
      lastSenderUid: '',
      lastTimestamp: 0,
    ),
  );

  if (conv.id.isEmpty || conv.lastSenderUid == user.uid) return false;
  final lastRead = readReceipts.getFriendChatLastRead(friendUid);
  return conv.lastTimestamp > lastRead;
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

/// Streams real-time match chat from the lightweight messages subcollection.
/// Decoupled from match document telemetry to prevent re-downloading shot data.
final matchChatProvider = StreamProvider.autoDispose.family<
    List<CloudChatMessage>, String>((ref, matchId) {
  if (matchId.isEmpty) return Stream.value(const <CloudChatMessage>[]);
  final matchService = ref.watch(matchServiceProvider);
  return matchService.streamMatchChat(matchId);
});
