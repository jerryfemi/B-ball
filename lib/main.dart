import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'game/basketball_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeForge2D();
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
        body: GameWidget(
          game: BasketballGame(),
        ),
      ),
    );
  }
}
