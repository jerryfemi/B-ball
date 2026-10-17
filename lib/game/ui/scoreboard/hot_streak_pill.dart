import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Animated streak badge displayed below the scoreboard when streak >= 3.
///
/// Tier-aware, matching the ball and hoop streak effects:
///   3–5  ⚡ HEATING UP  (electric cyan)
///   6–9  🔥 ON FIRE     (flame orange)
///   10+  ☄️ INFERNO     (crimson / gold)
/// Pops with an elastic scale on every new make.
class HotStreakPill extends StatelessWidget {
  final ValueListenable<int> streakNotifier;

  const HotStreakPill({
    super.key,
    required this.streakNotifier,
  });

  static ({String icon, String label, List<Color> gradient, Color border, Color glow})
  _style(int streak) {
    if (streak >= 10) {
      return (
        icon: '☄️',
        label: 'INFERNO',
        gradient: const [Color(0xFFB91C1C), Color(0xFFF59E0B)],
        border: const Color(0xFFFFE27A),
        glow: const Color(0x99FF3B1F),
      );
    }
    if (streak >= 6) {
      return (
        icon: '🔥',
        label: 'ON FIRE',
        gradient: const [Color(0xFFEA580C), Color(0xFFDC2626)],
        border: const Color(0xFFFFD700),
        glow: const Color(0x80EA580C),
      );
    }
    return (
      icon: '⚡',
      label: 'HEATING UP',
      gradient: const [Color(0xFF0EA5E9), Color(0xFF6366F1)],
      border: const Color(0xFFBAE6FD),
      glow: const Color(0x7038BDF8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: streakNotifier,
      builder: (context, streak, _) {
        final bool isHot = streak >= 3;
        final style = _style(streak);
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: isHot
              ? Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  // Keyed by streak: every new make replays the pop.
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(streak),
                    tween: Tween(begin: 1.25, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: style.gradient),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: style.border.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: style.glow,
                            blurRadius: streak >= 10 ? 16.0 : 10.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            style.icon,
                            style: const TextStyle(fontSize: 13.0),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            'x$streak ${style.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
