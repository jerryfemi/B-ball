import 'dart:ui';
import 'package:flutter/material.dart';

import '../../basketball_game.dart';
import '../../match/match_session.dart';

/// Turn completion & handoff modal shown between match turns (GamePigeon style).
///
/// Workflow:
/// 1. Shooter finishes their 60-second round.
/// 2. Modal recaps their round score and running match standings.
/// 3. Shooter taps "SEND GAME ➔" to pass the turn to the opponent.
/// 4. Opponent automatically sees the shooter's ghost shots play on court,
///    with a clear "SKIP ❯❯" button to begin their turn at any moment.
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
    final shooter = session.activePlayer;
    final recipient = session.activePlayerIndex == 0 ? session.player2 : session.player1;
    final roundScore = shooter.roundScores.isNotEmpty ? shooter.roundScores.last : 0;

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
                  color: shooter.accentColor.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shooter.accentColor.withValues(alpha: 0.18),
                    blurRadius: 32.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Round Status Header Capsule
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
                      'ROUND ${session.currentRoundNumber} OF ${session.totalRounds} COMPLETED',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // 2. Shooter Performance Callout
                  Text(
                    '${shooter.name.toUpperCase()} SCORED',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$roundScore',
                        style: TextStyle(
                          color: shooter.accentColor,
                          fontSize: 48.0,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: shooter.accentColor.withValues(alpha: 0.6),
                              blurRadius: 20.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      const Text(
                        'PTS',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18.0),

                  // 3. Match Running Scoreboard
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
                          isHighlight: shooter == session.player1,
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
                          isHighlight: shooter == session.player2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // 4. Primary "SEND GAME" Button (GamePigeon Style)
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF22C55E),
                            Color(0xFF16A34A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5522C55E),
                            blurRadius: 18.0,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => game.sendMatchTurn(),
                          borderRadius: BorderRadius.circular(18.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14.0,
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  'SEND GAME ➔',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    "${recipient.name} will watch your ghost shots & take their turn",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // 5. Exit Match Discreet Button
                  TextButton(
                    onPressed: () => game.exitToSoloMode(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                    ),
                    child: const Text(
                      'EXIT MATCH',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
    required bool isHighlight,
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 28.0,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
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
