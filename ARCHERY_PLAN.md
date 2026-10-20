# Archery Prototype — Build Plan v2 (GamePigeon-style)

> For: the AI assistant building the archery prototype inside the DunkVerse repo.
> **v2 replaces v1.** Milestones 1–3 of v1 are done. After studying a screen recording of GamePigeon Archery, the **camera, aiming controls, shot sequence and scene** change. The physics core stays.
> Still local-only: no Firebase, no deploys, no changes to basketball.

---

## 0. Ground rules (unchanged from v1)

1. All code in `lib/archery/`, all assets in `assets/archery/`, dev entry `lib/main_archery.dart`:
   `flutter run -d chrome -t lib/main_archery.dart`
2. **Do not edit** `lib/game/**` (basketball), `lib/main.dart`, Firebase files, `web/index.html`, `firebase.json`. Read-only imports of shared helpers are fine.
3. No Firebase, no network.
4. **Zero allocations** in `update()`/`render()`: no `Paint()`, `Rect`, `Offset`, `List`, `.map/.where` or closures per frame. Allocating on one-off *events* (an impact, a round end) is fine.
5. **Deterministic physics:** results depend only on inputs + seeds. No `DateTime.now()`, no unseeded `Random()`, no frame `dt` inside physics maths.
6. HUD colours: DunkVerse obsidian palette (already in `ArcheryK`).

---

## 1. What changes from v1 (migration table)

| Area | v1 (built) | v2 (GamePigeon) | Action |
|---|---|---|---|
| `physics/arrow_physics.dart` | fixed-step flight, plane-crossing hit | same | **Keep** |
| `physics/target_scoring.dart` | ring scoring, line-cutter | same, new face size | **Keep**, update constants |
| `physics/sight_solver.dart` | pitch offset for centre | also needs a pitch for any aim height | **Extend** (§5) |
| `physics/wind_model.dart` | one crosswind per round, m/s | **new wind every arrow**, 2D direction, GamePigeon-style number | **Rewrite** (§6) |
| `physics/sway_model.dart` | moves the camera, fatigue after 2.5 s | moves the **crosshair**: settles, steady window, then fatigue | **Rewrite** (§4.3) |
| `camera/archery_camera.dart` | yaw/pitch/FOV pinhole | **no rotation**. Camera only **slides along Z** (dolly). Add lens shift `cy`. | **Simplify** (§3.1) |
| `camera/camera_rig.dart` | spring zoom on draw, drag rotates camera | **shot-sequence state machine** (line → raise → aim → chase → close-up → return) | **Rewrite** (§3.2) |
| `input/draw_aim_controller.dart` | hold-to-draw, drag rotates view | **touch-and-hold, thumb-roll moves crosshair**, steady ring, timer arc, release fires | **Rewrite** (§4) |
| Draw power / under-draw drop | release early = slow arrow | **removed.** Every arrow flies at full speed. Skill = steadiness + wind reading. | **Remove** |
| `components/range_background.dart` | night range, floodlights, drawn shapes | **daytime park** made of billboard images + **ground shader** + haze | **Replace** (§7) |
| `components/bow_overlay.dart` | first-person drawn bow | bow sits on the right edge at the line, **slides out** when aiming | **Rework** (§8.1) |
| Format | 3 rounds × 3 arrows at 20/40/60 m | **sets of 3 arrows at 50 ft (15.24 m)**, set points | **Change** (§9) |
| Slow-mo shot cam (great shots only) | — | **chase cam on every arrow, normal speed**, always ends on a close-up | **Replace** |
| Wind flag, particles, floodlights | planned | **not used** | **Drop** |

### 1.1 Bug to fix now
`ArcheryGame.update()` calls `_notifyHud()` **every frame**, which rebuilds the Flutter HUD 60 times a second. Only notify on real state changes (shot fired, impact, score change, phase change, wind change). The crosshair and rings are drawn on the Flame canvas, not in the Flutter HUD, so they don't need notifications.

