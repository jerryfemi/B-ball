import 'dart:ui';
import 'package:flutter/material.dart';

import '../../basketball_game.dart';
import '../../match/match_session.dart';

/// Modal dialog shown between match rounds and player turns.
///
/// Features:
/// 1. Frosted obsidian glass modal with neon boundary
/// 2. Clear recap of the completed turn and running match aggregate score
/// 3. Pass-and-play phone handoff prompt
/// 4. Options to watch opponent's round replay or jump directly into the turn
class RoundIntermissionOverlay extends StatelessWidget {
  final BasketballGame game;
  final MatchSession session;

  const RoundIntermissionOverlay({
    super.key,
    required this.game,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final opponent = session.opponentPlayer;
    final activePlayer = session.activePlayer;
    final hasOpponentReplay = opponent.latestTelemetry != null &&
        opponent.latestTelemetry!.shots.isNotEmpty;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        constraints: const BoxConstraints(maxWidth: 380.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 26.0,
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
                  color: const Color(0x38FFFFFF),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 32.0,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Round Status Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22F59E0B),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: const Color(0x66F59E0B),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'ROUND ${session.currentRoundNumber} OF ${session.totalRounds}',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 2. Scoreboard Match Tally Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
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
                        _buildPlayerTally(
                          name: session.player1.name,
                          score: session.player1.totalScore,
                          color: session.player1.accentColor,
                        ),
                        Container(
                          height: 36.0,
                          width: 1.0,
                          color: const Color(0x28FFFFFF),
                        ),
                        _buildPlayerTally(
                          name: session.player2.name,
                          score: session.player2.totalScore,
                          color: session.player2.accentColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // 3. Pass Device Callout
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: activePlayer.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: activePlayer.accentColor.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smartphone_rounded,
                          color: activePlayer.accentColor,
                          size: 22.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'PASS TO ${activePlayer.name.toUpperCase()}',
                          style: TextStyle(
                            color: activePlayer.accentColor,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22.0),

                  // 4. Action Buttons
                  if (hasOpponentReplay) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => game.startOpponentReplay(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0x2238BDF8),
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(
                            color: Color(0x6638BDF8),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_rounded, size: 20.0),
                            const SizedBox(width: 8.0),
                            Text(
                              "WATCH ${opponent.name.toUpperCase()}'S REPLAY",
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => game.startMatchTurn(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        elevation: 6.0,
                        shadowColor:
                            const Color(0xFF22C55E).withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 22.0),
                          const SizedBox(width: 8.0),
                          Text(
                            hasOpponentReplay
                                ? 'START MY TURN NOW'
                                : 'START TURN',
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
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

  Widget _buildPlayerTally({
    required String name,
    required int score,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28.0,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const Text(
          'PTS',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
