import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/inbox/match_inbox_sheet.dart';
import '../../game/ui/match/incoming_challenge_dialog.dart';
import '../../models/cloud_match.dart';
import '../../providers/app_providers.dart';
import '../../notifications/app_notices.dart';

/// Round icon button for the archery screen's corners (icon only, so it never
/// collides with the scoreboard on narrow phones). Optional count badge.
class ArcheryRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;
  final Color? badgeColor;

  const ArcheryRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
    this.badgeColor,
  });

  static const double size = 38.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: const Color(0xCC0A0E1A),
              shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, size: 18, color: const Color(0xFFE2E8F0)),
                ),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -3,
                right: -3,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF0A0E1A), width: 1.5),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the shared match inbox (all games) from archery.
abstract final class ArcheryInbox {
  static void open(
    BuildContext context, {
    required VoidCallback onCreateMatch,
  }) {
    MatchInboxSheet.show(
      context,
      // /match/:id opens whichever game the match belongs to.
      onPlayMatch: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
      onViewPodium: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
      onCreateMatch: onCreateMatch,
    );
  }
}

/// MATCHES button with a badge for matches where it's your turn.
class ArcheryMatchesButton extends ConsumerWidget {
  final VoidCallback onTap;
  const ArcheryMatchesButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProfileProvider.select((p) => p.value?.uid ?? ''));
    final matches = ref.watch(userMatchesProvider).value ?? const <CloudMatch>[];
    final int yourTurn = myUid.isEmpty ? 0 : matches.where((m) => m.isMyTurn(myUid)).length;
    // Opens your profile drawer, so the badge counts everything in it:
    // matches waiting on you plus invites and friend requests.
    final int waiting = ref.watch(appNoticesProvider).length;
    return ArcheryRoundButton(
      icon: Icons.person_rounded,
      tooltip: 'You: invites, friends, matches',
      onTap: onTap,
      badge: yourTurn + waiting,
    );
  }
}

/// "🎯 NAME challenged you · ACCEPT" pill for incoming challenges (any game).
/// Accepting opens the match in its own game.
class ArcheryChallengePill extends ConsumerWidget {
  /// Called before the dialog opens (e.g. to pause solo play).
  final VoidCallback? onOpen;
  const ArcheryChallengePill({super.key, this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(incomingMatchChallengesProvider).value ?? const [];
    if (challenges.isEmpty) return const SizedBox.shrink();
    final invite = challenges.first;
    final String what =
        invite.isArchery ? 'Archery' : (invite.isDarts ? 'Darts' : 'Basketball');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onOpen?.call();
          IncomingChallengeDialog.show(
            context: context,
            invite: invite,
            onAccepted: (m) => GoRouter.maybeOf(context)?.go('/match/${m.id}'),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FFCC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(avatar: invite.hostAvatar, size: 24, borderColor: const Color(0xFF00FFCC), borderWidth: 1),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '${invite.isArchery ? '🏹' : (invite.isDarts ? '🎯' : '🏀')} ${invite.hostName} challenged you to $what',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFCC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ACCEPT',
                  style: TextStyle(
                    color: Color(0xFF0A0E1A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
