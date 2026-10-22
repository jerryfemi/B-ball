import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'archery/archery_game_screen.dart';
import 'game/audio/audio_engine.dart';

export 'archery/archery_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AudioEngine.init());

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
    return Listener(
      onPointerDown: (_) => AudioEngine.unlockAudio(),
      onPointerUp: (_) => AudioEngine.unlockAudio(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        title: 'Archery Range Prototype',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF060913),
          fontFamily: 'Roboto',
        ),
        home: const ArcheryGameScreen(),
      ),
    );
  }
}
