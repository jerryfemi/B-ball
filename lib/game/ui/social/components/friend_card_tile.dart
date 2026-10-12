import 'package:flutter/material.dart';

import '../../../../models/cloud_match.dart';
import '../../../../models/friend_profile.dart';
import '../../common/app_avatar.dart';

/// Card tile representing an existing friend in the Friends Hub with match status indicator and chat/play triggers.
class FriendCardTile extends StatelessWidget {
  final FriendProfile friend;
  final String myUid;
  final CloudMatch? match;
  final VoidCallback onTap;
  final ValueChanged<CloudMatch> onPlayMatch;

  const FriendCardTile({
    super.key,
    required this.friend,
    required this.myUid,
    required this.match,
    required this.onTap,
    required this.onPlayMatch,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveMatch =
        match != null && match!.status != MatchStatus.completed;
    final isMyTurn = hasActiveMatch && match!.isMyTurn(myUid);

    return Container(
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
        onTap: onTap,
        leading: AppAvatar(
          avatar: friend.avatarEmoji,
          size: 38,
          borderColor: const Color(0xFF38BDF8),
          borderWidth: 1.5,
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          hasActiveMatch
              ? (isMyTurn
                    ? '⚡ Your turn to shoot (Round ${match!.currentRound})'
                    : '⏳ Waiting for opponent (Round ${match!.currentRound})')
              : 'Tap to chat & 1v1 challenge 🏀',
          style: TextStyle(
            color: isMyTurn ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyTurn)
              ElevatedButton(
                onPressed: () => onPlayMatch(match!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'PLAY',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
                tooltip: 'Chat',
                onPressed: onTap,
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
