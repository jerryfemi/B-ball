import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'archery/archery_game_screen.dart';
import 'darts/darts_game_screen.dart';
import 'game/basketball_game.dart';
import 'game/ui/game_hud_overlay.dart';
import 'lobby/game_lobby_screen.dart';
import 'routes/match_route_screen.dart';

/// Central GameVerse GoRouter setup.
///
/// Clean URLs without hashes (#) supported via [usePathUrlStrategy]:
/// - `/`: Basketball game (stays default)
/// - `/bball`: Basketball alias
/// - `/games`: GameVerse Lobby
/// - `/archery`: Standalone & 1v1 Archery Range
/// - `/darts`: 501 / Cricket Darts preview
/// - `/match/:id`: Auto-dispatching match loader
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const BasketballScreen(),
    ),
    GoRoute(
      path: '/bball',
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/games',
      builder: (context, state) => const GameLobbyScreen(),
    ),
    GoRoute(
      path: '/archery',
      builder: (context, state) => const ArcheryGameScreen(),
    ),
    GoRoute(
      path: '/darts',
      builder: (context, state) => const DartsGameScreen(),
    ),
    GoRoute(
      path: '/match/:id',
      builder: (context, state) {
        final matchId = state.pathParameters['id'] ?? '';
        return MatchRouteScreen(matchId: matchId);
      },
    ),
  ],
);

/// Primary screen for the DunkVerse basketball arcade game.
class BasketballScreen extends StatefulWidget {
  const BasketballScreen({super.key});

  @override
  State<BasketballScreen> createState() => _BasketballScreenState();
}

class _BasketballScreenState extends State<BasketballScreen> {
  late final BasketballGame _game;

  @override
  void initState() {
    super.initState();
    _game = BasketballGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: GameWidget<BasketballGame>(
        game: _game,
        overlayBuilderMap: {
          'HUD': (context, game) => GameHudOverlay(game: game),
        },
        initialActiveOverlays: const ['HUD'],
      ),
    );
  }
}
