import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../game/ui/common/app_avatar.dart';
import '../game/ui/common/edit_profile_dialog.dart';
import '../game/ui/common/ui_font.dart';
import '../game/ui/social/add_friend_dialog.dart';
import '../game/ui/social/friends_hub_sheet.dart';
import '../models/cloud_match.dart';
import '../models/friend_profile.dart';
import '../providers/app_providers.dart';
import 'app_notices.dart';
import 'notice_stack.dart';

/// Everything social in one place: who you are, what's waiting for you,
/// friends and matches. Opens from your avatar (lobby and games) as a panel
/// sliding in from the right, the side the avatar sits on, and leaves the
/// same way: tap outside, or drag/flick it back to the right.
class ProfileDrawer extends ConsumerWidget {
  final ValueChanged<CloudMatch> onOpenMatch;
  final VoidCallback onOpenMatches;
  final VoidCallback? onPlayFriend;
  final VoidCallback? onHowToPlay;

  /// The screen that opened the drawer; sheets opened after the drawer
  /// closes use it (the drawer's own context is gone by then).
  final BuildContext hostContext;

  const ProfileDrawer({
    super.key,
    required this.hostContext,
    required this.onOpenMatch,
    required this.onOpenMatches,
    this.onPlayFriend,
    this.onHowToPlay,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CloudMatch> onOpenMatch,
    required VoidCallback onOpenMatches,
    VoidCallback? onPlayFriend,
    VoidCallback? onHowToPlay,
  }) {
    HapticFeedback.selectionClick();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x8C000000),
      transitionDuration: Duration(milliseconds: reduceMotion ? 150 : 340),
      pageBuilder: (_, _, _) => ProfileDrawer(
        hostContext: context,
        onOpenMatch: onOpenMatch,
        onOpenMatches: onOpenMatches,
        onPlayFriend: onPlayFriend,
        onHowToPlay: onHowToPlay,
      ),
      transitionBuilder: (context, a, _, child) {
        if (reduceMotion) return FadeTransition(opacity: a, child: child);
        final curved = CurvedAnimation(
          parent: a,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final notices = ref.watch(appNoticesProvider);
    final hidden = ref.watch(dismissedNoticesProvider);
    final friends =
        ref.watch(friendsListProvider).value ?? const <FriendProfile>[];
    final matches =
        ref.watch(userMatchesProvider).value ?? const <CloudMatch>[];
    final int live = matches
        .where(
          (m) =>
              m.status == MatchStatus.active ||
              m.status == MatchStatus.waitingForOpponent,
        )
        .length;
    final double width = (MediaQuery.sizeOf(context).width * 0.88).clamp(
      0.0,
      360.0,
    );

    // Close first, then act, so the next sheet or screen isn't under the drawer.
    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    void addFriend() {
      HapticFeedback.selectionClick();
      AddFriendDialog.show(
        context,
        existingFriendUids: {for (final f in friends) f.uid},
      );
    }

    final panel = Material(
      color: const Color(0xFF0A0E1A),
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF1E2638))),
        ),
        child: SafeArea(
          left: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // Who you are. Tap to edit.
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => EditProfileDialog.show(context, profile: profile),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      AppAvatar(
                        avatar: profile?.avatarEmoji ?? AppAvatar.defaultAvatar,
                        size: 56,
                        borderColor: const Color(0xFF38BDF8),
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Player',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UiFont.style(
                                size: 22,
                                weight: 800,
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Edit name and avatar',
                              style: UiFont.style(
                                size: 13,
                                weight: 500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (notices.isNotEmpty) ...[
                _Section('Needs you'),
                for (final n in notices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NoticeCard(
                      key: ValueKey('drawer-${n.id}'),
                      notice: n,
                      countLabel: hidden.contains(n.id)
                          ? 'saved for later'
                          : null,
                      onOpenMatch: (m) => closeThen(() => onOpenMatch(m)),
                    ),
                  ),
              ],

              _Section('You'),
              _Tile(
                icon: Icons.people_alt_rounded,
                tint: const Color(0xFF38BDF8),
                title: 'Friends',
                subtitle: friends.isEmpty
                    ? 'Add someone to play with'
                    : '${friends.length} friend${friends.length == 1 ? '' : 's'}',
                trailing: _AddPill(onTap: addFriend),
                onTap: () => closeThen(
                  () => FriendsHubSheet.show(
                    hostContext,
                    onPlayMatch: onOpenMatch,
                    onCreateMatch: onPlayFriend ?? () {},
                  ),
                ),
              ),
              _Tile(
                icon: Icons.emoji_events_rounded,
                tint: const Color(0xFF00FFCC),
                title: 'Matches',
                subtitle: live == 0
                    ? 'Live games and finished results'
                    : '$live live',
                onTap: () => closeThen(onOpenMatches),
              ),
              if (onPlayFriend != null)
                _Tile(
                  icon: Icons.sports_esports_rounded,
                  tint: const Color(0xFFF59E0B),
                  title: 'Play a friend',
                  subtitle: 'Share a code, challenge a friend, or join',
                  onTap: () => closeThen(onPlayFriend!),
                ),
              if (onHowToPlay != null)
                _Tile(
                  icon: Icons.help_outline_rounded,
                  tint: const Color(0xFF94A3B8),
                  title: 'How to play',
                  subtitle: 'See the steps again',
                  onTap: () => closeThen(onHowToPlay!),
                ),
            ],
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      // Drag it back to the right (1:1 with the finger) or flick to close.
      child: Dismissible(
        key: const ValueKey('profile-drawer'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.3},
        onDismissed: (_) => Navigator.of(context).pop(),
        child: SizedBox(height: double.infinity, child: panel),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(
        label,
        style: UiFont.style(
          size: 13,
          weight: 600,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E2638)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: UiFont.style(
                          size: 16,
                          weight: 700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: UiFont.style(
                          size: 13,
                          weight: 500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF475569),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF38BDF8),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            '+ Add',
            style: UiFont.style(
              size: 13,
              weight: 800,
              color: const Color(0xFF0A0E1A),
            ),
          ),
        ),
      ),
    );
  }
}
