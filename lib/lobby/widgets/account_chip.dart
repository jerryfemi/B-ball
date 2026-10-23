import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../archery/archery_game_screen.dart' show ArcheryChallenge;
import '../../archery/ui/archery_match_bar.dart' show ArcheryInbox;
import '../../notifications/profile_drawer.dart';

import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/common/edit_profile_dialog.dart';
import '../../notifications/app_notices.dart';
import '../../providers/app_providers.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// Lobby account chip: avatar and name (avatar only when [compact]). Tapping
/// it opens the profile editor.
///
/// When invites or friend requests are waiting it shows how many, and when a
/// new one arrives that hasn't been swiped away, a ring pulses out of the
/// avatar a few times (then rests, so it never nags).
class AccountChip extends HookConsumerWidget {
  final bool compact;
  const AccountChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final String name = profile?.displayName ?? 'Player';
    final int waiting = ref.watch(appNoticesProvider).length;
    final int fresh = ref.watch(visibleNoticesProvider).length;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final pulse = useAnimationController(duration: const Duration(milliseconds: 1400));
    final pulses = useRef(0);
    useEffect(() {
      void onStatus(AnimationStatus s) {
        if (s == AnimationStatus.completed && ++pulses.value < 3) pulse.forward(from: 0);
      }

      pulse.addStatusListener(onStatus);
      return () => pulse.removeStatusListener(onStatus);
    }, [pulse]);
    // Pulse again whenever the number of new notices goes up.
    useEffect(() {
      if (fresh > 0 && !reduceMotion) {
        pulses.value = 0;
        pulse.forward(from: 0);
      } else {
        pulse.stop();
        pulse.value = 0;
      }
      return null;
    }, [fresh, reduceMotion]);

    final avatar = SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (fresh > 0)
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(pulse.value);
                return IgnorePointer(
                  child: Container(
                    width: 32 + 22 * t,
                    height: 32 + 22 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.6 * (1 - t)),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          AppAvatar(
            avatar: profile?.avatarEmoji ?? AppAvatar.defaultAvatar,
            size: 32,
            borderWidth: 0,
          ),
          if (waiting > 0)
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: LobbyStyle.ink, width: 2),
                ),
                child: Text(
                  waiting > 9 ? '9+' : '$waiting',
                  style: LobbyStyle.text(size: 10.5, weight: 800, height: 1),
                ),
              ),
            ),
        ],
      ),
    );

    return Tooltip(
      message: waiting > 0 ? '$waiting waiting' : 'You',
      child: Pressable(
        semanticLabel: waiting > 0
            ? '$name, $waiting invites or requests waiting'
            : 'Edit profile, $name',
        // Online: the profile drawer (what's waiting, friends, matches).
        onTap: Firebase.apps.isEmpty
            ? () => EditProfileDialog.show(context, profile: profile)
            : () => ProfileDrawer.show(
                  context,
                  onOpenMatch: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
                  onOpenMatches: () => ArcheryInbox.open(
                    context,
                    onCreateMatch: () => ArcheryChallenge.start(context, showGamePicker: true),
                  ),
                  onPlayFriend: () => ArcheryChallenge.start(context, showGamePicker: true),
                ),
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
              avatar,
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