---

## 2. World & constants (update `ArcheryK`)

Units: meters, seconds. `X` right, `Y` up (ground `Y = 0`), `Z` downrange. The shooting line is `Z = 0`.

```dart
// Distance: GamePigeon uses 50 ft
static const double distanceM = 15.24;          // 50 ft
static const String distanceLabel = '50ft';

// Target (smaller face suits 50 ft; 80 cm WA face)
static const double faceRadius   = 0.40;
static const double ringWidth    = 0.040;
static const double xRingRadius  = 0.020;
static const double targetCenterY = 1.30;
static const double boardWidth   = 1.00;   // white square board
static const double boardHeight  = 1.00;
static const double boardFrame   = 0.025;  // brown wooden edge
static const double legHeight    = 0.80;   // board bottom height above ground

// Physics: keep v1 values (gravity, fullDrawSpeed 62, dragK, fixedDt 1/240)

// Camera
static const double fovYDeg        = 60.0;   // wide portrait view, like GamePigeon
static const double horizonFrac    = 0.52;   // lens shift: horizon sits at 52% of screen height
static const double camLineZ       = -2.0;   // "at the line" view (behind the shooter)
static const double camAimZ        = 1.0;    // aiming view (pushed in)
static const double camCloseupDist = 2.2;    // close-up: camera this far in front of the target
static const double chaseBehind    = 1.2;    // chase cam distance behind the arrow
static const double chaseAbove     = 0.15;

// Aim
static const double aimGain        = 3.0;    // crosshair px per px of thumb movement (tune 2.5–5)
static const double aimSmoothOmega = 18.0;   // low-pass on crosshair (removes touch jitter)
static const double ringStartRadiusFrac = 0.30; // steady ring starts at 30% of screen width
static const double ringSettleSeconds   = 1.8;  // ring shrinks to minimum over this time
static const double shotTimerSeconds    = 5.0;  // arc fills over this; full = auto-fire

// Sway (radians of aim angle)
static const double swaySettle   = 0.0060;  // big wobble right after touch
static const double swaySettleTau = 0.6;    // decays with this time constant
static const double swayBase     = 0.0008;  // small wobble during the steady window
static const double swayFatigue  = 0.0035;  // grows near the end of the timer
static const double fatigueStart = 3.5;     // seconds into the hold

// Wind (GamePigeon-style number 0.0 – 2.0)
static const double windMaxDisplay = 2.0;
static const double windLateralAccelPerUnit = 1.9;  // m/s² per 1.0 of displayed wind (crosswind)
static const double windAlongAccelPerUnit   = 0.6;  // m/s² per 1.0 (tail/head wind)
```

**Wind calibration:** flight time at 50 ft is about 0.25 s. A pure crosswind of `1.0` gives drift ≈ ½·1.9·0.25² ≈ **6 cm ≈ 1.5 rings**, and `2.0` gives about 3 rings. That matches how much GamePigeon players aim off. Tune `windLateralAccelPerUnit` until it feels right.

---

## 3. Camera

### 3.1 `ArcheryCamera`: no rotation, dolly only, lens shift

The camera **never turns**. It always looks straight down `+Z` and only moves its position (`eyeX`, `eyeY`, `eyeZ`). This keeps billboards perfectly correct (§7) and makes the ground shader maths exact.

```dart
void prepare() {
  _f  = (screenH * 0.5) / tan(fovY * 0.5);
  _cx = screenW * 0.5;
  _cy = screenH * ArcheryK.horizonFrac;   // lens shift instead of pitch
}
bool project(double x, double y, double z) {
  final dz = z - eyeZ;
  depth = dz;
  if (dz <= 0.05) return false;
  final inv = 1.0 / dz;
  sx = _cx + _f * (x - eyeX) * inv;
  sy = _cy - _f * (y - eyeY) * inv;
  return true;
}
// Inverse: screen point -> point on the plane z = planeZ (for aiming)
void unprojectToPlane(double sx, double sy, double planeZ) {
  final dz = planeZ - eyeZ;
  outX = eyeX + (sx - _cx) * dz / _f;
  outY = eyeY - (sy - _cy) * dz / _f;
}
```
Remove `yaw`, `pitch` and the trig. `fovY` stays fixed (60°). Optionally narrow it by 2–4° in the close-up for a gentle zoom feel.

