# Flame Engine Core Concepts

Always adhere to these Flame component system (FCS) principles and paradigms when writing game code for this project.

## 1. The Game Loop & GameWidget
- **GameWidget**: The bridge between standard Flutter Widgets and the Flame game engine. The game loop runs inside this.
- **update(dt)**: The logic/physics loop. `dt` is delta time. Never put rendering logic here.
- **render(Canvas)**: The drawing loop. Never put game logic, state changes, or physics calculations here.

## 2. Flame Component System (FCS)
- Everything in Flame is a `Component`.
- **Component Tree**: The game acts as the root. Adding a component to a parent means the parent automatically calls `update` and `render` on that child.
- **Lifecycle Methods**:
  - `onLoad()`: Async method called once. Best place to load assets or initialize heavy objects.
  - `onMount()`: Called when the component is added to the active tree.
  - `onRemove()`: Called when the component is removed.

## 3. PositionComponent
- The core class for anything with a physical presence.
- Provides `position`, `size`, `scale`, `angle`, and `anchor`.
- **Anchors**: Controls origin point (e.g. `Anchor.center` means position is the center of the size bounds).
- **Coordinate System**: Children are positioned relative to their parent's coordinate system.

## 4. SpriteComponents
- `SpriteComponent`: Renders a static image asset.
- `SpriteAnimationComponent`: Renders a spritesheet/sequence of images over time, managing frame timings automatically via the game loop.

## 5. ParallaxComponent
- Used for scrolling backgrounds to simulate 3D depth.
- Allows multiple image layers to scroll at independent velocities (foreground faster, background slower).

## 6. ShapeComponents
- `CircleComponent`, `RectangleComponent`, `PolygonComponent`.
- Used for drawing vector shapes directly to the canvas without images.
- Distinct from Box2D/Forge2D physics shapes; these are strictly for Flame's rendering/hitbox systems. Excellent for visual debugging of physics bodies.

## 7. Utility Components
- `TimerComponent`: Executes logic after a delay or periodically, using the game's `dt`. The proper way to handle timeouts in Flame (do not use `Future.delayed`).
- `FpsTextComponent`: Drop-in component to display current framerate for optimization tracking.

## Forge2D Integration Notes
- When using `flame_forge2d`, use `BodyComponent`.
- `BodyComponent` relies on the physics world for its `position` and `angle`, overriding standard `PositionComponent` behavior.
- Remember: Forge2D operates in meters (typically 1 meter = 10 pixels via camera zoom). Always explicitly handle the translation between screen pixels and world meters.
