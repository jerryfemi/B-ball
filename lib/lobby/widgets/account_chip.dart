import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/common/edit_profile_dialog.dart';
import '../../providers/app_providers.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// Lobby account chip: avatar and name (avatar only when [compact]). Tapping
/// it opens the profile editor. Watches only the profile.
class AccountChip extends ConsumerWidget {
  final bool compact;
  const AccountChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final String name = profile?.displayName ?? 'Player';

    return Tooltip(
      message: 'Edit profile',
      child: Pressable(
        semanticLabel: 'Edit profile, $name',
        onTap: () => EditProfileDialog.show(context, profile: profile),
        child: Container(
          padding: EdgeInsets.fromLTRB(4, 4, compact ? 4 : 16, 4),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                avatar: profile?.avatarEmoji ?? AppAvatar.defaultAvatar,
                size: 32,
                borderWidth: 0,
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: LobbyStyle.text(size: 14, weight: 600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
