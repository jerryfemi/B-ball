import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/friends_service.dart';

/// Modal dialog to search and add friends by display name or player tag,
/// and share one's own tag with others.
class AddFriendDialog extends StatefulWidget {
  final Set<String> existingFriendUids;
  final ValueChanged<FriendProfile>? onFriendAdded;

  const AddFriendDialog({
    super.key,
    required this.existingFriendUids,
    this.onFriendAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required Set<String> existingFriendUids,
    ValueChanged<FriendProfile>? onFriendAdded,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => AddFriendDialog(
        existingFriendUids: existingFriendUids,
        onFriendAdded: onFriendAdded,
      ),
    );
  }

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<FriendProfile> _results = [];
  bool _isSearching = false;
  late final Set<String> _friendUids;

  @override
  void initState() {
    super.initState();
    _friendUids = Set.from(widget.existingFriendUids);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final query = val.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final myUid = AuthService.instance.currentUser?.uid ?? '';
      final results = await FriendsService.instance.searchUsers(query, myUid);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _handleAddFriend(FriendProfile friend) async {
    HapticFeedback.mediumImpact();
    final myUid = AuthService.instance.currentUser?.uid ?? '';
    await FriendsService.instance.addFriend(myUid, friend);
    setState(() => _friendUids.add(friend.uid));
    widget.onFriendAdded?.call(friend);
  }

  void _copyMyTag() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    Clipboard.setData(ClipboardData(text: user.displayName));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${user.displayName}" to clipboard!'),
        backgroundColor: const Color(0xFF1E2638),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUser = AuthService.instance.currentUser;
    final myName = myUser?.displayName ?? 'Player';
    final myAvatar = myUser?.avatarEmoji ?? '🏀';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131826),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2E3954), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ADD FRIEND',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Player tag card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Text(myAvatar, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PLAYER TAG',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            myName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _copyMyTag,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3954),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'COPY',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search field
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Enter friend's name or tag...",
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E2638),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Search results list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'Search by username above to add friends'
                                : _isSearching
                                    ? 'Searching players...'
                                    : 'No players found matching "$_searchController.text"',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final friend = _results[index];
                          final isAlreadyFriend = _friendUids.contains(friend.uid);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2234),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2E3954)),
                            ),
                            child: Row(
                              children: [
                                Text(friend.avatarEmoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    friend.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                if (isAlreadyFriend)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ADDED ✓',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _handleAddFriend(friend),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '+ ADD',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
