import 'package:flutter/material.dart';
import '../../../models/cloud_match.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_match_service.dart';
import 'join_match_dialog.dart';
import 'match_inbox_card.dart';
import 'match_thread_dialog.dart';

/// The central Game Conversation Inbox bottom sheet modal.
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
  int _selectedTab = 0; // 0: Active, 1: Completed

  @override
  Widget build(BuildContext context) {
    final myProfile = AuthService.instance.currentUser;
    final myUid = myProfile?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF111624),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF26324A), width: 1.5)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row: Avatar, Title, Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(myProfile?.avatarEmoji ?? '🏀', style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MATCH INBOX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          myProfile?.displayName ?? 'Guest Player',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action row: "NEW MATCH" + "JOIN WITH CODE"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCreateMatch();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('NEW MATCH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final match = await JoinMatchDialog.show(context);
                        if (match != null && context.mounted) {
                          Navigator.of(context).pop();
                          widget.onPlayMatch(match);
                        }
                      },
                      icon: const Icon(Icons.dialpad, size: 16),
                      label: const Text('JOIN CODE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00FFCC),
                        side: const BorderSide(color: Color(0xFF00FFCC)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Selector: Active vs Completed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabPill(0, 'ACTIVE GAMES'),
                  const SizedBox(width: 10),
                  _buildTabPill(1, 'COMPLETED'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Stream List of Matches
            Expanded(
              child: StreamBuilder<List<CloudMatch>>(
                stream: FirestoreMatchService.instance.streamUserMatches(myUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC)),
                    );
                  }

                  final allMatches = snapshot.data ?? [];
                  final activeMatches = allMatches.where((m) => m.status != MatchStatus.completed).toList();
                  final completedMatches = allMatches.where((m) => m.status == MatchStatus.completed).toList();

                  final displayList = _selectedTab == 0 ? activeMatches : completedMatches;

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
                        },
                        onPlayTurn: () {
                          Navigator.of(context).pop();
                          widget.onPlayMatch(match);
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
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2638) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF2E3954),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isActiveTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isActiveTab ? '🏀' : '🏆', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            isActiveTab ? 'No active games right now' : 'No completed games yet',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            isActiveTab
                ? 'Create a new match or join a friend with code!'
                : 'Played matches will appear here with final scores.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
