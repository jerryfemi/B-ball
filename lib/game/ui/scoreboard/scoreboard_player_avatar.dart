import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../common/app_avatar.dart';

/// Flanking circular player avatar with illuminated badge, "You" label,
/// and live reactive inbox/turns notification pip.
class ScoreboardPlayerAvatar extends StatefulWidget {
  final bool isActive;
  final String label;
  final String avatar;
  final String? activeMatchId;
  final VoidCallback? onTap;

  const ScoreboardPlayerAvatar({
    super.key,
    this.isActive = true,
    this.label = 'You',
    this.avatar = AppAvatar.defaultAvatar,
    this.activeMatchId,
    this.onTap,
  });

  @override
  State<ScoreboardPlayerAvatar> createState() => _ScoreboardPlayerAvatarState();
}

class _ScoreboardPlayerAvatarState extends State<ScoreboardPlayerAvatar>
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
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
          return _buildAvatar(alertsCount: 0);
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

                // Also count unread chat messages from background matches
                final chatAlerts = matches.where((m) {
                  if (activeId != null && m.id == activeId) return false;
                  if (m.chat.isEmpty) return false;
                  final lastMsg = m.chat.last;
                  return lastMsg.senderUid != user.uid;
                }).length;

                final totalAlerts = turnsWaiting + invitesCount + chatAlerts;
                _onAlertsUpdated(totalAlerts);

                return _buildAvatar(alertsCount: totalAlerts);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar({required int alertsCount}) {
    final hasAlerts = alertsCount > 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = hasAlerts ? _scaleAnimation.value : 1.0;
        final glowProgress = hasAlerts ? _pulseController.value : 0.0;

        final Color borderColor = hasAlerts
            ? Color.lerp(
                const Color(0xFFF59E0B),
                const Color(0xFFFBBF24),
                glowProgress,
              )!
            : (widget.isActive
                ? const Color(0xFF86EFAC)
                : Colors.white.withValues(alpha: 0.8));

        final Color glowColor = hasAlerts
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

        final bool showGlow = hasAlerts || widget.isActive;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    avatar: widget.avatar,
                    size: 36.0,
                    borderColor: borderColor,
                    borderWidth:
                        hasAlerts ? 2.4 : (widget.isActive ? 2.2 : 1.5),
                    showGlow: showGlow,
                    glowColor: glowColor,
                    onTap: () {
                      if (widget.onTap != null) {
                        HapticFeedback.lightImpact();
                        widget.onTap!();
                      }
                    },
                  ),
                  if (hasAlerts)
                    Positioned(
                      top: -2.0,
                      right: -2.0,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16.0,
                          minHeight: 16.0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(9.0),
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.6),
                              blurRadius: 6.0,
                              spreadRadius: 1.0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$alertsCount',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 9.0,
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
            const SizedBox(height: 2.0),
            Text(
              widget.label,
              style: TextStyle(
                color: hasAlerts
                    ? const Color(0xFFFBBF24)
                    : (widget.isActive
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFF4ADE80)),
                fontSize: 10.0,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4.0)],
              ),
            ),
          ],
        );
      },
    );
  }
}
