import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/friend_profile.dart';
import '../../../../services/friends_service.dart';
import '../../common/app_avatar.dart';

/// Card tile representing an incoming friend request with accept and decline actions.
class FriendInviteTile extends StatelessWidget {
  final FriendInvite invite;
  final String myUid;

  const FriendInviteTile({
    super.key,
    required this.invite,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            avatar: invite.senderAvatar,
            size: 36,
            borderColor: const Color(0xFF38BDF8),
            borderWidth: 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.senderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Wants to be friends',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await FriendsService.instance.declineFriendInvite(
                myUid,
                invite.senderUid,
              );
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            tooltip: 'Decline',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E2638),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await FriendsService.instance.acceptFriendInvite(myUid, invite);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${invite.senderName} as a friend! 🎉'),
                    backgroundColor: const Color(0xFF1E2638),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ACCEPT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
