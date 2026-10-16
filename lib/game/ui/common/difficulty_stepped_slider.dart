import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../physics/shot_difficulty.dart';

/// Compact, premium discrete stepped slider for selecting [ShotDifficulty].
///
/// Replaces bulky 4-box grids with a space-efficient ~48px control featuring
/// haptic snap feedback, status color grading, and direct-tap label targets.
class DifficultySteppedSlider extends StatelessWidget {
  final ShotDifficulty value;
  final ValueChanged<ShotDifficulty> onChanged;
  final String title;

  const DifficultySteppedSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'DIFFICULTY',
  });

  static Color _getDifficultyColor(ShotDifficulty diff) {
    switch (diff) {
      case ShotDifficulty.easy:
        return const Color(0xFF22C55E); // Green
      case ShotDifficulty.medium:
        return const Color(0xFFF59E0B); // Amber
      case ShotDifficulty.hard:
        return const Color(0xFFEF4444); // Red
      case ShotDifficulty.pro:
        return const Color(0xFF818CF8); // Indigo / Violet
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getDifficultyColor(value);
    final currentIndex = value.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Header with dynamic status badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.40),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.emoji,
                    style: const TextStyle(fontSize: 11.0),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    value.label.toUpperCase(),
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),

        // 2. Stepped Slider Track
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            activeTrackColor: activeColor,
            inactiveTrackColor: const Color(0x33334155),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6.5,
              pressedElevation: 3.0,
            ),
            overlayColor: activeColor.withValues(alpha: 0.20),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 13.0,
            ),
            tickMarkShape: const RoundSliderTickMarkShape(
              tickMarkRadius: 2.2,
            ),
            activeTickMarkColor: Colors.white.withValues(alpha: 0.90),
            inactiveTickMarkColor: const Color(0x6694A3B8),
          ),
          child: Slider(
            value: currentIndex.toDouble(),
            min: 0.0,
            max: (ShotDifficulty.values.length - 1).toDouble(),
            divisions: ShotDifficulty.values.length - 1,
            onChanged: (double doubleVal) {
              final newIdx = doubleVal.round();
              if (newIdx != currentIndex) {
                HapticFeedback.selectionClick();
                onChanged(ShotDifficulty.values[newIdx]);
              }
            },
          ),
        ),

        // 3. Direct-tap step label row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(ShotDifficulty.values.length, (idx) {
              final diff = ShotDifficulty.values[idx];
              final isSel = idx == currentIndex;
              return GestureDetector(
                onTap: () {
                  if (idx != currentIndex) {
                    HapticFeedback.selectionClick();
                    onChanged(diff);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  child: Text(
                    diff.label,
                    style: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF64748B),
                      fontSize: 10.0,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
