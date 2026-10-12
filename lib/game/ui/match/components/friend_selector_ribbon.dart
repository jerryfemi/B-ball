import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../models/friend_profile.dart';
import '../../../../providers/app_providers.dart';
import '../../../../services/auth_service.dart';
import '../../common/app_avatar.dart';

/// Horizontal scrollable ribbon displaying friends for 1v1 match challenges.
class FriendSelectorRibbon extends ConsumerWidget {
  final UserProfile? profile;
  final FriendProfile? selectedFriend;
  final ValueChanged<FriendProfile?> onFriendSelected;
  final VoidCallback onUseOpenCode;

  const FriendSelectorRibbon({
    super.key,
    required this.profile,
    required this.selectedFriend,
    required this.onFriendSelected,
    required this.onUseOpenCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider).value ?? const <FriendProfile>[];
        if (friends.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                const Text(
                  'No friends added yet. Add friends via the Friends Hub, or generate an open code!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.0,
                  ),
                ),
                const SizedBox(height: 6.0),
                TextButton(
                  onPressed: onUseOpenCode,
                  child: const Text(
                    'USE OPEN MATCH CODE',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 84.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8.0),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final isSelected = selectedFriend?.uid == friend.uid;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFriendSelected(isSelected ? null : friend);
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  width: 72.0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E3A5F)
                        : const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF334155),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AppAvatar(
                            avatar: friend.avatarEmoji,
                            size: 32.0,
                            borderColor: isSelected
                                ? const Color(0xFF38BDF8)
                                : Colors.transparent,
                          ),
                          if (isSelected)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2.0),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          fontSize: 10.0,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
  }
}
