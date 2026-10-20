import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'archery/archery_game.dart';
import 'archery/ui/archery_hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait / natural orientation for smartphone archery
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ArcheryDevApp());
}

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

class ArcheryGameScreen extends StatefulWidget {
  const ArcheryGameScreen({super.key});

  @override
  State<ArcheryGameScreen> createState() => _ArcheryGameScreenState();
}

class _ArcheryGameScreenState extends State<ArcheryGameScreen> {
  late final ArcheryGame _game;

  @override
  void initState() {
    super.initState();
    _game = ArcheryGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _game.controller.onPointerDown(
              event.pointer,
              event.localPosition.dx,
              event.localPosition.dy,
            );
          },
          onPointerMove: (event) {
            _game.controller.onPointerMove(
              event.pointer,
              event.localPosition.dx,
              event.localPosition.dy,
            );
          },
          onPointerUp: (event) {
            _game.controller.onPointerUp(event.pointer);
          },
          onPointerCancel: (_) {
            _game.controller.onPointerCancel();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The Flame 3D Archery Game Canvas
              GameWidget(game: _game),

              // The Flutter Luxury Obsidian HUD Overlay
              ArcheryHud(game: _game),
            ],
          ),
        ),
      ),
    );
  }
}
