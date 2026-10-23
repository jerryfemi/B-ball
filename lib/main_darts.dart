import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'darts/darts_constants.dart';
import 'darts/darts_game.dart';
import 'darts/state/darts_match_notifier.dart';
import 'game/audio/audio_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AudioEngine.init());

  // Portrait orientation for smartphone darts
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: DartsDevApp(),
    ),
  );
}

/// Standalone Darts 301 application harness (DARTS_PLAN.md Step 8).
///
/// Completely decoupled from Firebase, basketball match models, and main.dart.
class DartsDevApp extends StatelessWidget {
  const DartsDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AudioEngine.unlockAudio(),
      onPointerUp: (_) => AudioEngine.unlockAudio(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        title: 'Darts 301 Prototype',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(DartsK.surfaceDark),
          fontFamily: 'Roboto',
        ),
        home: const DartsHarnessScreen(),
      ),
    );
  }
}

/// Standalone harness screen hosting [DartsGame].
class DartsHarnessScreen extends ConsumerWidget {
  const DartsHarnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.read(dartsMatchProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(DartsK.surfaceDark),
      body: GameWidget<DartsGame>.controlled(
        gameFactory: () => DartsGame(events: events),
      ),
    );
  }
}
