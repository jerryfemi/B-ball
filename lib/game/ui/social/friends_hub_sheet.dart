import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import 'add_friend_dialog.dart';
import 'components/friend_card_tile.dart';
import 'components/friend_invite_tile.dart';
import 'edit_gamer_tag_dialog.dart';
import 'friend_conversation_sheet.dart';
import '../common/app_avatar.dart';
import '../common/app_modal_sheet.dart';

/// Dedicated Friends Management sheet for launching 1v1 challenges and banter chat.
class FriendsHubSheet extends StatefulWidget {
  final ValueChanged<CloudMatch> onPlayMatch;
  final VoidCallback onCreateMatch;
  final ValueChanged<CloudMatch>? onViewPodium;

  const FriendsHubSheet({
    super.key,
    required this.onPlayMatch,
    required this.onCreateMatch,
    this.onViewPodium,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CloudMatch> onPlayMatch,
    required VoidCallback onCreateMatch,
    ValueChanged<CloudMatch>? onViewPodium,
  }) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => FriendsHubSheet(
        onPlayMatch: onPlayMatch,
        onCreateMatch: onCreateMatch,
        onViewPodium: onViewPodium,
      ),
    );
  }

  @override
  State<FriendsHubSheet> createState() => _FriendsHubSheetState();
}

class _FriendsHubSheetState extends State<FriendsHubSheet> {
  void _openAddFriend(Set<String> existingUids) {
    HapticFeedback.lightImpact();
    AddFriendDialog.show(context, existingFriendUids: existingUids);
  }

  void _openConversation(
    FriendProfile friend,
    String myUid,
    CloudMatch? match,
  ) {
    HapticFeedback.lightImpact();
    FriendConversationSheet.show(
      context,
      friend: friend,
      myUid: myUid,
      activeMatch: match,
      onPlayTurn: (m) {
        Navigator.of(context).pop();
        widget.onPlayMatch(m);
      },
      onViewPodium: widget.onViewPodium,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        final myUid = user?.uid ?? '';

        return AppModalSheet(
          heightFactor: 0.85,
          child: StreamBuilder<List<FriendInvite>>(
            stream: FriendsService.instance.streamIncomingInvites(myUid),
            initialData: const <FriendInvite>[],
            builder: (context, invitesSnap) {
              final invites = invitesSnap.data ?? [];

              return StreamBuilder<List<FriendProfile>>(
                stream: FriendsService.instance.streamFriends(myUid),
                builder: (context, friendsSnap) {
                  final friends = friendsSnap.data ?? [];
                  final friendUids = friends.map((f) => f.uid).toSet();

                  return Column(
                    children: [

                        // Dedicated Friends Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2638),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '👥',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FRIENDS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        EditGamerTagDialog.show(context);
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Playing as ${user?.displayName ?? "Player"}',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.edit_rounded,
                                            size: 11,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openAddFriend(friendUids),
                                icon: const Icon(
                                  Icons.person_add_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'ADD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFF1E2638), height: 16),

                        // Main Content (Invites + Friends)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (friendsSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !friendsSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF38BDF8),
                                  ),
                                );
                              }

                              if (friends.isEmpty && invites.isEmpty) {
                                return _buildEmptyState(user, friendUids);
                              }

                              return StreamBuilder<List<CloudMatch>>(
                                stream: FirestoreMatchService.instance
                                    .streamUserMatches(myUid),
                                builder: (context, matchSnap) {
                                  final matches = matchSnap.data ?? [];

                                  return ListView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    children: [
                                      if (invites.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                            left: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              const Text(
                                                'PENDING INVITES',
                                                style: TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF59E0B,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${invites.length}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        for (final inv in invites)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: FriendInviteTile(
                                              invite: inv,
                                              myUid: myUid,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (friends.isNotEmpty) ...[
                                        if (invites.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 8,
                                              left: 2,
                                            ),
                                            child: Text(
                                              'MY FRIENDS',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                        for (final friend in friends) ...[
                                          Builder(
                                            builder: (context) {
                                              final match = matches
                                                  .cast<CloudMatch?>()
                                                  .firstWhere(
                                                    (m) =>
                                                        m != null &&
                                                        m.playerIds.contains(
                                                          friend.uid,
                                                        ),
                                                    orElse: () => null,
                                                  );
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: FriendCardTile(
                                                  friend: friend,
                                                  myUid: myUid,
                                                  match: match,
                                                  onTap: () => _openConversation(
                                                    friend,
                                                    myUid,
                                                    match,
                                                  ),
                                                  onPlayMatch: (m) {
                                                    Navigator.of(context).pop();
                                                    widget.onPlayMatch(m);
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ] else if (invites.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        const Center(
                                          child: Text(
                                            'Accept pending invites above to connect with players!',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        );
      },
    );
  }

  Widget _buildEmptyState(UserProfile? user, Set<String> existingUids) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF38BDF8),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'NO FRIENDS YET',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add friends using their player tag or username to chat and launch 1v1 challenges anytime!',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openAddFriend(existingUids),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text(
                '+ ADD FRIEND',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF26334A)),
                ),
                child: Row(
                  children: [
                    AppAvatar(avatar: user.avatarEmoji, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PLAYER TAG',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Color(0xFF38BDF8),
                        size: 16,
                      ),
                      tooltip: 'Copy Tag',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: user.displayName),
                        );
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied "${user.displayName}" to clipboard!',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF1E2638),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
