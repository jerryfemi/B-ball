import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_avatar.dart';
import '../common/app_modal_sheet.dart';

/// Modal sheet showing the live game conversation thread, round score breakdown, and banter chat.
class MatchThreadDialog extends StatefulWidget {
  final CloudMatch initialMatch;
  final String myUid;
  final VoidCallback onPlayTurn;
  final VoidCallback? onViewPodium;

  const MatchThreadDialog({
    super.key,
    required this.initialMatch,
    required this.myUid,
    required this.onPlayTurn,
    this.onViewPodium,
  });

  static Future<void> show(
    BuildContext context, {
    required CloudMatch match,
    required String myUid,
    required VoidCallback onPlayTurn,
    VoidCallback? onViewPodium,
  }) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => MatchThreadDialog(
        initialMatch: match,
        myUid: myUid,
        onPlayTurn: onPlayTurn,
        onViewPodium: onViewPodium,
      ),
    );
  }

  @override
  State<MatchThreadDialog> createState() => _MatchThreadDialogState();
}

class _MatchThreadDialogState extends State<MatchThreadDialog> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _quickBanter = [
    '🧱 Brick!',
    '🎯 Swish!',
    '🔥 On fire!',
    '🥶 Ice cold!',
    '🍀 Lucky bounce!',
    '👑 Rematch?',
  ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText(
    String matchId,
    CloudPlayer myPlayer,
    String text,
  ) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final msg = CloudChatMessage(
      id: '${now}_${widget.myUid}',
      senderUid: widget.myUid,
      senderName: myPlayer.displayName,
      senderAvatar: myPlayer.avatarEmoji,
      text: clean,
      timestamp: now,
    );

    _msgController.clear();
    HapticFeedback.lightImpact();
    await FirestoreMatchService.instance.sendChatMessage(
      matchId: matchId,
      message: msg,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CloudMatch?>(
      stream: FirestoreMatchService.instance.streamMatch(
        widget.initialMatch.id,
      ),
      initialData: widget.initialMatch,
      builder: (context, snapshot) {
        final match = snapshot.data ?? widget.initialMatch;
        final myPlayer =
            match.myPlayer(widget.myUid) ??
            CloudPlayer(
              uid: widget.myUid,
              displayName: 'You',
              avatarEmoji: 'assets/avatars/dunk_heads (1).webp',
              roundScores: const [],
            );
        final opponent = match.opponentPlayer(widget.myUid);
        final isMyTurn = match.isMyTurn(widget.myUid);
        final isCompleted = match.status == MatchStatus.completed;

        return AppModalSheet(
          heightFactor: 0.85,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                AppAvatar(
                  avatar: opponent?.avatarEmoji ??
                      'assets/avatars/dunk_heads (2).webp',
                  size: 36,
                  borderColor: const Color(0xFF38BDF8),
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponent?.displayName ?? 'Waiting for opponent',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: match.joinCode),
                              );
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Match code ${match.joinCode} copied! 📋',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF1E2638),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Code: ${match.joinCode}',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.copy_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Round ${match.currentRound}/${match.totalRounds}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Mini Scoreboard Matrix
                _buildMiniScoreboard(match, myPlayer, opponent),
                const SizedBox(height: 12),

                // Chat banter list
                Expanded(
                  child: match.chat.isEmpty
                      ? const Center(
                          child: Text(
                            'No banter yet. Send a reaction below! 🎯',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: match.chat.length,
                          itemBuilder: (ctx, i) {
                            final msg = match.chat[i];
                            final isMe = msg.senderUid == widget.myUid;
                            return _buildChatBubble(msg, isMe);
                          },
                        ),
                ),

                // Quick banter chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickBanter.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final text = _quickBanter[i];
                      return ActionChip(
                        label: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: const Color(0xFF1E2638),
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () => _sendText(match.id, myPlayer, text),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Text Input Field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type banter message...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E2638),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        onSubmitted: (val) =>
                            _sendText(match.id, myPlayer, val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF00FFCC),
                        size: 20,
                      ),
                      onPressed: () =>
                          _sendText(match.id, myPlayer, _msgController.text),
                    ),
                  ],
                ),

                // Primary Bottom Action Bar (shown when completed or when it is my turn)
                if (isCompleted) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onViewPodium?.call();
                    },
                    icon: const Icon(Icons.emoji_events, size: 18),
                    label: const Text('VIEW WINNER PODIUM 🏆'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ] else if (isMyTurn) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPlayTurn();
                    },
                    icon: const Icon(Icons.sports_basketball, size: 18),
                    label: Text('PLAY ROUND ${match.currentRound} NOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniScoreboard(
    CloudMatch match,
    CloudPlayer myPlayer,
    CloudPlayer? opponent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2234),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E3954)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreColumn(
            myPlayer.displayName,
            myPlayer.totalScore,
            const Color(0xFF00FFCC),
          ),
          const Text(
            'VS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          _buildScoreColumn(
            opponent?.displayName ?? 'Opponent',
            opponent?.totalScore ?? 0,
            const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String name, int score, Color color) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(CloudChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(avatar: msg.senderAvatar, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
