import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Animated flame streak badge displayed below the scoreboard when streak >= 3.
class HotStreakPill extends StatelessWidget {
  final ValueListenable<int> streakNotifier;

  const HotStreakPill({
    super.key,
    required this.streakNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: streakNotifier,
      builder: (context, streak, _) {
        final bool isHot = streak >= 3;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: isHot
              ? Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFEA580C),
                          Color(0xFFDC2626),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66EA580C),
                          blurRadius: 10.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 13.0),
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'x$streak ON FIRE',
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
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
