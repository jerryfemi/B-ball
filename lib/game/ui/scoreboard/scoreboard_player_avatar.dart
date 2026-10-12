import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../common/app_avatar.dart';

/// Flanking circular player avatar with illuminated badge, "You" label,
/// and live reactive inbox/turns notification pip.
class ScoreboardPlayerAvatar extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsCount = ref.watch(userAlertsCountProvider(activeMatchId));
    final chatMessages = (activeMatchId != null && activeMatchId!.isNotEmpty)
        ? ref.watch(matchChatProvider(activeMatchId!)).value ?? const []
        : const [];
    final user = ref.watch(currentUserProfileProvider).value;

    return _PulsingPlayerAvatar(
      alertsCount: alertsCount,
      recentMessageCount: chatMessages.length,
      lastMessageSenderUid:
          chatMessages.isNotEmpty ? chatMessages.last.senderUid : null,
      myUid: user?.uid,
      avatar: avatar,
      label: label,
      isActive: isActive,
      onTap: onTap,
    );
  }
}

class _PulsingPlayerAvatar extends HookWidget {
  final int alertsCount;
  final int recentMessageCount;
  final String? lastMessageSenderUid;
  final String? myUid;
  final String avatar;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _PulsingPlayerAvatar({
    required this.alertsCount,
    this.recentMessageCount = 0,
    this.lastMessageSenderUid,
    this.myUid,
    required this.avatar,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 750),
    );

    final scaleAnimation = useMemoized(
      () => Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      [pulseController],
    );

    final prevIsActiveRef = useRef<bool>(isActive);
    final prevMsgCountRef = useRef<int>(recentMessageCount);
    final prevCountRef = useRef<int>(alertsCount);

    final shouldPulse = isActive || alertsCount > 0;

    useEffect(() {
      if (shouldPulse) {
        if (!pulseController.isAnimating) {
          pulseController.repeat(reverse: true);
        }
      } else {
        if (pulseController.isAnimating) {
          pulseController.stop();
          pulseController.value = 0.0;
        }
      }
      return null;
    }, [shouldPulse]);

    useEffect(() {
      final turnJustBecameMine = isActive && !prevIsActiveRef.value;
      final newMessageFromOpponent =
          recentMessageCount > prevMsgCountRef.value &&
              lastMessageSenderUid != null &&
              lastMessageSenderUid != myUid;
      final alertsIncreased = alertsCount > prevCountRef.value;

      if (turnJustBecameMine || newMessageFromOpponent || alertsIncreased) {
        HapticFeedback.mediumImpact();
        pulseController.forward(from: 0.0).then((_) {
          if (shouldPulse) {
            pulseController.repeat(reverse: true);
          }
        });
      }

      prevIsActiveRef.value = isActive;
      prevMsgCountRef.value = recentMessageCount;
      prevCountRef.value = alertsCount;
      return null;
    }, [isActive, recentMessageCount, alertsCount]);

    final hasAlerts = alertsCount > 0;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final scale = (hasAlerts || isActive) ? scaleAnimation.value : 1.0;
        final glowProgress = (hasAlerts || isActive) ? pulseController.value : 0.0;

        final Color borderColor = hasAlerts
            ? Color.lerp(
                const Color(0xFFF59E0B),
                const Color(0xFFFBBF24),
                glowProgress,
              )!
            : (isActive
                ? Color.lerp(
                    const Color(0xFF4ADE80),
                    const Color(0xFF86EFAC),
                    glowProgress,
                  )!
                : Colors.white.withValues(alpha: 0.8));

        final Color glowColor = hasAlerts
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

        final bool showGlow = hasAlerts || isActive;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    avatar: avatar,
                    size: 36.0,
                    borderColor: borderColor,
                    borderWidth: hasAlerts ? 2.4 : (isActive ? 2.2 : 1.5),
                    showGlow: showGlow,
                    glowColor: glowColor,
                    onTap: () {
                      if (onTap != null) {
                        HapticFeedback.lightImpact();
                        onTap!();
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
              label,
              style: TextStyle(
                color: hasAlerts
                    ? const Color(0xFFFBBF24)
                    : (isActive
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