### 3.2 `CameraRig`: shot-sequence state machine

Every move eases in and out, and nothing cuts. This is the main reason GamePigeon feels smooth.

| Phase | Camera | Duration | HUD |
|---|---|---|---|
| `atLine` | `eyeZ = camLineZ`, `eyeY = 1.6` | until touch | score bar visible, wind pill visible, "50ft" tag visible |
| `raising` | ease `eyeZ` from `camLineZ` → `camAimZ` (easeInOutCubic) | 0.6 s | score bar fades out; bow slides out (§8.1) |
| `aiming` | still at `camAimZ` (shake only) | until release / timer | crosshair, steady ring, timer arc, wind pill |
| `chase` | `eyeZ = min(arrow.z − chaseBehind, D − camCloseupDist)`; `eyeX → lerp(eyeX, arrow.x, 0.8)`; `eyeY = arrow.y + chaseAbove`. Smooth with a critically damped spring (ω ≈ 14) so the start does not jerk. | ~0.4–0.6 s | nothing (clean view) |
| `closeup` | settle at `eyeZ = D − camCloseupDist`, `eyeX = 0`, `eyeY = targetCenterY` | 1.4 s | "+10" popup, score bar fades in and counts up |
| `returning` | ease back to `camLineZ`, `eyeY = 1.6` | 0.8 s | wind pill shows the **new** wind |
| `setEnd` (after the 3rd arrow) | stay in close-up | 2.0 s | big "SET n  29 - 25" card over the target, "+1" set point flies to the avatar |

