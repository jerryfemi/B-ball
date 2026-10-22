import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../archery/state/archery_rules.dart';
import '../../game/ui/common/app_avatar.dart';
import '../../game/ui/inbox/match_inbox_sheet.dart';
import '../../models/cloud_match.dart';
import '../../providers/app_providers.dart';
import '../game_catalog.dart';
import '../lobby_style.dart';
import 'pressable.dart';

/// "Your matches": the running matches (your turn first), each one tap away
/// from its game, plus a link to the full inbox (history included).
///
/// Watches the match list itself, so match updates rebuild only this part
/// of the lobby.
class ActiveMatchesSection extends ConsumerWidget {
  /// Opens the "new match" flow (shown when nothing is running).
  final VoidCallback onChallenge;

  const ActiveMatchesSection({super.key, required this.onChallenge});

  /// How many rows the lobby shows; the rest are in the inbox.
  static const int maxRows = 4;

  static void openInbox(BuildContext context, {required VoidCallback onCreateMatch}) {
    MatchInboxSheet.show(
      context,
      // Every game opens through /match/:id, which picks the right screen.
      onPlayMatch: (m) => context.go('/match/${m.id}'),
      onCreateMatch: onCreateMatch,
      onViewPodium: (m) => context.go('/match/${m.id}'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProfileProvider.select((p) => p.value?.uid ?? ''));
    final matches = ref.watch(userMatchesProvider).value ?? const <CloudMatch>[];
    if (myUid.isEmpty) return const SizedBox.shrink();

    final active = matches.where((m) => m.status == MatchStatus.active).toList()
      ..sort((a, b) {
        final int turn = (b.isMyTurn(myUid) ? 1 : 0) - (a.isMyTurn(myUid) ? 1 : 0);
        return turn != 0 ? turn : b.updatedAt.compareTo(a.updatedAt);
      });
    final shown = active.take(maxRows).toList();
    final int more = active.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Your matches', style: LobbyStyle.sectionLabel)),
            _InboxLink(
              label: more > 0 ? '$more more in inbox' : 'Open inbox',
              onTap: () => openInbox(context, onCreateMatch: onChallenge),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          _EmptyRow(onChallenge: onChallenge)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const double gap = 10;
              final int cols = ((constraints.maxWidth + gap) / 330).floor().clamp(1, 3);
              final double w = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final m in shown)
                    SizedBox(
                      width: w,
                      child: _MatchRow(
                        match: m,
                        myUid: myUid,
                        onTap: () => context.go('/match/${m.id}'),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _InboxLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _InboxLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Open match inbox',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(label, style: LobbyStyle.text(size: 14, weight: 600, color: LobbyStyle.soft)),
      ),
    );
  }
}

/// Nothing running: say so and offer the next step.
class _EmptyRow extends StatelessWidget {
  final VoidCallback onChallenge;
  const _EmptyRow({required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: LobbyStyle.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LobbyStyle.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'No matches running. Challenge a friend to start one.',
              style: LobbyStyle.text(size: 14, color: LobbyStyle.muted, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            semanticLabel: 'Challenge a friend',
            onTap: onChallenge,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Challenge', style: LobbyStyle.text(size: 13, weight: 700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final CloudMatch match;
  final String myUid;
  final VoidCallback onTap;

  const _MatchRow({required this.match, required this.myUid, required this.onTap});

  /// "Archery, set 3 of 5, you lead 4–2"
  String _summary() {
    final m = match;
    final mine = m.myPlayer(myUid);
    final theirs = m.opponentPlayer(myUid);
    final String game = lobbyGameById(m.game).title;
    final String unit = m.isArchery ? 'set' : 'round';
    final parts = <String>['$game, $unit ${m.currentRound} of ${m.totalRounds}'];

    if (mine != null && theirs != null) {
      final int you;
      final int them;
      if (m.isArchery) {
        final p = ArcheryRules.setPoints(mine.roundScores, theirs.roundScores);
        you = p.you;
        them = p.them;
      } else {
        you = mine.totalScore;
        them = theirs.totalScore;
      }
      if (you != 0 || them != 0) {
        parts.add(you > them
            ? 'you lead $you–$them'
            : (you < them ? 'down $you–$them' : 'level $you–$them'));
      }
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final theirs = m.opponentPlayer(myUid);
    final bool myTurn = m.isMyTurn(myUid);
    final Color accent = lobbyGameById(m.game).accent;
    final String name = theirs?.displayName ?? 'Waiting for opponent';

    return Pressable(
      semanticLabel: '$name, ${myTurn ? 'your turn' : 'their turn'}',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: LobbyStyle.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LobbyStyle.line),
        ),
        child: Row(
          children: [
            AppAvatar(avatar: theirs?.avatarEmoji ?? '⏳', size: 40, borderWidth: 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LobbyStyle.text(size: 15, weight: 700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _summary(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LobbyStyle.text(size: 13, color: LobbyStyle.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: myTurn ? accent : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                myTurn ? 'Your turn' : 'Their turn',
                style: LobbyStyle.text(
                  size: 13,
                  weight: 700,
                  color: myTurn ? LobbyStyle.ink : LobbyStyle.soft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
