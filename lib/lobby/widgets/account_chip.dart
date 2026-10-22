import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/common/edit_profile_dialog.dart';
import '../../providers/app_providers.dart';

/// Lobby account chip: the signed-in player's avatar and name. Tapping it
/// opens the profile editor. Watches only the profile, so match updates
/// never rebuild it.
class AccountChip extends ConsumerWidget {
  const AccountChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        EditProfileDialog.show(context, profile: profile);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF131826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E3954), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              avatar: profile?.avatarEmoji ?? AppAvatar.defaultAvatar,
              size: 28,
              borderColor: const Color(0xFF00FFCC),
              borderWidth: 1.5,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                profile?.displayName ?? 'Player',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF00FFCC)),
          ],
        ),
      ),
    );
  }
}
