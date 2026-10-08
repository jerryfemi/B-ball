import 'package:flame/components.dart';
import 'package:flame/events.dart';

class BallVisual extends SpriteComponent with TapCallbacks {
  BallVisual({required super.position, required super.size, required super.sprite});

  @override
  void onTapDown(TapDownEvent event) {
    print('Ball tapped! We will implement swipe soon.');
  }
}
