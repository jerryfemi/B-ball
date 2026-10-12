import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../common/app_avatar.dart';

/// Flanking circular opponent avatar with illuminated badge and "Them" label.
class ScoreboardOpponentAvatar extends HookConsumerWidget {
  final bool isActive;
  final String label;
  final String avatar;
  final bool isWaiting;
  final String? joinCode;
  final String? activeMatchId;
  final VoidCallback? onTap;

  const ScoreboardOpponentAvatar({
    super.key,
    this.isActive = false,
    this.label = 'Them',
    this.avatar = 'assets/avatars/dunk_heads (2).webp',
    this.isWaiting = false,
    this.joinCode,
    this.activeMatchId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bubbleController = useAnimationController(
      duration: const Duration(milliseconds: 250),
    );

    final bubbleScaleAnimation = useMemoized(
      () => CurvedAnimation(
        parent: bubbleController,
        curve: Curves.easeOutBack,
      ),
      [bubbleController],
    );

    final currentBanterText = useState<String?>(null);
    final bubbleTimerRef = useRef<Timer?>(null);
    final lastSeenTimestampRef = useRef<int>(DateTime.now().millisecondsSinceEpoch);

    useEffect(() {
      return () => bubbleTimerRef.value?.cancel();
    }, const []);

    void triggerBanterBubble(String text) {
      bubbleTimerRef.value?.cancel();
      currentBanterText.value = text;
      bubbleController.forward();
      HapticFeedback.lightImpact();
      bubbleTimerRef.value = Timer(const Duration(milliseconds: 2500), () {
        bubbleController.reverse();
      });
    }

    void handleAvatarTap() {
      if (isWaiting && joinCode != null && joinCode!.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: joinCode!));
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Match code $joinCode copied! Share it with a friend.'),
            backgroundColor: const Color(0xFF1E2638),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.0),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        onTap?.call();
      }
    }

    Widget buildContent() {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: handleAvatarTap,
                borderRadius: BorderRadius.circular(18.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      avatar: isWaiting ? '⏳' : avatar,
                      size: 36.0,
                      borderColor: isWaiting
                          ? const Color(0xFFF59E0B)
                          : (isActive
                              ? const Color(0xFF38BDF8)
                              : Colors.white.withValues(alpha: 0.8)),
                      borderWidth: isWaiting || isActive ? 2.2 : 1.5,
                      showGlow: isActive || isWaiting,
                      glowColor: isWaiting
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF38BDF8),
                    ),
                    if (isWaiting)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 9.0,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2.0),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 62.0),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isWaiting
                        ? const Color(0xFFFBBF24)
                        : (isActive
                            ? const Color(0xFF7DD3FC)
                            : const Color(0xFF38BDF8)),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4.0)],
                  ),
                ),
              ),
            ],
          ),

          // Floating speech bubble for live banter
          if (currentBanterText.value != null)
            Positioned(
              bottom: 48.0,
              child: FadeTransition(
                opacity: bubbleController,
                child: ScaleTransition(
                  scale: bubbleScaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 6.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88.0),
                      child: Text(
                        currentBanterText.value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final matchId = activeMatchId;
    final match = (matchId != null && matchId.isNotEmpty)
        ? ref.watch(singleMatchProvider(matchId)).value
        : null;
    final user = ref.watch(currentUserProfileProvider).value;

    useEffect(() {
      if (match != null && match.chat.isNotEmpty) {
        final lastMsg = match.chat.last;
        final myUid = user?.uid ?? '';
        if (lastMsg.senderUid != myUid &&
            lastMsg.timestamp > lastSeenTimestampRef.value) {
          lastSeenTimestampRef.value = lastMsg.timestamp;
          triggerBanterBubble(lastMsg.text);
        }
      }
      return null;
    }, [match]);

    return buildContent();
  }
}
