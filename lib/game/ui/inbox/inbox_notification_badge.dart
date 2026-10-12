import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';

/// Clean stadium scoreboard header badge for 1v1 Matches.
///
/// Follows strict arena guidelines:
/// - Idle: Plain chat bubble icon with neutral border.
/// - Your move: Amber ring with count badge, gentle single pulse on new turn arrival.
/// - Single shared Firestore broadcast stream listener (zero duplicate queries).
class InboxNotificationBadge extends StatefulWidget {
  final VoidCallback onTap;
  final String? activeMatchId;

  const InboxNotificationBadge({
    super.key,
    required this.onTap,
    this.activeMatchId,
  });

  @override
  State<InboxNotificationBadge> createState() => _InboxNotificationBadgeState();
}

class _InboxNotificationBadgeState extends State<InboxNotificationBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  int _prevWaitingCount = 0;
  String? _currentStreamUid;
  Stream<List<CloudMatch>>? _matchesStream;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onAlertsUpdated(int count) {
    if (count > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (count > _prevWaitingCount) {
        HapticFeedback.lightImpact();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
    _prevWaitingCount = count;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null || user.uid.isEmpty) {
          return _buildButton(alertsCount: 0);
        }

        if (_currentStreamUid != user.uid) {
          _currentStreamUid = user.uid;
          _matchesStream = FirestoreMatchService.instance.streamUserMatches(
            user.uid,
          );
        }

        return StreamBuilder<List<FriendInvite>>(
          stream: FriendsService.instance.streamIncomingInvites(user.uid),
          initialData: const <FriendInvite>[],
          builder: (context, invitesSnapshot) {
            final invitesCount = (invitesSnapshot.data ?? []).length;

            return StreamBuilder<List<CloudMatch>>(
              stream: _matchesStream,
              initialData: const <CloudMatch>[],
              builder: (context, snapshot) {
                final matches = snapshot.data ?? [];
                final activeId = widget.activeMatchId;
                final turnsWaiting = matches
                    .where(
                      (m) =>
                          m.isMyTurn(user.uid) &&
                          m.status != MatchStatus.completed &&
                          (activeId == null || m.id != activeId),
                    )
                    .length;

                final totalAlerts = turnsWaiting + invitesCount;
                _onAlertsUpdated(totalAlerts);

                return _buildButton(alertsCount: totalAlerts);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildButton({required int alertsCount}) {
    final hasAlerts = alertsCount > 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = hasAlerts ? _scaleAnimation.value : 1.0;
        final glowProgress = hasAlerts ? _pulseController.value : 0.0;

        return Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              borderRadius: BorderRadius.circular(17.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F2E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasAlerts
                            ? Color.lerp(
                                const Color(0xFFF59E0B),
                                const Color(0xFF38BDF8),
                                glowProgress,
                              )!
                            : const Color(0xFF334155),
                        width: hasAlerts ? 2.0 : 1.2,
                      ),
                      boxShadow: hasAlerts
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.35 + 0.35 * glowProgress),
                                blurRadius: 10 + 6 * glowProgress,
                                spreadRadius: 1 + 2 * glowProgress,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16.0,
                        color: hasAlerts
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (hasAlerts)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$alertsCount',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
