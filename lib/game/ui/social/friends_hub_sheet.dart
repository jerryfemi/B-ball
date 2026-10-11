import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../inbox/join_match_dialog.dart';
import 'add_friend_dialog.dart';
import 'friend_conversation_sheet.dart';

/// GamePigeon-style Social Conversations & 1v1 Match Hub modal sheet.
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    AddFriendDialog.show(
      context,
      existingFriendUids: existingUids,
    );
  }

  Future<void> _openJoinCode() async {
    HapticFeedback.lightImpact();
    final match = await JoinMatchDialog.show(context);
    if (match != null && mounted) {
      Navigator.of(context).pop();
      widget.onPlayMatch(match);
    }
  }

  void _openConversation(FriendProfile friend, String myUid, CloudMatch? match) {
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
    final user = AuthService.instance.currentUser;
    final myUid = user?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF2E3954), width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Pull bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(user?.avatarEmoji ?? '🏀', style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1V1 HUB & CONVERSATIONS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Playing as ${user?.displayName ?? "Player"}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Quick Actions Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionPill(
                      icon: Icons.person_add_rounded,
                      label: '+ Add Friend',
                      color: const Color(0xFF38BDF8),
                      onTap: () => _openAddFriend({}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionPill(
                      icon: Icons.tag_rounded,
                      label: '# Join Code',
                      color: const Color(0xFF94A3B8),
                      onTap: _openJoinCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionPill(
                      icon: Icons.sports_basketball_rounded,
                      label: '⚡ New 1v1',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onCreateMatch();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E2638), height: 16),

            // Main Feed
            Expanded(
              child: StreamBuilder<List<FriendProfile>>(
                stream: FriendsService.instance.streamFriends(myUid),
                builder: (context, friendsSnap) {
                  final friends = friendsSnap.data ?? [];
                  final friendUids = friends.map((f) => f.uid).toSet();

                  return StreamBuilder<List<CloudMatch>>(
                    stream: FirestoreMatchService.instance.streamUserMatches(myUid),
                    builder: (context, matchSnap) {
                      final matches = matchSnap.data ?? [];

                      // Identify stranger matches (not in friends list and not completed)
                      final oneOffMatches = matches.where((m) {
                        final oppUid = m.opponentPlayer(myUid)?.uid ?? '';
                        return !friendUids.contains(oppUid) &&
                            m.status != MatchStatus.completed;
                      }).toList();

                      if (friends.isEmpty && oneOffMatches.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        children: [
                          if (friends.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Text(
                                'FRIENDS & THREADS',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            ...friends.map((friend) {
                              final match = matches.cast<CloudMatch?>().firstWhere(
                                (m) => m != null && m.playerIds.contains(friend.uid),
                                orElse: () => null,
                              );
                              return _buildFriendCard(friend, myUid, match);
                            }),
                          ],
                          if (oneOffMatches.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Text(
                                'ONE-OFF ROOM CODES',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            ...oneOffMatches.map((m) => _buildOneOffMatchCard(m, myUid)),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2638),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(FriendProfile friend, String myUid, CloudMatch? match) {
    final hasActiveMatch = match != null && match.status != MatchStatus.completed;
    final isMyTurn = hasActiveMatch && match.isMyTurn(myUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMyTurn ? const Color(0xFF19253B) : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyTurn ? const Color(0xFF38BDF8) : const Color(0xFF26334A),
          width: isMyTurn ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _openConversation(friend, myUid, match),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2638),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(friend.avatarEmoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          hasActiveMatch
              ? (isMyTurn
                  ? '⚡ Your turn to shoot (Round ${match.currentRound})'
                  : '⏳ Waiting for opponent to shoot')
              : 'Tap to chat or challenge 🏀',
          style: TextStyle(
            color: isMyTurn ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: isMyTurn
            ? ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onPlayMatch(match);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
      ),
    );
  }

  Widget _buildOneOffMatchCard(CloudMatch match, String myUid) {
    final opponent = match.opponentPlayer(myUid);
    final isMyTurn = match.isMyTurn(myUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26334A)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Text(opponent?.avatarEmoji ?? '⏳', style: const TextStyle(fontSize: 22)),
        title: Text(
          opponent?.displayName ?? 'Match #${match.joinCode}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          'Code: ${match.joinCode} • Round ${match.currentRound}/${match.totalRounds}',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (opponent != null)
              IconButton(
                icon: const Icon(Icons.person_add_outlined, color: Color(0xFF38BDF8), size: 18),
                tooltip: 'Add to Friends',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final friend = FriendProfile(
                    uid: opponent.uid,
                    displayName: opponent.displayName,
                    avatarEmoji: opponent.avatarEmoji,
                    addedAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await FriendsService.instance.addFriend(myUid, friend);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${friend.displayName} to friends!')),
                    );
                  }
                },
              ),
            if (isMyTurn)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onPlayMatch(match);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.sports_basketball_rounded, color: Color(0xFFF59E0B), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'NO ACTIVE CONVERSATIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add a friend or join a room code to start shooting 1v1 rounds back and forth!',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAddFriend({}),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('+ ADD FIRST FRIEND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
