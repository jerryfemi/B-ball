import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../archery/archery_game_screen.dart' show ArcheryChallenge;
import '../notifications/app_notices.dart';
import '../notifications/notice_stack.dart';
import 'game_catalog.dart';
import 'lobby_style.dart';
import 'widgets/active_matches_banner.dart';
import 'widgets/featured_hero.dart';
import 'widgets/game_card.dart';
import 'widgets/lobby_header.dart';
import 'widgets/made_by_footer.dart';

/// The GameVerse lobby (`/games`): jersey wordmark and account chip, a
/// banner that slides through the games (featured one first), your running
/// matches, then every game as a tile with its gameplay art.
///
/// The screen itself watches nothing; the account chip and the matches
/// section each watch only what they show.
class GameLobbyScreen extends StatelessWidget {
  const GameLobbyScreen({super.key});

  /// Keeps the lobby readable on desktop instead of stretching edge to edge.
  static const double _maxContentWidth = 1180;

  static bool get _online => Firebase.apps.isNotEmpty;

  /// New 1v1 match. The setup dialog has a game picker, so this works for
  /// every game; it opens on archery.
  static void _challenge(BuildContext context) {
    ArcheryChallenge.start(context, showGamePicker: true);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double side = width < 600 ? 18 : 32;
    final LobbyGame lead = featuredGame;

    return Scaffold(
      backgroundColor: LobbyStyle.ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 20, side, 0),
                  sliver: const SliverToBoxAdapter(child: LobbyHeader()),
                ),
                // Invites and friend requests from any game, right under
                // the header. Swipe one away to deal with it later.
                if (_online)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          if (ref.watch(visibleNoticesProvider).isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: NoticeStack(
                              onOpenMatch: (m) => context.go('/match/${m.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                  sliver: SliverToBoxAdapter(
                    child: HeroCarousel(
                      games: heroGames,
                      onPlay: (g) => context.go(g.route),
                      onChallenge: _online ? () => _challenge(context) : null,
                    ),
                  ),
                ),
                if (_online)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, 36, side, 0),
                    sliver: SliverToBoxAdapter(
                      child: ActiveMatchesSection(onChallenge: () => _challenge(context)),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 36, side, 14),
                  sliver: SliverToBoxAdapter(
                    child: Text('All games', style: LobbyStyle.sectionLabel),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const double gap = 20;
                      final double w = constraints.crossAxisExtent;
                      final int columns = w > 720 ? 3 : (w > 460 ? 2 : 1);
                      final double tileW = (w - gap * (columns - 1)) / columns;
                      // Picture (16:10 inside a 3 px ring) + caption.
                      final double tileH = (tileW - 10) * 10 / 16 + 10 + GameCard.captionHeight;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: gap,
                          mainAxisExtent: tileH,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final game = lobbyGames[i];
                            return GameCard(
                              game: game,
                              highlighted: identical(game, lead),
                              onTap: () => context.go(game.route),
                            );
                          },
                          childCount: lobbyGames.length,
                        ),
                      );
                    },
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 56, 20, 40),
                  sliver: SliverToBoxAdapter(child: MadeByFooter()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
