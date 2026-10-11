import 'package:flutter/material.dart';
import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';

/// Compact reactive button for the scoreboard showing unread / waiting turns count.
class InboxNotificationBadge extends StatelessWidget {
  final VoidCallback onTap;

  const InboxNotificationBadge({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.mail_outline, color: Colors.white70, size: 20),
          );
        }

        return StreamBuilder<List<CloudMatch>>(
          stream: FirestoreMatchService.instance.streamUserMatches(user.uid),
          builder: (context, snapshot) {
            final matches = snapshot.data ?? [];
            final turnsWaiting = matches.where((m) => m.isMyTurn(user.uid) && m.status != MatchStatus.completed).length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onTap,
                  tooltip: 'Match Inbox',
                  icon: const Icon(Icons.forum_outlined, color: Colors.white, size: 22),
                ),
                if (turnsWaiting > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        '$turnsWaiting',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
