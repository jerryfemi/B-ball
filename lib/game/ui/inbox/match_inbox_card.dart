import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';

/// Punchy Arcade Head-to-Head Versus Match Card.
///
/// Clearly displays the head-to-head score comparison, opponent identity,
/// round progression, banter snippet, and 1-tap direct shoot action.
class MatchInboxCard extends StatelessWidget {
  final CloudMatch match;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onPlayTurn;
  final VoidCallback? onViewPodium;

  const MatchInboxCard({
    super.key,
    required this.match,
    required this.myUid,
    required this.onTap,
    required this.onPlayTurn,
    this.onViewPodium,
  });

  Widget _buildAvatarView(String avatar, {double size = 22}) {
    if (avatar.startsWith('assets/') ||
        avatar.endsWith('.png') ||
        avatar.endsWith('.jpg') ||
        avatar.endsWith('.jpeg') ||
        avatar.endsWith('.webp')) {
      return ClipOval(
        child: Image.asset(
          avatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Text('🏀', style: TextStyle(fontSize: size * 0.85)),
        ),
      );
    }
    return Text(avatar, style: TextStyle(fontSize: size));
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = match.isMyTurn(myUid);
    final opponent = match.opponentPlayer(myUid);
    final myPlayer = match.myPlayer(myUid);

    final opponentName = opponent?.displayName ?? 'Waiting...';
    final opponentAvatar = opponent?.avatarEmoji ?? '⏳';
    final myScore = myPlayer?.totalScore ?? 0;
    final opponentScore = opponent?.totalScore ?? 0;

    final latestChat = match.chat.isNotEmpty ? match.chat.last : null;
    final isCompleted = match.status == MatchStatus.completed;
    final isWaitingOpponent = match.status == MatchStatus.waitingForOpponent;

    final borderColor = isMyTurn && !isCompleted
        ? const Color(0xFF00FFCC)
        : (isCompleted ? const Color(0xFF334155) : const Color(0xFF1E293B));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isMyTurn && !isCompleted ? 1.6 : 1.0,
        ),
        boxShadow: isMyTurn && !isCompleted
            ? [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top line: Round badge & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted
                            ? 'MATCH FINISHED'
                            : 'ROUND ${match.currentRound} OF ${match.totalRounds} • ${match.roundDurationSeconds}S',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildStatusPill(isMyTurn, isCompleted, isWaitingOpponent),
                  ],
                ),
                const SizedBox(height: 12),

                // Center Versus Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: You
                    Expanded(
                      child: Row(
                        children: [
                          _buildAvatarView(
                            myPlayer?.avatarEmoji ??
                                'assets/avatars/dunk_heads (1).webp',
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  myPlayer?.displayName ?? 'You',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: Color(0xFF00FFCC),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$myScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center VS Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: const Color(0xFF64748B).withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    // Right: Opponent
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isWaitingOpponent ? '--' : '$opponentScore',
                            style: TextStyle(
                              color: isWaitingOpponent
                                  ? const Color(0xFF64748B)
                                  : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  opponentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'OPPONENT',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildAvatarView(opponentAvatar, size: 22),
                        ],
                      ),
                    ),
                  ],
                ),

                // Latest banter chip (if available)
                if (latestChat != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C101A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 11,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${latestChat.senderName}: "${latestChat.text}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Footer
                if (isMyTurn && !isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onPlayTurn();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_basketball_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'SHOOT TURN ➔',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (isCompleted && onViewPodium != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: onViewPodium,
                      icon: const Icon(Icons.emoji_events_outlined, size: 14),
                      label: const Text(
                        'VIEW PODIUM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Color(0xFF475569)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildStatusPill(
    bool isMyTurn,
    bool isCompleted,
    bool isWaitingOpponent,
  ) {
    if (isCompleted) {
      final won = match.winnerUid == myUid;
      final tie = match.outcome == MatchOutcome.tie;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tie
              ? Colors.amber.withValues(alpha: 0.15)
              : won
              ? const Color(0xFF22C55E).withValues(alpha: 0.15)
              : const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tie
              ? 'TIED 🤝'
              : won
              ? 'WON 👑'
              : 'LOST 💥',
          style: TextStyle(
            color: tie
                ? Colors.amber
                : won
                ? const Color(0xFF22C55E)
                : const Color(0xFFEF4444),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (isWaitingOpponent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'WAITING FOR OPPONENT',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (isMyTurn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00FFCC), width: 1.0),
        ),
        child: const Text(
          'YOUR TURN ⚡',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'THEIR TURN ⏳',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
