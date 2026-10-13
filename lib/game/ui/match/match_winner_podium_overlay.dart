import 'package:flutter/material.dart';

import '../../../services/firestore_match_service.dart';
import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../common/app_avatar.dart';
import 'match_setup_dialog.dart';
import 'podium/podium_score_matrix.dart';
import 'podium/podium_stats_comparison.dart';
import 'podium/podium_trophy_header.dart';

/// Grand celebration podium overlay shown upon match conclusion.
class MatchWinnerPodiumOverlay extends StatelessWidget {
  final BasketballGame game;
  final MatchSession session;

  const MatchWinnerPodiumOverlay({
    super.key,
    required this.game,
    required this.session,
  });

  Future<void> _handleCloseOrDismiss(BuildContext context) async {
    final matchId = session.cloudMatchId;
    if (matchId != null) {
      try {
        await FirestoreMatchService.instance.deleteMatch(matchId);
      } catch (e) {
        debugPrint('Error evaporating match: $e');
      }
    }
    game.exitToSoloMode();
  }

  @override
  Widget build(BuildContext context) {
    final winner = session.overallWinner;
    final isTie = session.isTie;
    final isP1Winner = winner == session.player1;

    final Color bannerColor = isTie
        ? const Color(0xFFF59E0B)
        : (isP1Winner ? const Color(0xFF22C55E) : const Color(0xFF38BDF8));

    final String winnerDeclaration = isTie
        ? 'MATCH TIED!'
        : (winner != null
              ? '${winner.name.toUpperCase()} WINS!'
              : 'MATCH TIED!');

    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        constraints: BoxConstraints(
          maxWidth: 410.0,
          maxHeight: screenHeight * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 22.0,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF20F172A), Color(0xFA090D16)],
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Trophy Graphic, Declaration & Close Button
                    PodiumTrophyHeader(
                      session: session,
                      bannerColor: bannerColor,
                      winnerDeclaration: winnerDeclaration,
                      isTie: isTie,
                      onClose: () => _handleCloseOrDismiss(context),
                    ),
                    const SizedBox(height: 14.0),

                    // 2. Aggregate Score Display
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
                          _buildAggregateColumn(
                            name: session.player1.name,
                            avatar: session.player1.avatar,
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
                            avatar: session.player2.avatar,
                            score: session.player2.totalScore,
                            color: session.player2.accentColor,
                            isWinner: !isTie && !isP1Winner,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // 3. Round-by-Round Breakdown Matrix
                    PodiumScoreMatrix(session: session),
                    const SizedBox(height: 12.0),

                    // 4. Head-to-Head Shooting Analytics
                    PodiumStatsComparison(session: session),
                    const SizedBox(height: 18.0),

                    // 5. Action Buttons
                    if (session.cloudMatchId != null) ...[
                      // Online Cloud Match: Close & Evaporate Room
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleCloseOrDismiss(context),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'CLOSE ROOM & DISMISS MATCH',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.symmetric(vertical: 13.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              side: const BorderSide(
                                color: Color(0xFF334155),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Local / Pass & Play Actions
                      // Primary Action: REMATCH
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => game.startPassAndPlayMatch(
                            config: session.config,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bannerColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            elevation: 8.0,
                            shadowColor: bannerColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.replay_rounded, size: 20.0),
                              SizedBox(width: 8.0),
                              Text(
                                'REMATCH',
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Secondary Action: MATCH SETTINGS
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final newConfig = await MatchSetupDialog.show(
                              context,
                              initialConfig: session.config,
                            );
                            if (newConfig != null) {
                              game.startPassAndPlayMatch(config: newConfig);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(
                              color: Color(0x6638BDF8),
                              width: 1.0,
                            ),
                            backgroundColor: const Color(0x120284C7),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 18.0),
                              SizedBox(width: 8.0),
                              Text(
                                'MATCH SETTINGS',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Tertiary Action: PRACTICE SOLO
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => game.exitToSoloMode(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                          ),
                          child: const Text(
                            'PRACTICE SOLO',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
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
    required String avatar,
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
            AppAvatar(avatar: avatar, size: 16.0),
            const SizedBox(width: 4.0),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
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
            fontSize: 32.0,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
