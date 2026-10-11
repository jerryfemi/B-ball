import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'game/basketball_game.dart';
import 'game/ui/game_hud_overlay.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeForge2D();
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
  runApp(const BasketballApp());
}

class BasketballApp extends StatelessWidget {
  const BasketballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Basketball Challenge',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GameWidget<BasketballGame>(
          game: BasketballGame(),
          overlayBuilderMap: {
            'HUD': (context, game) => GameHudOverlay(game: game),
          },
          initialActiveOverlays: const ['HUD'],
        ),
      ),
    );
  }
}
