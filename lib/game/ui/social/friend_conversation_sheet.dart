import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cloud_match.dart';
import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import '../../../services/friends_service.dart';
import '../common/app_avatar.dart';
import '../match/match_setup_dialog.dart';

/// GamePigeon-style conversation screen featuring a sticky top 1v1 match banner,
/// persistent chat banter feed, and keyboard-safe layout.
class FriendConversationSheet extends StatefulWidget {
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

  static Future<void> show(
    BuildContext context, {
    required FriendProfile friend,
    required String myUid,
    CloudMatch? activeMatch,
    required ValueChanged<CloudMatch> onPlayTurn,
    ValueChanged<CloudMatch>? onViewPodium,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  State<FriendConversationSheet> createState() =>
      _FriendConversationSheetState();
}

class _FriendConversationSheetState extends State<FriendConversationSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  CloudMatch? _currentMatch;

  static const List<String> _quickBanter = [
    '🎯 Swish!',
    '🧱 Brick!',
    '🔥 On fire!',
    '🥶 Ice cold!',
    '👑 Rematch?',
    '🏀 Your turn!',
  ];

  @override
  void initState() {
    super.initState();
    _currentMatch = widget.activeMatch;
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final user = AuthService.instance.currentUser;
    final myName = user?.displayName ?? 'You';
    final myAvatar = user?.avatarEmoji ?? 'assets/avatars/dunk_heads (1).webp';
    final now = DateTime.now().millisecondsSinceEpoch;

    final msg = CloudChatMessage(
      id: '${now}_${widget.myUid}',
      senderUid: widget.myUid,
      senderName: myName,
      senderAvatar: myAvatar,
      text: clean,
      timestamp: now,
    );

    _msgController.clear();
    HapticFeedback.lightImpact();

    await FriendsService.instance.sendDirectMessage(
      fromUid: widget.myUid,
      toUid: widget.friend.uid,
      message: msg,
    );

    if (_currentMatch != null) {
      await FirestoreMatchService.instance.sendChatMessage(
        matchId: _currentMatch!.id,
        message: msg,
      );
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  Future<void> _handleCreateChallenge() async {
    final config = await MatchSetupDialog.show(context);
    if (config == null || !mounted) return;

    final profile =
        AuthService.instance.currentUser ??
        UserProfile(
          uid: widget.myUid,
          displayName: 'Player',
          avatarEmoji: 'assets/avatars/dunk_heads (1).webp',
        );

    final newMatch = await FirestoreMatchService.instance.createMatch(
      config: config,
      player1Profile: profile,
    );

    await FriendsService.instance.updateFriendMatch(
      myUid: widget.myUid,
      friendUid: widget.friend.uid,
      matchId: newMatch.id,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onPlayTurn(newMatch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final matchId = _currentMatch?.id ?? widget.friend.activeMatchId;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF2E3954), width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Pull indicator handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top Conversation Header
              _buildHeader(),

              // Stream active match state if present
              if (matchId != null)
                StreamBuilder<CloudMatch?>(
                  stream: FirestoreMatchService.instance.streamMatch(matchId),
                  initialData: _currentMatch,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      _currentMatch = snapshot.data;
                    }
                    return _buildStickyGameBanner(_currentMatch);
                  },
                )
              else
                _buildStickyGameBanner(null),

              const Divider(color: Color(0xFF1E2638), height: 1),

              // Chat banter message stream
              Expanded(
                child: StreamBuilder<List<CloudChatMessage>>(
                  stream: FriendsService.instance.streamDirectChat(
                    myUid: widget.myUid,
                    friendUid: widget.friend.uid,
                  ),
                  builder: (context, snapshot) {
                    final directChat = snapshot.data ?? const [];
                    final matchChat = _currentMatch?.chat ?? const [];
                    final allChat = <String, CloudChatMessage>{};
                    for (final m in matchChat) {
                      allChat[m.id] = m;
                    }
                    for (final m in directChat) {
                      allChat[m.id] = m;
                    }
                    final sortedChat = allChat.values.toList()
                      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                    return _buildChatList(sortedChat);
                  },
                ),
              ),

              // Banter Chips
              _buildBanterChips(),

              // Bottom Input Bar
              _buildInputField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppAvatar(
            avatar: widget.friend.avatarEmoji,
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
                  widget.friend.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  'H2H: ${widget.friend.h2hWins}W - ${widget.friend.h2hLosses}L',
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

  Widget _buildStickyGameBanner(CloudMatch? match) {
    if (match == null) {
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
              onPressed: _handleCreateChallenge,
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

    final isMyTurn = match.isMyTurn(widget.myUid);
    final isCompleted = match.status == MatchStatus.completed;
    final myPlayer = match.myPlayer(widget.myUid);
    final opponent = match.opponentPlayer(widget.myUid);
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
                      '${widget.friend.displayName}: $oppScore',
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
                    widget.onViewPodium?.call(match);
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
                    widget.onPlayTurn(match);
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

  Widget _buildChatList(List<CloudChatMessage> chat) {
    if (chat.isEmpty) {
      return const Center(
        child: Text(
          'No banter yet. Send a quick reaction below! 🎯',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: chat.length,
      itemBuilder: (ctx, i) {
        final msg = chat[i];
        final isMe = msg.senderUid == widget.myUid;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF2563EB) : const Color(0xFF1E2638),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 14),
              ),
              border: Border.all(
                color: isMe ? const Color(0xFF3B82F6) : const Color(0xFF334155),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBanterChips() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickBanter.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final text = _quickBanter[i];
          return ActionChip(
            label: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1E2638),
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onPressed: () => _sendText(text),
          );
        },
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type message...',
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
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF38BDF8),
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: _sendText,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.send_rounded,
              color: Color(0xFF38BDF8),
              size: 20,
            ),
            onPressed: () => _sendText(_msgController.text),
          ),
        ],
      ),
    );
  }
}
