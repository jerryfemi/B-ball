import 'package:flutter/material.dart';

import '../../../match/match_session.dart';

/// Round-by-round score matrix comparing Player 1 and Player 2 scores.
class PodiumScoreMatrix extends StatelessWidget {
  final MatchSession session;

  const PodiumScoreMatrix({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: const Color(0x1AFFFFFF),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ROUND BREAKDOWN',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  Text(
                    session.displayNameFor(session.player1).toUpperCase(),
                    style: TextStyle(
                      color: session.player1.accentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    ' vs ',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 9.5,
                    ),
                  ),
                  Text(
                    session.player2.name.toUpperCase(),
                    style: TextStyle(
                      color: session.player2.accentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          for (int i = 0; i < session.totalRounds; i++) ...[
            if (i > 0)
              const Divider(
                color: Color(0x1FFFFFFF),
                height: 8.0,
              ),
            _buildRoundRow(
              roundNumber: i + 1,
              p1Score: i < session.player1.roundScores.length
                  ? session.player1.roundScores[i]
                  : 0,
              p2Score: i < session.player2.roundScores.length
                  ? session.player2.roundScores[i]
                  : 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundRow({
    required int roundNumber,
    required int p1Score,
    required int p2Score,
  }) {
    final bool p1WonRound = p1Score > p2Score;
    final bool p2WonRound = p2Score > p1Score;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p1WonRound
                      ? const Color(0xFF22C55E)
                      : (p2WonRound
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                'ROUND $roundNumber',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '$p1Score',
                style: TextStyle(
                  color: p1WonRound
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF94A3B8),
                  fontSize: 13.0,
                  fontWeight: p1WonRound ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const Text(
                ' - ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
              ),
              Text(
                '$p2Score',
                style: TextStyle(
                  color: p2WonRound
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF94A3B8),
                  fontSize: 13.0,
                  fontWeight: p2WonRound ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
