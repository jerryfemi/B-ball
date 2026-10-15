import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'firebase_options.dart';
import 'game/audio/audio_engine.dart';
import 'game/basketball_game.dart';
import 'game/ui/game_hud_overlay.dart';
import 'services/auth_service.dart';
import 'services/chat_read_receipt_service.dart';
import 'services/update/update_service.dart';
import 'services/vatar/vatar_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DunkVerse',
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
      ),
    );
  }
}
