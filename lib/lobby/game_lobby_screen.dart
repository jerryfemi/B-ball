import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'game_catalog.dart';
import 'widgets/active_matches_banner.dart';
import 'widgets/game_card.dart';
import 'widgets/lobby_header.dart';

/// The GameVerse lobby (`/games`): account chip, active-matches strip and a
/// responsive grid of games ([lobbyGames]).
///
/// The screen itself watches nothing; the header chip and the matches strip
/// each watch only what they show.
class GameLobbyScreen extends StatelessWidget {
  const GameLobbyScreen({super.key});

  /// Keeps the lobby readable on desktop instead of stretching edge to edge.
  static const double _maxContentWidth = 1100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  sliver: SliverToBoxAdapter(child: LobbyHeader()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverToBoxAdapter(child: ActiveMatchesBanner()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'SELECT A GAME',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final double w = constraints.crossAxisExtent;
                      final int columns = w > 720 ? 3 : (w > 500 ? 2 : 1);
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 220,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final game = lobbyGames[i];
                            return GameCard(
                              game: game,
                              onTap: () => context.go(game.route),
                            );
                          },
                          childCount: lobbyGames.length,
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 36)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
