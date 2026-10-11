import 'dart:ui';
import 'package:flutter/material.dart';

import '../../basketball_game.dart';
import '../../match/match_session.dart';

/// Grand celebration podium overlay shown upon match conclusion.
///
/// Features:
/// 1. Frosted obsidian glass modal with golden victory aura
/// 2. Crown / trophy presentation with winner declaration
/// 3. Aggregate match score and round-by-round score tally
/// 4. Rematch and Solo Mode navigation triggers
class MatchWinnerPodiumOverlay extends StatelessWidget {
  final BasketballGame game;
  final MatchSession session;

  const MatchWinnerPodiumOverlay({
    super.key,
    required this.game,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final winner = session.overallWinner;
    final isTie = session.isTie;
    final isP1Winner = winner == session.player1;

    final Color bannerColor = isTie
        ? const Color(0xFFF59E0B)
        : (isP1Winner ? const Color(0xFF22C55E) : const Color(0xFF38BDF8));

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        constraints: const BoxConstraints(maxWidth: 390.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xF00F172A),
                    Color(0xFA090D16),
                  ],
                ),
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(
                  color: bannerColor.withValues(alpha: 0.60),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bannerColor.withValues(alpha: 0.25),
                    blurRadius: 36.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Trophy Graphic & Declaration
                  Container(
                    width: 64.0,
                    height: 64.0,
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: bannerColor.withValues(alpha: 0.50),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isTie ? '🤝' : '🏆',
                        style: const TextStyle(fontSize: 32.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    isTie
                        ? 'MATCH TIED!'
                        : (isP1Winner ? 'YOU WIN!' : 'THEM WINS!'),
                    style: TextStyle(
                      color: bannerColor,
                      fontSize: 24.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${session.totalRounds}-ROUND 1V1 MATCH FINAL',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // 2. Aggregate Score Display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 14.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06060A),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: const Color(0x28FFFFFF),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAggregateColumn(
                          name: session.player1.name,
                          score: session.player1.totalScore,
                          color: session.player1.accentColor,
                          isWinner: isP1Winner,
                        ),
                        const Text(
                          'VS',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        _buildAggregateColumn(
                          name: session.player2.name,
                          score: session.player2.totalScore,
                          color: session.player2.accentColor,
                          isWinner: !isTie && !isP1Winner,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 3. Round-by-Round Breakdown
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < session.totalRounds; i++) ...[
                          if (i > 0)
                            const Divider(
                              color: Color(0x1FFFFFFF),
                              height: 10.0,
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
                  ),
                  const SizedBox(height: 22.0),

                  // 4. Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => game.startPassAndPlayMatch(
                        totalRounds: session.totalRounds,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        elevation: 8.0,
                        shadowColor:
                            const Color(0xFF22C55E).withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded, size: 22.0),
                          SizedBox(width: 8.0),
                          Text(
                            'REMATCH',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => game.exitToSoloMode(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(
                          color: Color(0x38FFFFFF),
                          width: 1.0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      child: const Text(
                        'PRACTICE SOLO',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAggregateColumn({
    required String name,
    required int score,
    required Color color,
    required bool isWinner,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            if (isWinner) ...[
              const SizedBox(width: 4.0),
              const Text('👑', style: TextStyle(fontSize: 12.0)),
            ],
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34.0,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildRoundRow({
    required int roundNumber,
    required int p1Score,
    required int p2Score,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ROUND $roundNumber',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: [
              Text(
                '$p1Score',
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                ' - ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
              ),
              Text(
                '$p2Score',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
