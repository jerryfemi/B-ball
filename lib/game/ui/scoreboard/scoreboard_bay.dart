import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../digital_led_display.dart';

/// Recessed 7-segment digital LED score compartment for "YOU" and "BEST".
class ScoreboardBay extends StatelessWidget {
  final String label;
  final ValueListenable<int> valueListenable;
  final Animation<double>? scaleAnimation;

  const ScoreboardBay({
    super.key,
    required this.label,
    required this.valueListenable,
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final digitContent = ValueListenableBuilder<int>(
      valueListenable: valueListenable,
      builder: (context, val, _) {
        return DigitalLedNumberDisplay(
          value: val,
          digitWidth: 13.0,
          digitHeight: 23.0,
          spacing: 2.5,
          onColor: const Color(0xFFFF2020),
          offColor: const Color(0x283A0505),
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3.5),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6.0,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF060608),
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: const Color(0x38FFFFFF),
              width: 1.0,
            ),
          ),
          child: scaleAnimation != null
              ? ScaleTransition(
                  scale: scaleAnimation!,
                  child: digitContent,
                )
              : digitContent,
        ),
      ],
    );
  }
}

/// Center amber countdown clock compartment with white contour and urgent glow.
class ScoreboardClockBay extends StatelessWidget {
  final ValueListenable<int> timeRemainingNotifier;
  final Animation<double> urgentGlowAnimation;

  const ScoreboardClockBay({
    super.key,
    required this.timeRemainingNotifier,
    required this.urgentGlowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: urgentGlowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: timeRemainingNotifier.value <= 10
              ? urgentGlowAnimation.value
              : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9.0,
          vertical: 4.0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF040406),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Colors.white,
            width: 2.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4.0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: timeRemainingNotifier,
          builder: (context, secondsRemaining, _) {
            final isUrgent = secondsRemaining <= 10;
            return DigitalLedClockDisplay(
              totalSeconds: secondsRemaining,
              digitWidth: 12.0,
              digitHeight: 22.0,
              spacing: 2.0,
              onColor: isUrgent
                  ? const Color(0xFFFF3333)
                  : const Color(0xFFFFE000),
              offColor: isUrgent
                  ? const Color(0x283A0505)
                  : const Color(0x22352E04),
            );
          },
        ),
      ),
    );
  }
}
