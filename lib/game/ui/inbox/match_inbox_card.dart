import 'package:flutter/material.dart';
import '../../../models/cloud_match.dart';

/// Card component representing an active or completed match conversation thread.
class MatchInboxCard extends StatelessWidget {
  final CloudMatch match;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onPlayTurn;

  const MatchInboxCard({
    super.key,
    required this.match,
    required this.myUid,
    required this.onTap,
    required this.onPlayTurn,
  });

  @override
  Widget build(BuildContext context) {
    final isMyTurn = match.isMyTurn(myUid);
    final opponent = match.opponentPlayer(myUid);
    final myPlayer = match.myPlayer(myUid);

    final opponentName = opponent?.displayName ?? 'Waiting for opponent...';
    final opponentAvatar = opponent?.avatarEmoji ?? '⏳';

    final latestChat = match.chat.isNotEmpty ? match.chat.last : null;

    final isCompleted = match.status == MatchStatus.completed;
    final isWaitingOpponent = match.status == MatchStatus.waitingForOpponent;

    Color borderColor;
    if (isMyTurn) {
      borderColor = const Color(0xFF00FFCC);
    } else if (isCompleted) {
      borderColor = const Color(0xFF64748B);
    } else {
      borderColor = const Color(0xFF334155);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF192033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isMyTurn ? 1.6 : 1.0),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Opponent info + Round badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26324A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(opponentAvatar, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opponentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCompleted
                                ? 'Final Score: ${myPlayer?.totalScore ?? 0} - ${opponent?.totalScore ?? 0}'
                                : 'Round ${match.currentRound} of ${match.totalRounds}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(isMyTurn, isCompleted, isWaitingOpponent),
                  ],
                ),

                // Banter snippet row (if available)
                if (latestChat != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131826),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(latestChat.senderAvatar, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${latestChat.senderName}: "${latestChat.text}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action footer if it's your turn
                if (isMyTurn && !isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPlayTurn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'PLAY TURN 🏀',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isMyTurn, bool isCompleted, bool isWaitingOpponent) {
    if (isCompleted) {
      final won = match.winnerUid == myUid;
      final tie = match.outcome == MatchOutcome.tie;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tie
              ? Colors.amber.withValues(alpha: 0.15)
              : won
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          tie ? 'TIED' : won ? 'WON 👑' : 'LOST',
          style: TextStyle(
            color: tie
                ? Colors.amber
                : won
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (isWaitingOpponent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'WAITING',
          style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
    }

    if (isMyTurn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00FFCC), width: 1.2),
        ),
        child: const Text(
          'YOUR TURN',
          style: TextStyle(color: Color(0xFF00FFCC), fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'THEIR TURN',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
