import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../models/player_descriptor.dart';
import '../../../providers/app_providers.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_read_receipt_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../../match/match_config.dart';
import '../common/app_avatar.dart';
import '../common/app_modal_sheet.dart';
import '../common/chat/chat_bubble_list.dart';
import '../common/chat/chat_input_bar.dart';
import '../match/match_lobby_dialog.dart';
import '../match/match_setup_dialog.dart';

/// GamePigeon-style conversation screen featuring a sticky top 1v1 match banner,
/// persistent chat banter feed, and keyboard-safe layout.
class FriendConversationSheet extends HookConsumerWidget {
  final FriendProfile friend;
  final String myUid;
  final CloudMatch? activeMatch;
  final ValueChanged<CloudMatch> onPlayTurn;
  final ValueChanged<CloudMatch>? onViewPodium;

  const FriendConversationSheet({
    super.key,
    required this.friend,
    required this.myUid,
    this.activeMatch,
    required this.onPlayTurn,
    this.onViewPodium,
  });

  static const List<String> _quickBanter = [
    '🎯 Swish!',
    '🧱 Brick!',
    '🔥 On fire!',
    '🥶 Ice cold!',
    '👑 Rematch?',
    '🏀 Your turn!',
  ];

  static Future<void> show(
    BuildContext context, {
    required FriendProfile friend,
    required String myUid,
    CloudMatch? activeMatch,
    required ValueChanged<CloudMatch> onPlayTurn,
    ValueChanged<CloudMatch>? onViewPodium,
  }) {
    return AppModalSheet.show<void>(
      context: context,
      builder: (ctx) => FriendConversationSheet(
        friend: friend,
        myUid: myUid,
        activeMatch: activeMatch,
        onPlayTurn: onPlayTurn,
        onViewPodium: onViewPodium,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgController = useTextEditingController();
    final scrollController = useScrollController();
    final currentMatch = useState<CloudMatch?>(activeMatch);
    final currentUser = ref.watch(currentUserProfileProvider).value;

    useEffect(() {
      ChatReadReceiptService.instance.markFriendChatRead(friend.uid);
      if (activeMatch != null) {
        ChatReadReceiptService.instance.markMatchRead(activeMatch!.id);
      }
      return () {
        ChatReadReceiptService.instance.markFriendChatRead(friend.uid);
        if (activeMatch != null) {
          ChatReadReceiptService.instance.markMatchRead(activeMatch!.id);
        }
      };
    }, [friend.uid, activeMatch?.id]);

    void scrollToBottom() {
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

    Future<void> sendText(String text) async {
      final clean = text.trim();
      if (clean.isEmpty) return;

      final user = currentUser;
      final myName = user?.displayName ?? 'You';
      final myAvatar = user?.avatarEmoji ?? PlayerDescriptor.defaultAvatar;
      final now = DateTime.now().millisecondsSinceEpoch;

      final msg = CloudChatMessage(
        id: '${now}_$myUid',
        senderUid: myUid,
        senderName: myName,
        senderAvatar: myAvatar,
        text: clean,
        timestamp: now,
      );

      msgController.clear();
      HapticFeedback.lightImpact();

      await FriendsService.instance.sendDirectMessage(
        fromUid: myUid,
        toUid: friend.uid,
        message: msg,
      );

      final active = currentMatch.value;
      if (active != null) {
        await FirestoreMatchService.instance.sendChatMessage(
          matchId: active.id,
          message: msg,
        );
      }

      scrollToBottom();
    }

    Future<void> handleCreateChallenge() async {
      final config = await MatchSetupDialog.show(
        context,
        initialConfig: MatchConfig(
          opponentFriend: friend,
          player2Name: friend.displayName,
          player2Avatar: friend.avatarEmoji,
          player2Uid: friend.uid,
        ),
      );
      if (config == null || !context.mounted) return;

      final profile =
          currentUser ??
          UserProfile(
            uid: myUid,
            displayName: 'Player',
            avatarEmoji: PlayerDescriptor.defaultAvatar,
          );

      final newMatch = config.precreatedMatch ??
          await FirestoreMatchService.instance.createMatch(
            config: config,
            player1Profile: profile,
          );

      await FriendsService.instance.updateFriendMatch(
        myUid: myUid,
        friendUid: friend.uid,
        matchId: newMatch.id,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        MatchLobbyDialog.show(
          context: context,
          match: newMatch,
          challengedFriend: friend,
          onPlaySoloWhileWaiting: () {
            onPlayTurn(newMatch);
          },
          onEnterArena: (confirmedMatch) {
            onPlayTurn(confirmedMatch);
          },
        );
      }
    }

    final matchId = currentMatch.value?.id ?? friend.activeMatchId;
    final streamedMatch = (matchId != null && matchId.isNotEmpty)
        ? ref.watch(singleMatchProvider(matchId)).value
        : null;
    final effectiveMatch = streamedMatch ?? currentMatch.value;

    final directChat = ref.watch(directChatProvider((
      myUid: myUid,
      friendUid: friend.uid,
    ))).value ?? const <CloudChatMessage>[];

    // Stream match chat from lightweight subcollection (decoupled from telemetry)
    final matchChat = (effectiveMatch != null && effectiveMatch.id.isNotEmpty)
        ? ref.watch(matchChatProvider(effectiveMatch.id)).value ?? effectiveMatch.chat
        : const <CloudChatMessage>[];

    final allChat = <String, CloudChatMessage>{};
    for (final m in matchChat) {
      allChat[m.id] = m;
    }
    for (final m in directChat) {
      allChat[m.id] = m;
    }
    final sortedChat = allChat.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // When chat messages update or exist in the sheet, ensure read receipts mark through the highest message timestamp
    useEffect(() {
      if (sortedChat.isNotEmpty) {
        final latestMs = sortedChat.last.timestamp;
        ChatReadReceiptService.instance.markFriendChatRead(
          friend.uid,
          atTimestamp: latestMs + 100,
        );
        if (effectiveMatch != null) {
          ChatReadReceiptService.instance.markMatchRead(
            effectiveMatch.id,
            atTimestamp: latestMs + 100,
          );
        }
      }
      return null;
    }, [sortedChat.length, sortedChat.isNotEmpty ? sortedChat.last.id : '']);

    return AppModalSheet(
      heightFactor: 0.88,
      header: _buildHeader(context),
      child: Column(
        children: [
          _buildStickyGameBanner(
            context,
            effectiveMatch,
            handleCreateChallenge,
          ),
          const Divider(color: Color(0xFF1E2638), height: 1),

          // Chat banter message list
          Expanded(
            child: ChatBubbleList(
              messages: sortedChat,
              myUid: myUid,
              controller: scrollController,
            ),
          ),

          // Banter Chips & Input Bar
          ChatInputBar(
            controller: msgController,
            quickBanter: _quickBanter,
            onSend: sendText,
            accentColor: const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppAvatar(
            avatar: friend.avatarEmoji,
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
                  friend.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  'H2H: ${friend.h2hWins}W - ${friend.h2hLosses}L',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyGameBanner(
    BuildContext context,
    CloudMatch? match,
    VoidCallback onCreateChallenge,
  ) {
    if (match == null ||
        match.status == MatchStatus.completed ||
        match.status == MatchStatus.abandoned ||
        match.status == MatchStatus.declined) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2638),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sports_basketball_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NO ACTIVE 1V1 MATCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Challenge your friend to a shootout',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onCreateChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '🏀 CHALLENGE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
    }

    final isMyTurn = match.isMyTurn(myUid);
    final isCompleted = match.status == MatchStatus.completed;
    final myPlayer = match.myPlayer(myUid);
    final opponent = match.opponentPlayer(myUid);
    final myScore = myPlayer?.totalScore ?? 0;
    final oppScore = opponent?.totalScore ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMyTurn ? const Color(0xFF1A263E) : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyTurn ? const Color(0xFF38BDF8) : const Color(0xFF2E3954),
          width: isMyTurn ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUND ${match.currentRound} OF ${match.totalRounds}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Room: ${match.joinCode}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'You: $myScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      '  vs  ',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    Text(
                      '${friend.displayName}: $oppScore',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onViewPodium?.call(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'PODIUM 🏆',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                )
              else if (isMyTurn)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onPlayTurn(match);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '⚡ SHOOT TURN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Text(
                    '⏳ Their Turn',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
