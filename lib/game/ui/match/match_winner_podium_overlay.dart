import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/firestore_match_service.dart';
import '../../basketball_game.dart';
import '../../match/match_session.dart';
import '../common/app_avatar.dart';
import 'match_setup_dialog.dart';

/// Grand celebration podium overlay shown upon match conclusion.
///
/// Features:
/// 1. Frosted obsidian glass modal with golden victory aura
/// 2. Trophy presentation with dynamic winner declaration
/// 3. Aggregate match score with player avatars
/// 4. Detailed round-by-round scoreboard matrix (supports 2, 3, or 4 rounds)
/// 5. Head-to-head performance analytics (Accuracy %, Swishes, Best Streak, Field Goals)
/// 6. "REMATCH", "MATCH SETTINGS", and "PRACTICE SOLO" action triggers
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Container(
                            width: 58.0,
                            height: 58.0,
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
                                style: const TextStyle(fontSize: 28.0),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                              size: 22,
                            ),
                            tooltip: 'Close Match',
                            onPressed: () => _handleCloseOrDismiss(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      winnerDeclaration,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: bannerColor,
                        fontSize: 23.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      '${session.totalRounds}-ROUND 1V1 MATCH FINAL',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
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
                    Container(
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
                                    session.player1.name.toUpperCase(),
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
                    ),
                    const SizedBox(height: 12.0),

                    // 4. Head-to-Head Shooting Analytics
                    _buildHeadToHeadStats(),
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
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 6.0,
                            shadowColor: const Color(0xFFEF4444)
                                .withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),
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
                    ] else ...[
                      // Local Pass & Play: REMATCH with identical parameters
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => game.startPassAndPlayMatch(
                            config: session.config,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            elevation: 6.0,
                            shadowColor: const Color(0xFF22C55E)
                                .withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
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

  Widget _buildHeadToHeadStats() {
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
