import 'package:flutter/material.dart';

import 'common/app_modal_dialog.dart';

/// Displays the collegiate "HOW TO PLAY" rules dialog.
Future<void> showGameRulesDialog(BuildContext context) {
  return AppModalDialog.show<void>(
    context: context,
    builder: (context) => const GameRulesDialog(),
  );
}

/// Collegiate rules modal explaining flicks, buzzer beater clock, and scoring bonuses.
class GameRulesDialog extends StatelessWidget {
  const GameRulesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      title: 'HOW TO PLAY',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                const _RuleRow(
                  icon: '🏀',
                  title: 'Flick to Shoot',
                  desc: 'Swipe up with finger speed and angle towards the hoop.',
                ),
                const SizedBox(height: 12.0),
                const _RuleRow(
                  icon: '⏱️',
                  title: '60s Buzzer Beater',
                  desc: 'Score as many points as you can before time expires.',
                ),
                const SizedBox(height: 12.0),
                const _RuleRow(
                  icon: '🔥',
                  title: 'Swish (+3 PTS)',
                  desc: 'Clean shot through the net without hitting rim or backboard.',
                ),
                const SizedBox(height: 12.0),
                const _RuleRow(
                  icon: '🎯',
                  title: 'Bank Shot (+3 PTS)',
                  desc: 'Rebound the ball off the regulation tempered glass target box.',
                ),
                const SizedBox(height: 12.0),
                const _RuleRow(
                  icon: '⚡',
                  title: 'Streak Multiplier',
                  desc: 'Sink 3+ in a row to earn +1 extra bonus point per consecutive basket!',
                ),
                const SizedBox(height: 22.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

class _RuleRow extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _RuleRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18.0)),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
