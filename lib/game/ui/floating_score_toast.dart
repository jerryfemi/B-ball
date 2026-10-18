import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../basketball_game.dart';

/// Floating score toast item model
class _ToastItem {
  final Key key;
  final ScoreEvent event;
  final DateTime createdAt;

  _ToastItem({
    required this.key,
    required this.event,
    required this.createdAt,
  });
}

/// Floating Score Toast System that listens to [BasketballGame.scoreEventNotifier]
/// and spawns celebratory floating badges (+3 SWISH!, +3 BANK SHOT!, +2 PTS)
/// that gently drift upward and fade out.
class FloatingScoreToastSystem extends HookWidget {
  final BasketballGame game;

  const FloatingScoreToastSystem({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final activeToasts = useState<List<_ToastItem>>([]);
    final toastCounterRef = useRef<int>(0);

    useEffect(() {
      void onScoreEvent() {
        final event = game.scoreEventNotifier.value;
        if (event == null) return;
        toastCounterRef.value++;
        activeToasts.value = [
          ...activeToasts.value,
          _ToastItem(
            key: ValueKey('toast_${toastCounterRef.value}'),
            event: event,
            createdAt: DateTime.now(),
          ),
        ];
      }

      game.scoreEventNotifier.addListener(onScoreEvent);
      return () => game.scoreEventNotifier.removeListener(onScoreEvent);
    }, [game]);

    void removeToast(Key key) {
      activeToasts.value =
          activeToasts.value.where((item) => item.key != key).toList();
    }

    return IgnorePointer(
      child: Stack(
        children: activeToasts.value.map((toast) {
          return Positioned.fill(
            child: _FloatingToastWidget(
              key: toast.key,
              event: toast.event,
              onComplete: () => removeToast(toast.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FloatingToastWidget extends HookWidget {
  final ScoreEvent event;
  final VoidCallback onComplete;

  const _FloatingToastWidget({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    // Initial punchy spring pop-in
    final scaleAnimation = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.5, end: 1.15)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.95),
          weight: 45,
        ),
      ]).animate(controller),
      [controller],
    );

    // Upward float drift
    final slideAnimation = useMemoized(
      () => Tween<Offset>(
        begin: const Offset(0.0, 0.0),
        end: const Offset(0.0, -1.3),
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(controller),
      [controller],
    );

    // Smooth fade out in the final 40% of duration
    final fadeAnimation = useMemoized(
      () => TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
      ]).animate(controller),
      [controller],
    );

    useEffect(() {
      controller.forward().then((_) {
        onComplete();
      });
      return null;
    }, const []);

    // Palette & Label resolution
    final Color primaryColor;
    final Color glowColor;
    final String label;
    final IconData icon;

    if (event.isSwish) {
      primaryColor = const Color(0xFFFBBF24); // Warm radiant gold
      glowColor = const Color(0x66F59E0B);
      label = '+${event.points} SWISH!';
      icon = Icons.auto_awesome_rounded;
    } else if (event.isBankShot) {
      primaryColor = const Color(0xFF38BDF8); // Electric cyan
      glowColor = const Color(0x660EA5E9);
      label = '+${event.points} BANK!';
      icon = Icons.crop_square_rounded;
    } else {
      primaryColor = const Color(0xFFF8FAFC); // Clean collegiate pearl
      glowColor = const Color(0x33FFFFFF);
      label = '+${event.points} PTS';
      icon = Icons.sports_basketball_rounded;
    }

    final hasStreakBonus = event.streak >= 3;

    Widget animated(Widget child, {Alignment scaleFrom = Alignment.center}) {
      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            alignment: scaleFrom,
            child: child,
          ),
        ),
      );
    }

    // Layout: the shot callout pops BESIDE the hoop (right of the backboard)
    // so it never covers the rim; the streak-bonus chip keeps its old spot
    // centered under the scoreboard. The hoop sits at 25% of the game height
    // (Forge2D y=5 of 20), centered horizontally.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const calloutMaxWidth = 150.0;
        final calloutLeft = (w / 2 + h * 0.10).clamp(
          0.0,
          (w - calloutMaxWidth - 8.0).clamp(0.0, double.infinity),
        );
        return Stack(
          children: [
            Positioned(
              left: calloutLeft,
              top: h * 0.25 - 22.0,
              child: animated(
                _buildCallout(primaryColor, glowColor, label, icon),
                scaleFrom: Alignment.centerLeft,
              ),
            ),
            if (hasStreakBonus)
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.28,
                child: Center(child: animated(_buildStreakChip())),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStreakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88EF4444),
            blurRadius: 8.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '🔥 ${event.streak} STREAK (+1 BONUS)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCallout(
    Color primaryColor,
    Color glowColor,
    String label,
    IconData icon,
  ) {
    return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 7.0,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFA0F172A),
                      Color(0xFC1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(
                    color: primaryColor,
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.40),
                      blurRadius: 8.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 17.0,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 7.0),
                    Text(
                      label,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: const [
                          Shadow(
                            color: Color(0xCC000000),
                            blurRadius: 3.0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            ],
          );
  }
}
