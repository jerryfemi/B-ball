import 'package:flutter/material.dart';

import '../../basketball_game.dart';

/// 2x2 grid displaying shooting statistics at the end of a round.
class GameOverStatsGrid extends StatelessWidget {
  final GameRoundStats stats;

  const GameOverStatsGrid({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0x40020617),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: const Color(0x20FFFFFF),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GameOverStatTile(
                  label: 'FIELD GOALS',
                  value: '${stats.madeShots}/${stats.totalShots}',
                  subtitle: '${stats.accuracy.toStringAsFixed(0)}% ACC',
                ),
              ),
              Container(
                width: 1.0,
                height: 38.0,
                color: const Color(0x20FFFFFF),
              ),
              Expanded(
                child: GameOverStatTile(
                  label: 'BEST STREAK',
                  value: '⚡ x${stats.bestStreak}',
                  subtitle: stats.bestStreak >= 3 ? 'ON FIRE' : 'IN A ROW',
                ),
              ),
            ],
          ),
          const Divider(
            color: Color(0x20FFFFFF),
            height: 20.0,
          ),
          Row(
            children: [
              Expanded(
                child: GameOverStatTile(
                  label: 'SWISHES (+3)',
                  value: '🔥 ${stats.swishCount}',
                  subtitle: 'CLEAN NET',
                ),
              ),
              Container(
                width: 1.0,
                height: 38.0,
                color: const Color(0x20FFFFFF),
              ),
              Expanded(
                child: GameOverStatTile(
                  label: 'BANK SHOTS (+3)',
                  value: '🎯 ${stats.bankCount}',
                  subtitle: 'OFF GLASS',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual statistic metric display tile.
class GameOverStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const GameOverStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1.0),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
