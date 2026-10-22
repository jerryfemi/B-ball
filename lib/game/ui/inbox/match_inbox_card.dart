import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../services/chat_read_receipt_service.dart';
import '../common/app_avatar.dart';
import '../common/app_colors.dart';
import '../common/match_status_badge.dart';

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
  final VoidCallback? onLeave;

  const MatchInboxCard({
    super.key,
    required this.match,
    required this.myUid,
    required this.onTap,
    required this.onPlayTurn,
    this.onViewPodium,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isMyTurn = match.isMyTurn(myUid);
    final opponent = match.opponentPlayer(myUid);
    final myPlayer = match.myPlayer(myUid);

    final opponentName = opponent?.displayName ?? 'Waiting...';
    final opponentAvatar = opponent?.avatarEmoji ?? '⏳';
    final myScore = myPlayer?.totalScore ?? 0;
    final opponentScore = opponent?.totalScore ?? 0;

    final hasRootChat = match.lastChatText != null && match.lastChatText!.isNotEmpty;
    final latestChat = match.chat.isNotEmpty ? match.chat.last : null;
    final hasChatSnippet = latestChat != null || hasRootChat;
    final lastRead = ChatReadReceiptService.instance.getMatchLastRead(match.id);
    final hasUnreadBanter = match.hasUnreadChat(myUid, lastRead);
    final snippetText = latestChat?.text ?? match.lastChatText ?? '';
    final snippetSender = latestChat?.senderName ??
        (match.lastChatSenderUid == myUid ? (myPlayer?.displayName ?? 'You') : opponentName);

    final isCompleted = match.isFinished;
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            match.isArchery
                                ? Icons.track_changes_rounded
                                : (match.isDarts
                                    ? Icons.adjust_rounded
                                    : Icons.sports_basketball_rounded),
                            size: 13,
                            color: match.isArchery
                                ? const Color(0xFF10B981)
                                : (match.isDarts
                                    ? const Color(0xFFA855F7)
                                    : const Color(0xFFFF8A00)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isCompleted
                                ? '${CloudMatch.gameTitle(match.game).toUpperCase()} • FINISHED'
                                : (match.isArchery
                                    ? 'ARCHERY • SET ${match.currentRound} OF ${match.totalRounds}'
                                    : 'HOOPS • R${match.currentRound}/${match.totalRounds} • ${match.roundDurationSeconds}S'),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MatchStatusBadge.fromMatch(match: match, myUid: myUid),
                        if (onLeave != null) ...[
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onLeave!();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A64748B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.delete_outline_rounded
                                      : Icons.close_rounded,
                                  size: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                          AppAvatar(
                            avatar: myPlayer?.avatarEmoji ??
                                AppAvatar.defaultAvatar,
                            size: 24,
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
                          AppAvatar(avatar: opponentAvatar, size: 24),
                        ],
                      ),
                    ),
                  ],
                ),

                // Latest banter chip (if available)
                if (hasChatSnippet) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: hasUnreadBanter
                          ? AppColors.accentRed.withValues(alpha: 0.12)
                          : const Color(0xFF0C101A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasUnreadBanter
                            ? AppColors.accentRed.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasUnreadBanter
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline,
                          size: 11,
                          color: hasUnreadBanter
                              ? AppColors.accentRed
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$snippetSender: "$snippetText"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnreadBanter
                                  ? AppColors.accentRed
                                  : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: hasUnreadBanter
                                  ? FontWeight.w700
                                  : FontWeight.normal,
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

}
