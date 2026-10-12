import 'dart:ui';

import 'package:flutter/material.dart';

import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../common/app_avatar.dart';
import '../inbox/share_turn_sheet.dart';

/// Clean, non-intrusive Round Over recap modal.
///
/// Features:
/// - Clear '✕' dismiss button to view the court or exit
/// - Score callout with shooting stats
/// - Discrete share / copy code action for online 1v1
/// - Clean continue button without confusing exit labels
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
    final roundScore = shooter.roundScores.isNotEmpty
        ? shooter.roundScores.last
        : 0;
    final isOnline = session.mode == MatchGameMode.onlineCloud1v1;
    final lastTelemetry = game.lastRoundTelemetry;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        constraints: const BoxConstraints(maxWidth: 380.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 22.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF131826).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: shooter.accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shooter.accentColor.withValues(alpha: 0.15),
                    blurRadius: 28.0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar with status pill & '✕' close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x22F59E0B),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: const Color(0x66F59E0B),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          'ROUND ${session.currentRoundNumber} OF ${session.totalRounds} OVER',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 22,
                        ),
                        onPressed: () => game.exitToSoloMode(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Shooter score callout
                  Text(
                    '$roundScore',
                    style: TextStyle(
                      color: shooter.accentColor,
                      fontSize: 48.0,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: shooter.accentColor.withValues(alpha: 0.5),
                          blurRadius: 18.0,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'POINTS SCORED',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (lastTelemetry != null) ...[
                    const SizedBox(height: 6.0),
                    Text(
                      '${lastTelemetry.madeShots}/${lastTelemetry.totalShots} shots made • ${lastTelemetry.swishCount} swishes',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16.0),

                  // Standings box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: const Color(0xFF26324A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPlayerTally(
                          name: session.player1.name,
                          avatar: session.player1.avatar,
                          score: session.player1.totalScore,
                          color: session.player1.accentColor,
                          isHighlight: shooter == session.player1,
                        ),
                        Container(
                          height: 30.0,
                          width: 1.0,
                          color: const Color(0xFF26324A),
                        ),
                        _buildPlayerTally(
                          name: session.player2.name,
                          avatar: session.player2.avatar,
                          score: session.player2.totalScore,
                          color: session.player2.accentColor,
                          isHighlight: shooter == session.player2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Online 1v1 Room Code or Turn Status
                  if (isOnline) ...[
                    if (session.isWaitingForOpponent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.dialpad,
                              size: 16.0,
                              color: Color(0xFF00FFCC),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'Match Code: ${session.cloudMatchId ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.0,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                ShareTurnSheet.show(
                                  context,
                                  joinCode: session.cloudMatchId ?? '',
                                  roundIndex: session.currentRoundNumber,
                                  roundScore: roundScore,
                                  opponentName: session.player2.name,
                                );
                              },
                              borderRadius: BorderRadius.circular(8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 5.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.share,
                                      size: 13.0,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4.0),
                                    Text(
                                      'Share',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16.0,
                              color: Color(0xFF00FFCC),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'Turn Sent • Waiting for ${session.player2.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14.0),
                  ],

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 46.0,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isOnline) {
                          game.stayInMatchCourt();
                        } else {
                          game.sendMatchTurn();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        isOnline
                            ? 'BACK TO COURT ➔'
                            : 'PASS DEVICE TO ${session.player2.name.toUpperCase()} ➔',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.0,
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


  Widget _buildPlayerTally({
    required String name,
    required String avatar,
    required int score,
    required Color color,
    required bool isHighlight,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(avatar: avatar, size: 16.0),
            const SizedBox(width: 4.0),
            Text(
              name,
              style: TextStyle(
                color: isHighlight ? color : const Color(0xFF94A3B8),
                fontSize: 11.0,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          '$score',
          style: TextStyle(
            color: isHighlight ? Colors.white : const Color(0xFFCBD5E1),
            fontSize: 20.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
