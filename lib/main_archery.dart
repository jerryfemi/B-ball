import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'archery/archery_game.dart';
import 'archery/state/archery_match_notifier.dart';
import 'archery/ui/archery_hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait / natural orientation for smartphone archery
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: ArcheryDevApp(),
    ),
  );
}

/// Standalone archery range application harness (Build Plan v2 §5, Review §1.2, Bug #7).
///
/// Completely decoupled from Firebase, basketball match models, and main.dart.
class ArcheryDevApp extends StatelessWidget {
  const ArcheryDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archery Range Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060913),
        fontFamily: 'Roboto',
      ),
      home: const ArcheryGameScreen(),
    );
  }
}

class ArcheryGameScreen extends HookConsumerWidget {
  const ArcheryGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArcheryGame game = useMemoized(
      () => ArcheryGame(events: ref.read(archeryMatchProvider.notifier)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Flame 3D Archery Game Canvas with its isolated touch Listener (Bug #7)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                game.controller.onPointerDown(
                  event.pointer,
                  event.localPosition.dx,
                  event.localPosition.dy,
                );
              },
              onPointerMove: (event) {
                game.controller.onPointerMove(
                  event.pointer,
                  event.localPosition.dx,
                  event.localPosition.dy,
                );
              },
              onPointerUp: (event) {
                game.controller.onPointerUp(event.pointer);
              },
              onPointerCancel: (_) {
                game.controller.onPointerCancel();
              },
              child: GameWidget(game: game),
            ),

            // 2. The Flutter Luxury Obsidian HUD Overlay (on top of canvas)
            ArcheryHud(game: game),
          ],
        ),
      ),
    );
  }
}
