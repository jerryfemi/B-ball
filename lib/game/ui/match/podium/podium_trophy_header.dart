import 'package:flutter/material.dart';

import '../../../match/match_session.dart';

/// Top section of the Winner Podium showing the Trophy icon, winner banner, and subtitle.
class PodiumTrophyHeader extends StatelessWidget {
  final MatchSession session;
  final Color bannerColor;
  final String winnerDeclaration;
  final bool isTie;
  final VoidCallback onClose;

  const PodiumTrophyHeader({
    super.key,
    required this.session,
    required this.bannerColor,
    required this.winnerDeclaration,
    required this.isTie,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                onPressed: onClose,
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
          session.isForfeit
              ? (session.forfeitWinner == session.player1
                  ? 'VICTORY BY OPPONENT FORFEIT'
                  : 'MATCH CONCEDED BY FORFEIT')
              : '${session.totalRounds}-ROUND 1V1 MATCH FINAL',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
