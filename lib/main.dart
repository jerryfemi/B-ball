import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'archery/archery_game_screen.dart';
import 'darts/darts_game_screen.dart';
import 'firebase_options.dart';
import 'game/audio/audio_engine.dart';
import 'game/basketball_game.dart';
import 'game/ui/game_hud_overlay.dart';
import 'lobby/game_lobby_screen.dart';
import 'routes/match_route_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_read_receipt_service.dart';
import 'services/update/update_service.dart';
import 'services/vatar/vatar_bridge.dart';

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
      builder: (context, state) => const _BasketballScreen(),
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  unawaited(AudioEngine.init());
  unawaited(UpdateService.instance.initialize());
  unawaited(ChatReadReceiptService.instance.init());
  await initializeForge2D();
  try {
    await VatarBridge.instance.init();
  } catch (e) {
    debugPrint('[Main] Vatar init notice: $e');
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Main] Firebase Core init error: $e');
  }
  unawaited(AuthService.instance.initialize());
  runApp(const ProviderScope(child: BasketballApp()));
}

class BasketballApp extends StatefulWidget {
  const BasketballApp({super.key});

  @override
  State<BasketballApp> createState() => _BasketballAppState();
}

class _BasketballAppState extends State<BasketballApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AudioEngine.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      AudioEngine.onAppForeground();
      UpdateService.instance.checkForUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AudioEngine.unlockAudio(),
      onPointerUp: (_) => AudioEngine.unlockAudio(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'GameVerse',
        theme: ThemeData.dark(),
        routerConfig: appRouter,
      ),
    );
  }
}

class _BasketballScreen extends StatefulWidget {
  const _BasketballScreen();

  @override
  State<_BasketballScreen> createState() => _BasketballScreenState();
}

class _BasketballScreenState extends State<_BasketballScreen> {
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
