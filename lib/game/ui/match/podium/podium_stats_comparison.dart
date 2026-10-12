import 'package:flutter/material.dart';

import '../../../match/match_session.dart';

/// Detailed shooting analytics comparison table (Accuracy, Swishes, Streaks, Field Goals).
class PodiumStatsComparison extends StatelessWidget {
  final MatchSession session;

  const PodiumStatsComparison({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final p1 = session.player1;
    final p2 = session.player2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0x10FFFFFF),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1.0),
      ),
      child: Column(
        children: [
          _buildStatComparisonRow(
            label: 'ACCURACY',
            p1Value: '${p1.overallAccuracy.toStringAsFixed(1)}%',
            p2Value: '${p2.overallAccuracy.toStringAsFixed(1)}%',
            p1Higher: p1.overallAccuracy > p2.overallAccuracy,
            p2Higher: p2.overallAccuracy > p1.overallAccuracy,
          ),
          const Divider(color: Color(0x14FFFFFF), height: 10.0),
          _buildStatComparisonRow(
            label: 'SWISHES',
            p1Value: '${p1.totalSwishes}',
            p2Value: '${p2.totalSwishes}',
            p1Higher: p1.totalSwishes > p2.totalSwishes,
            p2Higher: p2.totalSwishes > p1.totalSwishes,
          ),
          const Divider(color: Color(0x14FFFFFF), height: 10.0),
          _buildStatComparisonRow(
            label: 'BEST STREAK',
            p1Value: 'x${p1.bestStreakAcrossMatch}',
            p2Value: 'x${p2.bestStreakAcrossMatch}',
            p1Higher: p1.bestStreakAcrossMatch > p2.bestStreakAcrossMatch,
            p2Higher: p2.bestStreakAcrossMatch > p1.bestStreakAcrossMatch,
          ),
          const Divider(color: Color(0x14FFFFFF), height: 10.0),
          _buildStatComparisonRow(
            label: 'FIELD GOALS',
            p1Value: '${p1.totalMadeShots}/${p1.totalAttemptedShots}',
            p2Value: '${p2.totalMadeShots}/${p2.totalAttemptedShots}',
            p1Higher: p1.totalMadeShots > p2.totalMadeShots,
            p2Higher: p2.totalMadeShots > p1.totalMadeShots,
          ),
        ],
      ),
    );
  }

  Widget _buildStatComparisonRow({
    required String label,
    required String p1Value,
    required String p2Value,
    required bool p1Higher,
    required bool p2Higher,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 65.0,
          child: Text(
            p1Value,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: p1Higher
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFCBD5E1),
              fontSize: 11.5,
              fontWeight: p1Higher ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(
          width: 65.0,
          child: Text(
            p2Value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: p2Higher
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFFCBD5E1),
              fontSize: 11.5,
              fontWeight: p2Higher ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
