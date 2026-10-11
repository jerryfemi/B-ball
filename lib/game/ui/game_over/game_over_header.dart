import 'package:flutter/material.dart';

import '../../basketball_game.dart';

/// Header section of the Game Over card showing accolades, final score, and labels.
class GameOverHeader extends StatelessWidget {
  final GameRoundStats stats;

  const GameOverHeader({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.isNewRecord) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 5.0,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66F59E0B),
                  blurRadius: 10.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏆', style: TextStyle(fontSize: 14.0)),
                SizedBox(width: 6.0),
                Text(
                  'NEW HIGH SCORE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
        ] else ...[
          const Text(
            "TIME'S UP!",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6.0),
        ],

        // Giant Final Score Numerals
        Text(
          '${stats.score}',
          style: TextStyle(
            color: stats.isNewRecord ? const Color(0xFFFFD700) : Colors.white,
            fontSize: 64.0,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 4.0),
        const Text(
          'POINTS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}