- The arrow's physics starts at the shooting line (`launchZ`) no matter where the camera is. The camera position is visual only.
- Camera shake (keep v1's): small on release, a "thunk" on impact, bigger for X.

---

## 4. Aiming controls (`draw_aim_controller.dart` rewrite)

How GamePigeon works (confirmed by the developer, who plays it): **touch and hold**. The "hold steady" ring starts loading. You **don't drag**. You **roll or tilt your thumb** in place. The touch point shifts a few pixels, and the game magnifies that into crosshair movement. Releasing fires.

### 4.1 Thumb-roll crosshair
```
onPointerDown(p):  anchor = p; crosshair = aimCenter; phase -> raising
onPointerMove(p):  rawTarget = aimCenter + (p - anchor) * aimGain     // anchor-relative, NOT accumulated deltas
update(dt):        crosshairSmooth += (rawTarget - crosshairSmooth) * (1 - exp(-aimSmoothOmega * dt))
                   crosshairShown  = crosshairSmooth + swayOffsetPx
onPointerUp:       fire at crosshairShown (if phase == aiming), else cancel back to atLine
```
- `aimCenter` is the projected target centre in the aiming view, so a perfectly still thumb aims dead centre.
- Clamp the crosshair to a box of about ±1.6 × board width around the target.
- Flutter delivers tiny pointer moves from thumb roll on iOS and Android. Don't add a "touch slop" threshold.
- Ignore extra fingers (track the first pointer id only).

### 4.2 Steady ring + timer arc (drawn on the canvas, centred on the crosshair)
- **Steady ring:** a thin, faint pink-red circle (`#EF4444` at ~30% alpha, 2 px). Its radius goes from `ringStartRadiusFrac × screenW` down to about 1.3 × crosshair size over `ringSettleSeconds` (easeOutCubic). It tells the player when they are steady.
- **Timer arc:** a solid red arc (`#EF4444`, 4 px, round caps) just outside the steady ring, **filling clockwise from 12 o'clock** over `shotTimerSeconds`. When full, the arrow **auto-fires** at the current crosshair.
- **Crosshair:** four short red dashes (`#EF4444`) with a 1.5 px white outline and a **gap in the middle (no centre dot)**. The dashes are ~10 px long, starting ~6 px from the centre.
- Cache every `Paint`. Use `canvas.drawArc` with a cached `Rect`: update it only when the radius changes by more than 0.5 px, or translate the canvas and draw at a fixed rect.

### 4.3 Sway (deterministic, visible)
The crosshair the player **sees** includes the sway, and the arrow goes **exactly where the visible crosshair is** (plus wind). Nothing hidden or random happens at release.
```
A(t) = swaySettle * exp(-t / swaySettleTau)                          // settling after touch
     + swayBase                                                       // steady window
     + swayFatigue * smoothstep(fatigueStart, shotTimerSeconds, t)    // arms tiring
swayYaw   = A(t) * (sin(1.3t + p1) + 0.5 sin(2.9t + p2)) / 1.5
swayPitch = A(t) * (sin(1.1t + p3) + 0.5 sin(3.7t + p4)) / 1.5
swayOffsetPx = (swayYaw, -swayPitch) * focalPx                       // small-angle conversion
```
`t` = seconds since touch-down; `p1..p4` come from the arrow's seed. Result: shooting too early is shaky, the best window is around 1.8–3.5 s, and waiting too long gets shaky again. The timer forces a decision.

---

## 5. From crosshair to launch (`sight_solver.dart` extension)

Rule: **with no wind, the arrow lands exactly under the crosshair.**

1. Aim point on the target plane: `camera.unprojectToPlane(crosshairShown, D)` → `(Px, Py)`.
2. Launch yaw: `atan2(Px − launchX, D − launchZ)`.
3. Launch pitch: extend the solver to `solvePitch(distance, targetY)`. Reuse the existing secant method with `targetY` instead of `targetCenterY`. Cache the centre solution and use a small-angle correction for other heights: `pitch(Py) ≈ pitchCentre + atan((Py − centreY)/(D − launchZ))`, then **one** secant refinement step. Unit-test it: error < 1 mm for any aim within the board.
4. Speed: always `fullDrawSpeed`.

Arrow physics (v1) then adds wind (§6). Hit detection, scoring, penetration and quiver stay as built.

---

## 6. Wind (`wind_model.dart` rewrite)

- **New wind for every arrow**, seeded from `seed = hash(matchSeed, setIndex, arrowIndex)`.
- `display = round1(rng.nextDouble() * windMaxDisplay)` → a value like 0.8, 1.0 or 1.8, shown with one decimal.
- `angle = rng.nextDouble() * 2π` (0 = blowing **downrange/away**, π/2 = blowing **right**).
- Forces in `ArrowPhysics3D._substep` (replace the v1 wind term):
  ```
  ax += display * sin(angle) * windLateralAccelPerUnit * gust(t)
  az += display * cos(angle) * windAlongAccelPerUnit   * gust(t)   // tailwind -> lands slightly higher
  gust(t) = 1 + 0.10 sin(2.1t + φ1) + 0.05 sin(5.3t + φ2)
  ```
- **Wind pill** (world-anchored above the target, re-projected every frame so it moves with the camera): dark rounded pill (`#0A0E1A` at 70% alpha), bold white text `WIND: 0.8`, then a 22 px circle outline with a small arrow inside rotated to the wind angle (pointing up = blowing away from you, right = blowing right). Show it in `atLine` and `aiming`, hide it during chase and close-up.

---

## 7. The scene: billboards + ground shader (replaces `range_background.dart`)

Because the camera never rotates and only slides along Z, the whole park can be **flat images standing at different depths**. Each one is scaled by `f / (z − eyeZ)`. When the camera moves forward, near objects grow fast and slide off the screen edges while far ones barely change. That parallax is what makes it feel 3D.

### 7.1 Layers (back to front)

| Layer | Placement | Rendering |
|---|---|---|
| Sky + mountains | infinitely far | one image, screen-space, fixed; optional 1–2% scale-up during the dolly for life |
| Distant hills / tree mass | `z ≈ 60 m` | billboard strip, full width, transparent top |
| Hedge row | `z ≈ D + 4` | billboard strip (dark green hedge) |
| Tree line behind target | `z ≈ D + 6 … D + 15` | 6–10 tree billboards, varied scale, some flipped |
| Side trees | both sides of the lane, `x = ±4…±9 m`, `z = 2…D + 3` | 8–14 tree billboards (reuse 4–6 images) |
| Ground (grass, stripes, lane lines, shadows) | `y = 0` | **one fragment shader draw** (§7.2) |
| Tree shadows | under each tree | blob-shadow sprite, flattened (§7.4) |
| Target board + legs | `z = D` | board image + procedural rings (§8.2) |
| Stuck / flying arrows | — | v1 components |
| Bow | screen-space foreground | §8.1 |

**Billboard maths** (per object, per frame, no allocation):
```
camera.project(obj.x, obj.baseY, obj.z) -> (sx, sy, depth)
scale = camera.pxPerMeterAt(depth) * obj.widthMeters / image.width
draw anchored at bottom-centre: (sx - image.width*scale/2, sy - image.height*scale)
```
- **Best performance:** put all tree, hedge and hill images in **one texture atlas** and draw every billboard in **one `canvas.drawRawAtlas` call**. Keep preallocated `Float32List`s for transforms (RSTransform: scale, 0, tx, ty) and source rects; refill the transforms each frame. Sort back-to-front once at load (positions are static).
- Otherwise: `canvas.save(); translate; scale; drawImage(img, Offset.zero, paint); restore()`. That pattern allocates nothing.
- Skip objects with `depth <= 0.3` (the camera has passed them) and objects fully off-screen.

### 7.2 Ground shader (`shaders/archery_ground.frag`)

Perspective-correct mowed stripes, grass texture, lane lines and haze in a single draw. It stays exact while the camera moves because the camera never rotates.

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;        // canvas size px
uniform float uHorizonY;    // px (= horizonFrac * height)
uniform float uFocal;       // px
uniform float uEyeX;        // m
uniform float uEyeY;        // m (camera height)
uniform float uEyeZ;        // m
uniform float uStripeLen;   // m, e.g. 2.0
uniform vec4  uGrassA;      // light stripe
uniform vec4  uGrassB;      // dark stripe
uniform vec4  uHaze;        // haze colour (sky-ish)
uniform float uHazeDist;    // m, e.g. 45
uniform float uTargetZ;     // m (D)
uniform sampler2D uGrassTex;// tileable grass detail

out vec4 fragColor;

float lineMask(float x, float halfW, float pxPerM) {
  // anti-aliased line of half-width halfW (m)
  float d = abs(x) - halfW;
  return 1.0 - clamp(d * pxPerM + 0.5, 0.0, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float dy = p.y - uHorizonY;
  if (dy <= 0.5) { fragColor = vec4(0.0); return; }

  float dist   = uEyeY * uFocal / dy;                 // distance ahead (m)
  float wx     = uEyeX + (p.x - uSize.x * 0.5) * dist / uFocal;
  float wz     = uEyeZ + dist;
  float pxPerM = uFocal / dist;

  // mowed stripes (bands across the lane)
  float stripe = mod(floor(wz / uStripeLen), 2.0);
  vec3 col = mix(uGrassA.rgb, uGrassB.rgb, stripe);

  // grass detail, faded with distance to avoid shimmer (no mipmaps)
  vec3 tex = texture(uGrassTex, fract(vec2(wx, wz) * 0.35)).rgb;
  float detail = exp(-dist / 18.0);
  col *= mix(1.0, 0.7 + 0.6 * tex.g, detail);

  // lane lines: centre line + two lines converging toward the target legs (the "V")
  float onLane = step(0.0, wz) * step(wz, uTargetZ);
  float t = clamp(wz / uTargetZ, 0.0, 1.0);
  float sideX = mix(3.2, 0.55, t);                     // from wide at the line to the legs
  float lines = max(lineMask(wx, 0.025, pxPerM),
                max(lineMask(wx - sideX, 0.04, pxPerM),
                    lineMask(wx + sideX, 0.04, pxPerM))) * onLane;
  // shooting line across the lane at z = 0
  lines = max(lines, lineMask(wz, 0.05, pxPerM) * step(abs(wx), 6.0));
  col = mix(col, vec3(0.97), lines * 0.92);

  // atmospheric haze
  float haze = 1.0 - exp(-dist / uHazeDist);
  col = mix(col, uHaze.rgb, haze * 0.55);

  fragColor = vec4(col, 1.0);
}
```
- Register it under `flutter: shaders:` in `pubspec.yaml`, load once with `FragmentProgram.fromAsset`, keep one `FragmentShader`, and update uniforms each frame (`setFloat`, no allocation).
- Draw it with one `drawRect` covering the screen below the horizon, using a cached `Paint` whose `shader` is set once.
- Grass colours to start from: `uGrassA = #4E9A2E`, `uGrassB = #3F8424`, haze `#BFD7E6`.

### 7.3 Haze on billboards
Tint each billboard toward the haze colour by its distance (`1 − exp(−z/45)`, about 0.55 max). Billboards are static, so **precompute one `ColorFilter` per billboard at load**. Use `ColorFilter.matrix` (a lerp toward the haze colour) and keep it on that billboard's `Paint`. This is the single biggest "looks real" upgrade.

### 7.4 Soft tree shadows
Reuse the radial blob-shadow sprite idea from `lib/game/components/ball.dart`: one 64×64 cached image. For each tree, draw it on the ground at the tree's base, stretched to about 1.6× the canopy width and **flattened** by `eyeY / sqrt(eyeY² + dist²)`, at 35% alpha. Offset it slightly to one side, as if the sun is to the left.

### 7.5 Venues are data
```dart
class VenueTheme {
  final String skyImage;
  final List<BillboardSpec> billboards; // image id, x, baseY, z, widthMeters, flipX
  final Color grassA, grassB, haze;
  final double stripeLen;
  final bool laneLines;
  final TargetStyle targetStyle;        // board style for this venue
}
```
- **Park** (first, matches GamePigeon): mountains + sky, hills, hedge, round broad-leaf trees, striped lawn, white lane lines.
- **Dojo / kyudo range** (second): you shoot from a **wooden shooting hall**. Its roof edge is a foreground billboard at `z ≈ 0.6` that frames the top of the screen and slides out of view upward as the camera dollies forward, which is a lovely effect. Across a raked-sand or moss lawn (shader with `grassA == grassB`, sand colours, no lane lines) stands a **target shed (azuchi)**: a tiled roof over a sand bank, with the target hanging in front. Add pine and bamboo billboards, a stone lantern, and a white plaster wall with a dark tiled cap behind. Keep WA ring scoring, styling the face as a round hanging target with no square board.

---

## 8. Foreground & target visuals

### 8.1 Bow (`bow_overlay.dart` rework)
- **`atLine`:** wooden recurve bow on the **right edge** (`x ≈ 0.80 W`), vertical, slightly rotated (−6°), extending from about 30% to 100% of screen height. The arrow rests on it, pointing diagonally toward the target: draw the shaft from the bow's grip toward a point just below the target, with **red vanes**.
- **`raising`:** over 0.5 s, the bow slides down and right, scales up 1.15× and fades out. For about 0.2 s you see the **arrowhead** near the bottom centre-right before it leaves the frame.
- **`returning`:** the bow slides back in (reverse ease) with a fresh arrow nocked.
- String: two thin lines from the limb tips to the nock (no draw animation needed now).

### 8.2 Target board (`target_board.dart` update)
- White square board (`boardWidth`) with a thin **brown wooden frame**, a small dark **screw in each corner**, and two brown **wooden legs** down to the ground.
- Face (procedural, cached `ui.Image`, re-rasterize only when the on-screen size changes by more than 15%): two outer **white** rings, then **black**, **blue**, **red**, **gold**, with thin dividing lines and small dots along the horizontal and vertical lines through the centre. Overlay a faint **paper texture** image (multiply, ~25%).
- In the close-up the board fills ~70% of screen width, so rasterize the face at that size.

### 8.3 Arrow in flight (`flying_arrow.dart` update)
In the chase cam the arrow is seen **from behind and slightly above**: a thin shaft and **three red vanes**. Use the rear-view sprite when the projected length is short (as v1 planned). There is no spin and almost no wobble during chase, which keeps it clean. Keep a very faint trail or drop it.

### 8.4 Hit popup + scores (`hit_popup.dart`, HUD)
- **Popup:** `+10` / `+9` / `+6` in a chunky rounded bold font, **amber-gold fill (`#F59E0B`) with a dark 3 px outline**. It appears at the hit point, scales 0.6 → 1.15 → 1.0 (0.25 s, back-out), rises ~40 px over 1.0 s and fades over the last 0.3 s.
- **Score bar (top):** settings gear on the left, your avatar on a green circle with "You", a dark rounded box with small `SET 1` above the big `0 - 25`, and the opponent's avatar on a purple circle. **Hidden during aiming and chase**; visible at the line and in the close-up. Scores **count up** (0.4 s) instead of jumping.
- **Set end:** a large dark translucent card over the target showing `SET 1` / `29 - 25` with both avatars beside it. The set winner gets a `+1` that flies to their avatar, and a **gold coin with the set count** appears under the avatar.

---

## 9. Format & local game loop

- **Sets of 3 arrows.** The higher set total wins **1 set point**; a tie gives each player 1. **First to 3 set points** wins. Keep these numbers in `ArcheryK` so they're easy to tune.
- Local prototype modes:
  - **Practice:** endless sets, solo.
  - **Pass-and-play:** player 1 shoots 3 arrows, then player 2 shoots 3 arrows with the **same wind seeds**. This proves the fairness rule needed for online play.
- Before player 2's turn, replay player 1's 3 arrows in the close-up (popups and count-up). That's how GamePigeon opens a turn, and it exercises the telemetry/replay path (§11).

---

## 10. Images & audio (`assets/archery/`)

One consistent **painted, soft, slightly stylised** look (not photo-real, not flat vector). Generate every image with the **same style description** and lighting (sun upper-left, soft shadows), with **transparent backgrounds** wherever images overlap. WebP, about 2× the largest on-screen size (web DPR is capped at 1.5).

**Park**
| File | Notes | Size |
|---|---|---|
| `park/sky_mountains.webp` | soft sky, light clouds, purple-pink stylised mountains, full screen | 1500 × 1400 |
| `park/hills.webp` | distant green hills + tree mass strip, transparent top | 2048 × 512 |
| `park/hedge.webp` | dark green hedge strip | 2048 × 256 |
| `park/tree_1..5.webp` | round broad-leaf trees, painted leaves, varied shapes, transparent | 800 × 900 each |
| `park/grass_detail.webp` | tileable grass detail (greyscale is fine) for the shader | 512 × 512 |

**Dojo / kyudo**
| File | Notes | Size |
|---|---|---|
| `dojo/sky.webp` | soft dusk or overcast sky | 1500 × 1400 |
| `dojo/hall_roof.webp` | dark wooden roof edge + beams, foreground frame, transparent bottom | 1600 × 500 |
| `dojo/hall_floor.webp` | polished wooden floor edge at the bottom | 1600 × 300 |
| `dojo/azuchi.webp` | target shed: tiled roof, sand bank | 1200 × 800 |
| `dojo/wall.webp` | white plaster wall with dark tile cap strip | 2048 × 400 |
| `dojo/pine_1..2.webp`, `dojo/bamboo.webp`, `dojo/lantern.webp` | billboards | 600–900 px |
| `dojo/sand_detail.webp` | tileable raked-sand detail | 512 × 512 |

**Shared**
| File | Notes | Size |
|---|---|---|
| `bow_recurve.webp` | vertical wooden recurve bow, grip wrap, no string | 500 × 1600 |
| `arrow_side.webp` | thin shaft, red vanes, tip pointing right | 1200 × 60 |
| `arrow_rear.webp` | nock + 3 red vanes seen from behind | 200 × 200 |
| `board_frame.webp` | white board with brown frame + 4 screws (face drawn in code) | 1024 × 1024 |
| `board_legs.webp` | two wooden legs | 512 × 512 |
| `paper_texture.webp` | subtle paper grain | 512 × 512 |
| `shadow_blob.webp` | *(or generate in code)* | 64 × 64 |

**Audio:** `raise_whoosh`, `string_release`, `arrow_flight`, `impact_board` (thunk), `impact_center` (thwack + bright ding for X), `score_tick` (soft tick for the count-up), `set_win`. Don't modify the basketball `Sfx` enum or `AudioBackend`; if a shared change is needed, write a proposal note instead.

---

## 11. Tests (`flutter test test/archery/`)

Keep v1's tests (determinism, no tunnelling, scoring) and add:
1. **Crosshair → hit:** with no wind and no sway, the hit point equals the unprojected crosshair point within **1 mm**, for 25 aim points across the board.
2. **Wind:** display 1.0 at angle π/2 drifts the hit to +X by 5–7 cm; angle 0 (tailwind) raises the hit slightly; display 0 → no drift.
3. **Seeds:** the same `(matchSeed, set, arrow)` always gives the same wind and sway phases. Different arrows give different winds.
4. **Sway curve:** `A(0) > A(2.5)` and `A(4.9) > A(2.5)` (shaky → steady → shaky).
5. **Projection round-trip:** `project(unprojectToPlane(p)) == p` within 0.01 px.

---

## 12. Milestones (continuing from v1's milestone 3)

4. **Controls + camera migration:** dolly-only camera, thumb-roll crosshair, steady ring, timer arc with auto-fire, new sway, crosshair→launch (§3.1, §4, §5). Per-arrow wind with pill (§6). Fix the HUD notify bug (§1.1). Tests 1–5.
   *Done when:* touch-hold-release at 50 ft feels like GamePigeon on a phone.
5. **Shot sequence:** state machine (§3.2), bow slide-out/in, chase cam, close-up, popups, hidden/visible score bar, count-up, set format + set-end card (§8, §9).
6. **Park scene:** billboard renderer + atlas, ground shader, haze, shadows, park images (§7, §10). Remove the floodlight night range.
7. **Audio + feel pass:** sounds, shake tuning, easing tuning, aim gain tuning on real phones (iPhone Safari + Android Chrome).
8. **Dojo venue** as a second `VenueTheme`.
9. **Telemetry + replay:** `ArrowShot {seed, holdMs, crossX, crossY, hitX, hitY, ring, x}` with short JSON keys, plus the turn-start replay (§9).

**Stop after 9.** No routing, Firebase or inbox work. That integration is reviewed and planned separately.

---

## 13. Don'ts

- Don't rotate the camera (it breaks billboards and the ground shader).
- Don't use Forge2D, `audioplayers` or `just_audio`.
- Don't use unseeded randomness or wall-clock time in gameplay.
- Don't draw the target rings from an image (procedural only; texture on top).
- Don't show a trajectory preview line.
- Don't touch basketball files, `main.dart`, Firebase or deploy configs.
