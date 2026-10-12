import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/friend_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/friends_service.dart';
import '../common/app_avatar.dart';
import '../common/app_modal_dialog.dart';
import '../common/app_text_field.dart';

/// Modal dialog to search and add friends by display name or player tag,
/// and share one's own tag with others.
class AddFriendDialog extends HookWidget {
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
    return AppModalDialog.show<void>(
      context: context,
      builder: (ctx) => AddFriendDialog(
        existingFriendUids: existingFriendUids,
        onFriendAdded: onFriendAdded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);
    final results = useState<List<FriendProfile>>([]);
    final isSearching = useState<bool>(false);
    final invitedUids = useState<Set<String>>({});
    final friendUids = useMemoized(
      () => Set<String>.from(existingFriendUids),
      [existingFriendUids],
    );

    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, const []);

    void onSearchChanged(String val) {
      debounceTimer.value?.cancel();
      final query = val.trim();
      if (query.length < 2) {
        results.value = [];
        isSearching.value = false;
        return;
      }

      isSearching.value = true;
      debounceTimer.value = Timer(const Duration(milliseconds: 350), () async {
        final myUid = AuthService.instance.currentUser?.uid ?? '';
        final res = await FriendsService.instance.searchUsers(query, myUid);
        if (context.mounted) {
          results.value = res;
          isSearching.value = false;
        }
      });
    }

    Future<void> handleSendInvite(FriendProfile friend) async {
      HapticFeedback.mediumImpact();
      final myProfile = AuthService.instance.currentUser;
      if (myProfile != null) {
        await FriendsService.instance.sendFriendInvite(
          targetUid: friend.uid,
          myProfile: myProfile,
        );
        if (context.mounted) {
          invitedUids.value = {...invitedUids.value, friend.uid};
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend invite sent to ${friend.displayName}! 📨'),
              backgroundColor: const Color(0xFF1E2638),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    void copyMyTag() {
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
    final myUser = AuthService.instance.currentUser;
    final myName = myUser?.displayName ?? 'Player';
    final myAvatar =
        myUser?.avatarEmoji ?? AppAvatar.defaultAvatar;

    return AppModalDialog(
      maxWidth: 380,
      iconWidget: const Icon(
        Icons.person_add_rounded,
        color: Color(0xFF38BDF8),
        size: 20,
      ),
      title: 'ADD FRIEND',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

              // Player tag card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    AppAvatar(avatar: myAvatar, size: 24),
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
                      onTap: copyMyTag,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3954),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF38BDF8),
                              size: 14,
                            ),
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
              AppTextField(
                controller: searchController,
                onChanged: onSearchChanged,
                hintText: "Enter friend's name or tag...",
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: isSearching.value
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),

              // Search results list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: results.value.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            searchController.text.trim().isEmpty
                                ? 'Search by username above to add friends'
                                : isSearching.value
                                ? 'Searching players...'
                                : 'No players found matching "${searchController.text}"',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.value.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final friend = results.value[index];
                          final isAlreadyFriend = friendUids.contains(
                            friend.uid,
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2234),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2E3954),
                              ),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(avatar: friend.avatarEmoji, size: 22),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'FRIENDS ✓',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                else if (invitedUids.value.contains(friend.uid))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'INVITED ⏳',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => handleSendInvite(friend),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'INVITE +',
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
        );
  }
}
