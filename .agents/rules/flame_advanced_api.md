# Flame Advanced API & Effects Reference

This rule defines the exact code snippets and API usage for Camera, Effects, Collisions, Rendering, Layout, and Overlays in Flame.

## 1. Camera & World API
```dart
// Setting up a fixed resolution viewport
camera.viewport = FixedResolutionViewport(resolution: Vector2(400, 800));

// Moving the camera's viewfinder
camera.viewfinder.position = Vector2(100, 200);
camera.viewfinder.zoom = 10.0;
camera.viewfinder.anchor = Anchor.center;

// Adding components to the HUD (moves with camera) vs Background
camera.viewport.add(ScoreTextComponent()); // Stays on screen
camera.backdrop.add(StaticBackground()); // Renders behind the world
```

## 2. Effects API (Full Details)

### Effect Controllers
Every effect requires an `EffectController`.
```dart
final controller = EffectController(
  duration: 1.5, // Time to complete one forward iteration
  reverseDuration: 1.5, // Time to reverse (creates a ping-pong)
  infinite: true, // Loop forever
  curve: Curves.easeIn, // Flutter animation curve
  alternate: true, // Ping-pongs back to start
  startDelay: 0.5, // Waits before starting
);
```

### Move Effects
```dart
// Move to an absolute position
component.add(MoveEffect.to(Vector2(100, 100), EffectController(duration: 1.0)));

// Move by a relative offset
component.add(MoveEffect.by(Vector2(0, -50), EffectController(duration: 1.0)));

// Move along a specific path (list of waypoints)
final path = [Vector2(10, 10), Vector2(50, -20), Vector2(100, 10)];
component.add(MoveAlongPathEffect(Path(path), EffectController(duration: 2.0)));
```

### Rotate & Scale Effects
```dart
// Rotate by 90 degrees (tau / 4 radians)
component.add(RotateEffect.by(tau / 4, EffectController(duration: 1.0)));
component.add(RotateEffect.to(tau, EffectController(duration: 1.0)));

// Scale component (e.g. pulsing)
component.add(ScaleEffect.by(Vector2.all(1.5), EffectController(
  duration: 0.5, reverseDuration: 0.5, infinite: true
)));
```

### Size & Anchor Effects
```dart
// SizeEffect only works on components with a mutable size (not scale!)
component.add(SizeEffect.to(Vector2(200, 200), EffectController(duration: 1.0)));

// AnchorEffect: animates the anchor point seamlessly
component.add(AnchorEffect.to(Anchor.center, EffectController(duration: 1.0)));
```

### Color & Opacity Effects
```dart
// Requires a component that uses a Paint object (like ShapeComponent or SpriteComponent)
// Fades out entirely
component.add(OpacityEffect.fadeOut(EffectController(duration: 1.5)));
component.add(OpacityEffect.to(0.5, EffectController(duration: 1.0)));

// Tints the component red
component.add(ColorEffect(Colors.red, EffectController(duration: 1.0), opacityTo: 0.8));
```

### Sequence & Combined Effects
```dart
// CombinedEffect: Runs multiple effects simultaneously
final combined = CombinedEffect([
  MoveEffect.by(Vector2(10, 10), EffectController(duration: 1)),
  ScaleEffect.by(Vector2.all(2.0), EffectController(duration: 1)),
]);

// SequenceEffect: Runs effects sequentially (one after the other)
final sequence = SequenceEffect([
  MoveEffect.by(Vector2(100, 0), EffectController(duration: 1)),
  MoveEffect.by(Vector2(0, 100), EffectController(duration: 1)),
]);
component.add(sequence);
```

### Remove & Function Effects
```dart
// FunctionEffect: executes a callback over time (0.0 to 1.0)
component.add(FunctionEffect(
  (double progress) { print('Progress: $progress'); },
  EffectController(duration: 1.0),
));

// RemoveEffect: removes the component from the game tree
component.add(RemoveEffect(delay: 2.0)); // Wait 2s, then remove()
```

## 3. Rendering API

### Text Rendering
```dart
// Basic text rendering using TextPaint
final textPaint = TextPaint(
  style: const TextStyle(
    fontSize: 48.0,
    color: Colors.white,
    fontFamily: 'Awesome Font',
  ),
);
final textComp = TextComponent(
  text: 'Score: 0',
  textRenderer: textPaint,
  position: Vector2(20, 20),
);
add(textComp);
```

### Decorators (Visual Shaders/Filters)
```dart
// Decorators alter how a component is drawn.
final paintDecorator = PaintDecorator.blur(3.0); // Adds blur
component.decorator.addLast(paintDecorator);

final shadow = PaintDecorator.shadow(const Shadow(color: Colors.black, blurRadius: 4));
component.decorator.addLast(shadow);
```

## 4. Layout API
Flame layout components behave exactly like Flutter widgets.
```dart
// Row Layout
final row = RowComponent(
  position: Vector2(10, 10),
  gap: 10,
  children: [
    SpriteComponent(sprite: mySprite1),
    SpriteComponent(sprite: mySprite2),
  ],
);

// Aligning a component relative to its parent
final aligned = AlignComponent(
  alignment: Anchor.topRight,
  child: ScoreComponent(),
);
parentComponent.add(aligned);
```

## 5. Overlays
```dart
// In your Flutter widget tree:
GameWidget(
  game: MyBasketballGame(),
  overlayBuilderMap: {
    'PauseMenu': (BuildContext context, MyBasketballGame game) {
      return Center(
        child: ElevatedButton(
          child: Text('Resume'),
          onPressed: () {
            game.overlays.remove('PauseMenu');
            game.resumeEngine();
          },
        ),
      );
    },
  },
)

// Inside the Flame Game code:
game.overlays.add('PauseMenu');
game.pauseEngine();
```
