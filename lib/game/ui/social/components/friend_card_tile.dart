import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../models/cloud_match.dart';
import '../../../../models/friend_profile.dart';
import '../../../../providers/app_providers.dart';
import '../../common/app_avatar.dart';
import '../../common/app_colors.dart';

/// Card tile representing an existing friend in the Friends Hub with match status indicator,
/// unread chat badging, and direct play/banter triggers.
class FriendCardTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveMatch =
        match != null && match!.status != MatchStatus.completed;
    final isMyTurn = hasActiveMatch && match!.isMyTurn(myUid);
    final hasUnreadMessage =
        ref.watch(friendHasUnreadMessageProvider(friend.uid));

    return Material(
      color: isMyTurn ? AppColors.surfaceTile : AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isMyTurn
              ? AppColors.accentElectricSky
              : (hasUnreadMessage
                  ? AppColors.accentRed.withValues(alpha: 0.6)
                  : AppColors.borderSubtle),
          width: (isMyTurn || hasUnreadMessage) ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            AppAvatar(
              avatar: friend.avatarEmoji,
              size: 38,
              borderColor: hasUnreadMessage
                  ? AppColors.accentRed
                  : (isMyTurn
                      ? AppColors.accentNeonCyan
                      : AppColors.accentElectricSky),
              borderWidth: hasUnreadMessage ? 2.0 : 1.5,
              showGlow: hasUnreadMessage,
              glowColor: AppColors.accentRed,
            ),
            if (hasUnreadMessage)
              Positioned(
                top: -2.0,
                right: -2.0,
                child: Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: BoxDecoration(
                    color: AppColors.accentRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceTile,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentRed.withValues(alpha: 0.8),
                        blurRadius: 6.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          hasActiveMatch
              ? (isMyTurn
                    ? '⚡ Your turn to shoot (Round ${match!.currentRound})'
                    : '⏳ Waiting for opponent (Round ${match!.currentRound})')
              : (hasUnreadMessage
                    ? '💬 New banter waiting for you!'
                    : 'Tap to chat & 1v1 challenge 🏀'),
          style: TextStyle(
            color: isMyTurn
                ? AppColors.accentElectricSky
                : (hasUnreadMessage
                    ? AppColors.accentRed
                    : AppColors.textMuted),
            fontSize: 11.5,
            fontWeight: (isMyTurn || hasUnreadMessage)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyTurn)
              ElevatedButton(
                onPressed: () => onPlayMatch(match!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentElectricSky,
                  foregroundColor: AppColors.buttonDarkText,
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      hasUnreadMessage
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: hasUnreadMessage
                          ? AppColors.accentRed
                          : AppColors.accentElectricSky,
                      size: 18,
                    ),
                    tooltip: 'Chat',
                    onPressed: onTap,
                  ),
                  if (hasUnreadMessage)
                    Positioned(
                      top: 6.0,
                      right: 6.0,
                      child: Container(
                        width: 7.0,
                        height: 7.0,
                        decoration: BoxDecoration(
                          color: AppColors.accentRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceTile,
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
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
