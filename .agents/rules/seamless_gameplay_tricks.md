# Seamless 2.5D Gameplay Tricks (Game Pigeon Style)

This rule defines the core illusions and physics tricks required to make a 2D Flame game feel like a premium 3D/2.5D experience (like Game Pigeon Basketball). Always refer to these techniques when implementing gameplay loops.

## 1. Faking 3D Depth (The 2.5D Trick)
- **Dynamic Sprite Scaling**: As an object moves "away" from the camera (up the screen / decreasing Y-coordinate), its scale must dynamically decrease.
  - *Implementation*: `canvas.scale(scaleFactor)` clamped between a minimum and maximum based on the current Y position.
- **Z-Index Layering (Crucial for Hoops)**: The illusion of passing *through* an object requires precise render ordering using Flame's `priority` property.
  - `priority: 0` = Background (Wall/Floor)
  - `priority: 1` = Backboard & Back-half of the rim
  - `priority: 2` = The Projectile (Basketball)
  - `priority: 3` = Front-half of the metal rim & Net.
  - *Result*: The ball will visually pass over the backboard, but behind the front rim.

## 2. Collision Filtering (Directional Solid Physics)
In a true 3D game, you shoot up through a hoop. In 2D, the rim blocks upward movement. We must fake depth using directional collision filtering.
- **The Concept**: Disable collisions with the front rim while the ball travels upwards. Enable collisions when it falls.
- **Implementation via Forge2D**:
  - Track `body.linearVelocity.y`.
  - If `velocity.y < 0` (moving UP), the ball ignores the front rim (either via `ContactFilter` or temporarily setting the rim's fixture to `isSensor = true`).
  - If `velocity.y > 0` (falling DOWN), the front rim becomes a solid physical object, allowing the ball to bounce off it realistically.

## 3. GamePigeon Specific Physics Tricks (From MetaAI Architecture)
- **Circular Rim Colliders**: The left and right edges of the rim MUST be two small static `CircleShape` bodies (radius ~0.15 - 0.25 meters / 4-6 px), not flat boxes or polygon edges. Circular contacts produce natural, realistic ball rattling, rim-rolling, and dramatic rim-outs instead of sticky polygon corners.
- **Invisible Sensor for Scoring**: The net is purely visual. Real score detection is handled by an invisible sensor box (`isSensor: true`) placed directly between the rim circles inside the hoop opening.
  - *Downward Entry Gate*: Only trigger a score if `ball.linearVelocity.y > 0` (moving downwards) when entering the sensor, preventing false scores on upward shots.
- **Bouncy Arena Boundaries (Chaotic Rebounds)**: Add invisible static walls on the left, right, and top of the screen with restitution ~0.5. When a shot misses or hits hard, it ricochets off the walls — capturing GamePigeon's signature chaotic, lively arcade feel.
- **Auto-Reset Game Loop**: The ball automatically resets to the shooter position 2-3 seconds after a throw, or once it settles / scores.

## 4. Architecture & State Decoupling
- **Input to Physics**: Map `onDragEnd` / `onPanEnd` vector velocities directly to `body.applyLinearImpulse()` for 1:1 user-to-game physical interaction. Scale the vector down appropriately for Box2D meters.
- **State Management**: Keep Flame entirely decoupled from UI State. 
  - Flame handles the Game Loop (physics, collisions, timers).
  - Use Riverpod (or a similar robust state manager) to pass scores, streaks, and match status OUT to Flutter overlays. 
  - Flutter overlays handle real-time leaderboards, backend Sync (Firebase/Supabase), and chat, completely separate from the Canvas rendering.
