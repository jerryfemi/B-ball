import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/cloud_match.dart';
import '../../../models/player_descriptor.dart';
import '../../../providers/app_providers.dart';
import '../../../services/firestore_match_service.dart';
import '../common/app_avatar.dart';
import '../common/app_modal_sheet.dart';
import '../common/chat/chat_bubble_list.dart';
import '../common/chat/chat_input_bar.dart';

/// Modal sheet showing the live game conversation thread, round score breakdown, and banter chat.
class MatchThreadDialog extends HookConsumerWidget {
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

  static const List<String> _quickBanter = [
    '🧱 Brick!',
    '🎯 Swish!',
    '🔥 On fire!',
    '🥶 Ice cold!',
    '🍀 Lucky bounce!',
    '👑 Rematch?',
  ];

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
  Widget build(BuildContext context, WidgetRef ref) {
    final msgController = useTextEditingController();
    final scrollController = useScrollController();

    Future<void> sendText(
      String matchId,
      CloudPlayer myPlayer,
      String text,
    ) async {
      final clean = text.trim();
      if (clean.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final msg = CloudChatMessage(
        id: '${now}_$myUid',
        senderUid: myUid,
        senderName: myPlayer.displayName,
        senderAvatar: myPlayer.avatarEmoji,
        text: clean,
        timestamp: now,
      );

      msgController.clear();
      HapticFeedback.lightImpact();
      await FirestoreMatchService.instance.sendChatMessage(
        matchId: matchId,
        message: msg,
      );

      Future.delayed(const Duration(milliseconds: 150), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    final match = ref.watch(singleMatchProvider(initialMatch.id)).value ?? initialMatch;
        final myPlayer =
            match.myPlayer(myUid) ??
            CloudPlayer(
              uid: myUid,
              displayName: 'You',
              avatarEmoji: PlayerDescriptor.defaultAvatar,
              roundScores: const [],
            );
        final opponent = match.opponentPlayer(myUid);
        final isMyTurn = match.isMyTurn(myUid);
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
                  child: ChatBubbleList(
                    messages: match.chat,
                    myUid: myUid,
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),

                // Quick banter & text input bar
                ChatInputBar(
                  controller: msgController,
                  quickBanter: _quickBanter,
                  onSend: (text) => sendText(match.id, myPlayer, text),
                  hintText: 'Type banter message...',
                  accentColor: const Color(0xFF00FFCC),
                  padding: EdgeInsets.zero,
                ),

                // Primary Bottom Action Bar (shown when completed or when it is my turn)
                if (isCompleted) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewPodium?.call();
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
                      onPlayTurn();
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
}

