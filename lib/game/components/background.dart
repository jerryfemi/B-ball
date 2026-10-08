import 'package:flame/components.dart';

class GameBackground extends Component with HasGameReference {
  late SpriteComponent brickWall;
  late SpriteComponent woodenFloor;

  @override
  Future<void> onLoad() async {
    // Load images
    final brickImage = await game.images.load('brick_wall.jpg');
    final floorImage = await game.images.load('wooden_floor.jpg');

    // The brick wall takes the top 2/3 of the screen
    final brickHeight = game.size.y * 0.66;
    brickWall = SpriteComponent(
      sprite: Sprite(brickImage),
      size: Vector2(game.size.x, brickHeight),
      position: Vector2(0, 0),
    );

    // The wooden floor takes the bottom 1/3 of the screen
    final floorHeight = game.size.y - brickHeight;
    woodenFloor = SpriteComponent(
      sprite: Sprite(floorImage),
      size: Vector2(game.size.x, floorHeight),
      position: Vector2(0, brickHeight),
    );

    add(brickWall);
    add(woodenFloor);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final brickHeight = size.y * 0.66;
      brickWall.size = Vector2(size.x, brickHeight);

      final floorHeight = size.y - brickHeight;
      woodenFloor.size = Vector2(size.x, floorHeight);
      woodenFloor.position = Vector2(0, brickHeight);
    }
  }
}
