import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import 'join_match_dialog.dart';
import 'match_inbox_card.dart';
import 'match_thread_dialog.dart';
import '../social/friends_hub_sheet.dart';

/// The central 1v1 Match Hub bottom sheet modal.
class MatchInboxSheet extends StatefulWidget {
  final ValueChanged<CloudMatch> onPlayMatch;
  final VoidCallback onCreateMatch;
  final ValueChanged<CloudMatch>? onViewPodium;

  const MatchInboxSheet({
    super.key,
    required this.onPlayMatch,
    required this.onCreateMatch,
    this.onViewPodium,
  });

  /// Summon the Match Inbox sheet.
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CloudMatch> onPlayMatch,
    required VoidCallback onCreateMatch,
    ValueChanged<CloudMatch>? onViewPodium,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MatchInboxSheet(
        onPlayMatch: onPlayMatch,
        onCreateMatch: onCreateMatch,
        onViewPodium: onViewPodium,
      ),
    );
  }

  @override
  State<MatchInboxSheet> createState() => _MatchInboxSheetState();
}

class _MatchInboxSheetState extends State<MatchInboxSheet> {
  int _selectedTab = 0; // 0: Live Matches, 1: Trophy History

  void _showEditProfileDialog(BuildContext context, UserProfile current) {
    final nameCtrl = TextEditingController(text: current.displayName);
    String selectedEmoji = current.avatarEmoji;
    final emojiOptions = ['🏀', '🔥', '⚡', '👑', '🐺', '🎯', '🚀', '💎', '🦁'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF131826),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2E3954)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'EDIT YOUR PROFILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  maxLength: 16,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF1E2638),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'CHOOSE AVATAR',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emojiOptions.map((e) {
                    final isSel = selectedEmoji == e;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedEmoji = e),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF00FFCC).withValues(alpha: 0.2) : const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFF00FFCC) : const Color(0xFF334155),
                            width: isSel ? 1.6 : 1.0,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    final cleanName = nameCtrl.text.trim();
                    if (cleanName.isNotEmpty) {
                      await AuthService.instance.updateProfile(
                        displayName: cleanName,
                        avatarEmoji: selectedEmoji,
                      );
                      setState(() {});
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = AuthService.instance.currentUser;
    final myUid = myProfile?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF26324A), width: 1.5)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Top Header: Profile Pill + Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  InkWell(
                    onTap: myProfile != null ? () => _showEditProfileDialog(context, myProfile) : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2638),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(myProfile?.avatarEmoji ?? '🏀', style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MATCH INBOX',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  myProfile?.displayName ?? 'Baller',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined, size: 11, color: Color(0xFF64748B)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Actions: "+ CREATE MATCH", "JOIN MATCH", and "FRIENDS"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCreateMatch();
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'CREATE MATCH',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final match = await JoinMatchDialog.show(context);
                        if (match != null && context.mounted) {
                          Navigator.of(context).pop();
                          widget.onPlayMatch(match);
                        }
                      },
                      icon: const Icon(Icons.dialpad_rounded, size: 14),
                      label: const Text(
                        'JOIN MATCH',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00FFCC),
                        side: const BorderSide(color: Color(0xFF00FFCC), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 8,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        FriendsHubSheet.show(
                          context,
                          onPlayMatch: widget.onPlayMatch,
                          onCreateMatch: widget.onCreateMatch,
                          onViewPodium: widget.onViewPodium,
                        );
                      },
                      icon: const Icon(Icons.people_alt_rounded, size: 14),
                      label: const Text(
                        'FRIENDS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF818CF8),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabPill(0, 'ACTIVE MATCHES'),
                  const SizedBox(width: 8),
                  _buildTabPill(1, 'COMPLETED'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Matches Stream Feed
            Expanded(
              child: StreamBuilder<List<CloudMatch>>(
                stream: FirestoreMatchService.instance.streamUserMatches(myUid),
                initialData: FirestoreMatchService.instance.getCachedUserMatches(myUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC)),
                    );
                  }

                  final allMatches = snapshot.data ?? [];
                  final liveMatches = allMatches.where((m) => m.status != MatchStatus.completed).toList();
                  final completedMatches = allMatches.where((m) => m.status == MatchStatus.completed).toList();

                  // Sort live matches so your turns appear at the top
                  liveMatches.sort((a, b) {
                    final aTurn = a.isMyTurn(myUid) ? 0 : 1;
                    final bTurn = b.isMyTurn(myUid) ? 0 : 1;
                    return aTurn.compareTo(bTurn);
                  });

                  final displayList = _selectedTab == 0 ? liveMatches : completedMatches;

                  if (displayList.isEmpty) {
                    return _buildEmptyState(_selectedTab == 0);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, i) {
                      final match = displayList[i];
                      return MatchInboxCard(
                        match: match,
                        myUid: myUid,
                        onTap: () {
                          if (match.status == MatchStatus.completed) {
                            Navigator.of(context).pop();
                            widget.onViewPodium?.call(match);
                          } else {
                            MatchThreadDialog.show(
                              context,
                              match: match,
                              myUid: myUid,
                              onPlayTurn: () {
                                Navigator.of(context).pop();
                                widget.onPlayMatch(match);
                              },
                              onViewPodium: () {
                                Navigator.of(context).pop();
                                widget.onViewPodium?.call(match);
                              },
                            );
                          }
                        },
                        onPlayTurn: () {
                          Navigator.of(context).pop();
                          widget.onPlayMatch(match);
                        },
                        onViewPodium: () {
                          Navigator.of(context).pop();
                          widget.onViewPodium?.call(match);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(int index, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2638) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF26324A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLiveTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiveTab ? Icons.sports_basketball_outlined : Icons.emoji_events_outlined,
              size: 40,
              color: const Color(0xFF475569),
            ),
            const SizedBox(height: 10),
            Text(
              isLiveTab ? 'No live challenges right now' : 'No completed matches yet',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              isLiveTab
                  ? 'Tap "+ NEW MATCH" or join a friend\'s code to play!'
                  : 'Finished games and winner podiums will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
