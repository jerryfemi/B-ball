import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../common/app_avatar.dart';
import '../common/app_colors.dart';

/// Flanking circular player avatar with illuminated badge, "You" label,
/// contextual bouncing badge (turn, challenge, chat), and reactive inbox pip.
class ScoreboardPlayerAvatar extends HookConsumerWidget {
  final bool isActive;
  final String label;
  final String avatar;
  final String? activeMatchId;
  final VoidCallback? onTap;

  const ScoreboardPlayerAvatar({
    super.key,
    this.isActive = false,
    this.label = 'You',
    this.avatar = AppAvatar.defaultAvatar,
    this.activeMatchId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(scoreboardAlertStateProvider(activeMatchId));
    final chatMessages = (activeMatchId != null && activeMatchId!.isNotEmpty)
        ? ref.watch(matchChatProvider(activeMatchId!)).value ?? const []
        : const [];
    final user = ref.watch(currentUserProfileProvider).value;

    return _PulsingPlayerAvatar(
      alertState: alertState,
      recentMessageCount: chatMessages.length,
      lastMessageSenderUid: chatMessages.isNotEmpty
          ? chatMessages.last.senderUid
          : null,
      myUid: user?.uid,
      avatar: avatar,
      label: label,
      isActive: isActive,
      onTap: onTap,
    );
  }
}

class _PulsingPlayerAvatar extends HookWidget {
  final ScoreboardAlertState alertState;
  final int recentMessageCount;
  final String? lastMessageSenderUid;
  final String? myUid;
  final String avatar;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _PulsingPlayerAvatar({
    required this.alertState,
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
    // Continuous subtle breathing glow controller
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );

    // One-shot energetic elastic bounce controller on alert arrival
    final bounceController = useAnimationController(
      duration: const Duration(milliseconds: 700),
    );

    final pulseScaleAnimation = useMemoized(
      () => Tween<double>(begin: 1.0, end: 1.10).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      [pulseController],
    );

    final bounceScaleAnimation = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: 1.32,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 45.0,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.32,
            end: 0.94,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25.0,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.94,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30.0,
        ),
      ]).animate(bounceController),
      [bounceController],
    );

    final prevIsActiveRef = useRef<bool>(isActive);
    final prevMsgCountRef = useRef<int>(recentMessageCount);
    final prevCountRef = useRef<int>(alertState.totalCount);
    final prevTypeRef = useRef<ScoreboardAlertType>(alertState.alertType);

    final hasAlerts = alertState.totalCount > 0;
    final shouldPulse = isActive || hasAlerts;

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

    useEffect(
      () {
        final turnJustBecameMine = isActive && !prevIsActiveRef.value;
        final newMessageFromOpponent =
            recentMessageCount > prevMsgCountRef.value &&
            lastMessageSenderUid != null &&
            lastMessageSenderUid != myUid;
        final alertsIncreased = alertState.totalCount > prevCountRef.value;
        final alertTypeChanged =
            alertState.alertType != prevTypeRef.value &&
            alertState.alertType != ScoreboardAlertType.none;

        if (turnJustBecameMine ||
            newMessageFromOpponent ||
            alertsIncreased ||
            alertTypeChanged) {
          HapticFeedback.mediumImpact();
          bounceController.forward(from: 0.0);
        }

        prevIsActiveRef.value = isActive;
        prevMsgCountRef.value = recentMessageCount;
        prevCountRef.value = alertState.totalCount;
        prevTypeRef.value = alertState.alertType;
        return null;
      },
      [
        isActive,
        recentMessageCount,
        alertState.totalCount,
        alertState.alertType,
      ],
    );

    // Color and icon determination by strict hierarchy: Turn (Cyan) > Challenge (Amber) > Chat (Red)
    final Color badgeColor;
    final IconData badgeIcon;
    final Color avatarGlowColor;

    switch (alertState.alertType) {
      case ScoreboardAlertType.turnWaiting:
        badgeColor = AppColors.accentNeonCyan;
        badgeIcon = Icons.sports_esports_rounded;
        avatarGlowColor = AppColors.accentNeonCyan;
      case ScoreboardAlertType.challenge:
        badgeColor = AppColors.accentAmber;
        badgeIcon = Icons.sports_basketball_rounded;
        avatarGlowColor = AppColors.accentAmber;
      case ScoreboardAlertType.chat:
        badgeColor = AppColors.accentRed;
        badgeIcon = Icons.chat_bubble_rounded;
        avatarGlowColor = AppColors.accentRed;
      case ScoreboardAlertType.none:
        badgeColor = AppColors.accentAmber;
        badgeIcon = Icons.circle;
        avatarGlowColor = AppColors.accentEmerald;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([pulseController, bounceController]),
      builder: (context, _) {
        final bounceMultiplier = bounceController.isAnimating
            ? bounceScaleAnimation.value
            : 1.0;
        final basePulse = shouldPulse ? pulseScaleAnimation.value : 1.0;
        final totalScale = basePulse * bounceMultiplier;
        final glowProgress = shouldPulse ? pulseController.value : 0.0;

        final Color borderColor = hasAlerts
            ? Color.lerp(
                badgeColor,
                badgeColor.withValues(alpha: 0.7),
                glowProgress,
              )!
            : (isActive
                  ? Color.lerp(
                      const Color(0xFF4ADE80),
                      const Color(0xFF86EFAC),
                      glowProgress,
                    )!
                  : Colors.white.withValues(alpha: 0.8));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: totalScale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    avatar: avatar,
                    size: 36.0,
                    borderColor: borderColor,
                    borderWidth: hasAlerts ? 2.4 : (isActive ? 2.2 : 1.5),
                    showGlow: shouldPulse,
                    glowColor: avatarGlowColor,
                    onTap: () {
                      if (onTap != null) {
                        HapticFeedback.lightImpact();
                        onTap!();
                      }
                    },
                  ),

                  // Contextual Badging Pip
                  if (hasAlerts)
                    Positioned(
                      top: -4.0,
                      right: -6.0,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18.0,
                          minHeight: 18.0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: const Color(0xFF0A0F1D),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.7),
                              blurRadius: 7.0,
                              spreadRadius: 1.0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              badgeIcon,
                              size: 10.0,
                              color: const Color(0xFF0F172A),
                            ),
                            if (alertState.totalCount > 1) ...[
                              const SizedBox(width: 2.0),
                              Text(
                                '${alertState.totalCount}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ],
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
                    ? badgeColor
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
