# Flame Assets & Inputs API Reference

This rule defines how to handle assets and event-based inputs in Flame.

## 1. Asset Directory Structure
Flame requires assets to be placed exactly in these directories, registered in `pubspec.yaml`:
```text
.
└── assets
    ├── audio
    │   └── explosion.mp3
    ├── images
    │   ├── enemy.png
    │   └── player.png
    └── tiles
        └── map.tmx
```
- Flame automatically prepends `assets/images/` when you call `Flame.images.load('player.png')` or `Sprite.load('player.png')`.
- Do NOT include `assets/images/` in the code string. 

## 2. Input Events API

In modern Flame, inputs are handled via **Mixins** on your Components (from `package:flame/events.dart`). 

### Tap Events (`TapCallbacks`)
Used to detect clicks/taps on a specific component (Component must have a size/hitbox).
```dart
import 'package:flame/events.dart';

class MyButton extends PositionComponent with TapCallbacks {
  @override
  void onTapDown(TapDownEvent event) {
    // Fired immediately when pointer touches down on this component
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Fired when pointer is released inside this component
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    // Fired if the pointer moves outside the component before releasing
  }
}
```

### Drag Events (`DragCallbacks`)
Used to detect continuous sliding/swiping on a component.
```dart
class MyDraggable extends PositionComponent with DragCallbacks {
  @override
  void onDragStart(DragStartEvent event) {
    // Fired when the drag begins
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Fired continuously as the pointer moves
    position += event.localDelta; // Example: Move component
  }

  @override
  void onDragEnd(DragEndEvent event) {
    // Fired when the pointer is released. 
    // event.velocity gives the swipe speed!
  }
}
```

### Keyboard Events (`KeyboardEvents`)
Used to detect key presses. Mixin can be applied to the `FlameGame` itself or individual components (if focused).
```dart
import 'package:flutter/services.dart';

class MyGame extends FlameGame with KeyboardEvents {
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      // Move up
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
```
*Note: Also available is `HasKeyboardHandlerComponents` for delegating to children using `KeyboardHandler` mixin.*

### Scale Events (`ScaleCallbacks`)
Used for pinch-to-zoom gestures.
```dart
class MapCamera extends Component with ScaleCallbacks {
  @override
  void onScaleUpdate(ScaleUpdateEvent event) {
    // event.scale is a multiplier (e.g., 1.5 for zooming in)
  }
}
```

### Pointer Events (`PointerCallbacks`)
Low-level pointer events, capturing exact hover, down, and move details at the rawest level. Usually, `TapCallbacks` or `DragCallbacks` are preferred.

## Global Rule for Inputs
- The component **MUST** have a defined `size` (or a `Shape` if it's a `BodyComponent`) for Flame to calculate if the pointer intersects with it. If `size` is `Vector2.zero()`, tap and drag events will never fire!
