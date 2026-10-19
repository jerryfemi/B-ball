# Archery Prototype — Build Plan & Guidelines

> For: the AI assistant (or developer) building the archery prototype inside the DunkVerse codebase.
> Goal: a **local-only, playable archery prototype** that *feels* great. No Firebase, no deploys, no changes to basketball.
> Integration (routing, matches, inbox) comes later, after review.

---

## 0. Ground rules (read first)

1. **Same repo, isolated folder.** All new code lives in `lib/archery/`. All new assets live in `assets/archery/`.
2. **Do not edit anything under `lib/game/`** (the basketball game), `lib/main.dart`, Firebase config, `web/index.html`, or `firebase.json`. Importing shared helpers from `lib/game/` (read-only use) is fine — e.g. `fx/game_feel.dart`, `fx/glow_sprite.dart`, `ui/common/app_colors.dart`.
   - If you believe a shared file *must* change (e.g. the audio backend), stop and write the proposed change in a note instead of making it.
3. **Separate dev entry point.** Create `lib/main_archery.dart` and run with:
   ```
   flutter run -d chrome -t lib/main_archery.dart
   ```
   The real app (`lib/main.dart`) must build and behave exactly as before.
4. **No Firebase calls, no network.** Pure local game.
5. **Performance rules (same as DunkVerse):**
   - Zero allocations in `update()` / `render()`: no `Paint()`, `Rect.fromCenter()`, `Offset(...)` chains, `List`s, `.map()`, `.where()`, closures created per frame. Cache everything on the component or as `static final`.
   - Use `package:vector_math/vector_math_64.dart` for physics; Forge2D is **not needed** for archery (do not add a Forge2D world).
   - Fixed-timestep physics, clamped frame `dt`.
   - Read device pixel ratio once and cache it.
6. **Determinism.** Physics output must depend only on the inputs (aim, draw, wind seed, time since release). No `DateTime.now()`, no `Random()` without a seed, no frame `dt` inside the physics math. This is required for multiplayer replays later.
7. **Style:** match the DunkVerse "luxury obsidian" palette for all HUD/UI (`#0A0E1A`, `#0F172A`, `#1E2638`, accents `#38BDF8`, `#00FFCC`, `#F59E0B`, `#EF4444`; text white / `#94A3B8`). No default SnackBars.

---

## 1. Folder structure

```
lib/
  main_archery.dart                 # dev-only entry: runApp(ArcheryDevApp())
  archery/
    archery_game.dart               # FlameGame: owns world, camera, round state
    archery_constants.dart          # every tunable number in ONE place
    physics/
      arrow_physics.dart            # ArrowPhysics3D: fixed-step integration + hit detection
      sight_solver.dart             # computes the "sight mark" (drop compensation) per distance
      wind_model.dart               # seeded wind + gusts
      sway_model.dart               # seeded aim sway / fatigue
      target_scoring.dart           # hit point -> ring score
    camera/
      archery_camera.dart           # yaw/pitch/FOV pinhole camera, zero-alloc projection
      camera_rig.dart               # spring-smoothed FOV zoom, shot cam, shake
    input/
      draw_aim_controller.dart      # hold-to-draw, drag-to-aim, release-to-fire
    components/
      range_background.dart         # sky, treeline, ground lanes (parallax)
      target_board.dart             # stand + straw boss + procedural face
      flying_arrow.dart             # arrow in flight (sprite between projected tip & nock)
      stuck_arrow.dart              # arrow embedded in target, quiver animation
      bow_overlay.dart              # foreground bow + string + hands
      wind_flag.dart                # small verlet cloth flag on the target pole
      wind_particles.dart           # drifting dust/leaves showing wind (SoA arrays)
      arrow_trail.dart              # faint streak from a ring buffer
    ui/
      archery_hud.dart              # score, arrows left, round, wind readout, draw meter
      hit_popup.dart                # "10", "X", "9" popup at hit point
      round_summary.dart            # end-of-round card
    telemetry/
      arrow_shot.dart               # compact record of one shot (for later replays)
assets/
  archery/
    images/ ...
    audio/ ...
test/
  archery/
    arrow_physics_test.dart
    sight_solver_test.dart
    scoring_test.dart
```

Register `assets/archery/images/` and `assets/archery/audio/` in `pubspec.yaml` (adding asset folders is the only allowed `pubspec.yaml` change).

---

## 2. World units & coordinate system

Same convention as DunkVerse so later code sharing is easy:

- Units: **meters, seconds**.
- `X` = right, `Y` = up (ground at `Y = 0`), `Z` = downrange (away from the archer).
- Archer eye: `eye = (0, 1.60, 0)`.
- Arrow nock/launch point (anchor under the chin, slightly forward): `launch = (0, 1.52, 0.35)`.
  The arrow starts **below the eye**, so the sight solver (section 5) must account for that offset. This is realistic and makes it look right.
- Target face centre: `(0, 1.30, D)` where `D` is the round distance.
- Target face: **122 cm World Archery face**, 10 rings, ring width `0.061 m`, outer radius `0.61 m`, X ring radius `0.0305 m`.
- Boss (straw block behind the face): `1.30 m × 1.30 m`, `0.30 m` deep. Hitting boss outside the face = 0 points but the arrow still sticks.

Suggested round distances: **20 m, 40 m, 60 m** (3 rounds × 3 arrows = max 90 points).

---

## 3. `archery_constants.dart` — starting values (tune by feel)

```dart
class ArcheryK {
  // Physics
  static const double gravity = 9.81;          // real gravity — arrows are fast enough
  static const double fullDrawSpeed = 62.0;    // m/s at full draw (arcade-fast, real bows ~55-90)
  static const double minDrawSpeedRatio = 0.60;// speed at 0% draw = 60% of full
  static const double fullDrawPlateau = 0.95;  // draw >= 0.95 counts as a perfect full draw
  static const double dragK = 0.0006;          // quadratic drag coefficient (1/m)
  static const double windAccelPerMps = 0.10;  // lateral accel (m/s²) per 1 m/s of wind
  static const double fixedDt = 1.0 / 240.0;   // arrows are fast: 240 Hz step
  static const int maxSubstepsPerFrame = 8;

  // Target
  static const double faceRadius = 0.61;
  static const double ringWidth = 0.061;
  static const double xRingRadius = 0.0305;
  static const double targetCenterY = 1.30;

  // Input / feel
  static const double autoDrawSeconds = 0.70;  // hold time to reach full draw
  static const double fatigueStartSeconds = 2.5;
  static const double fatigueFullSeconds = 6.0;
  static const double baseSwayRad = 0.0012;    // ≈ ±7 cm at 60 m
  static const double fatigueSwayMultiplier = 3.0;
  static const double aimSensitivity = 0.55;   // screen-px of reticle motion per px of drag

  // Camera
  static const double idleFovDeg = 42.0;
  static const double faceScreenFraction = 0.38; // target face fills 38% of screen height at full draw
  static const double fovSpringOmega = 9.0;      // critically damped spring speed
}
```

**Why these wind numbers:** with constant lateral acceleration `a = 0.10 × W`, drift ≈ `½·a·t²`.
For `W = 5 m/s` (≈ 11 mph): at 60 m (t ≈ 1.0 s) drift ≈ 0.25 m ≈ **4 rings**; at 20 m (t ≈ 0.33 s) drift ≈ 0.03 m ≈ **half a ring**.
So distance naturally makes wind matter more. Tune `windAccelPerMps` with: `K = 2 · desiredDrift / (W · t²)`.

---

## 4. Arrow physics (`arrow_physics.dart`)

### 4.1 State (preallocated, mutated in place)

```dart
class ArrowPhysics3D {
  final Vector3 pos = Vector3.zero();
  final Vector3 vel = Vector3.zero();
  final Vector3 prevPos = Vector3.zero();
  double timeSinceRelease = 0;
  double _acc = 0;
  bool inFlight = false;
  bool stuck = false;
  // hit result
  final Vector3 hitPoint = Vector3.zero();
  double hitLocalX = 0, hitLocalY = 0;  // position on target face plane, meters from centre
  int ring = 0; bool isX = false; bool hitBoss = false;
  // visual orientation (derived, NOT fed back into physics)
  double pitch = 0, yaw = 0;
}
```

### 4.2 Forces per substep

1. **Gravity:** `vel.y -= g·dt`
2. **Quadratic drag relative to air** (small — mostly gives a slight speed loss):
   `vRel = vel - windVec`; `vel -= dragK · |vRel| · vRel · dt`
3. **Wind push** (the gameplay force): `vel.x += windAccelPerMps · windX(t) · dt`
   (`windX(t)` from `WindModel`, using `timeSinceRelease`, not wall-clock time.)
4. **Position:** semi-implicit Euler — update velocity first, then `pos += vel·dt`.

Write the vector maths as scalar `x/y/z` fields (as `BallPhysics3D._contact` does) to avoid creating `Vector3` temporaries.

### 4.3 Fixed-step loop (same pattern as `BallPhysics3D.update`)

```dart
void update(double frameDt) {
  if (!inFlight) return;
  _acc += frameDt.clamp(0.0, 0.05);
  int n = 0;
  while (_acc >= ArcheryK.fixedDt && n < ArcheryK.maxSubstepsPerFrame) {
    _substep(ArcheryK.fixedDt);
    _acc -= ArcheryK.fixedDt; n++;
    if (!inFlight) break;
  }
  if (_acc > ArcheryK.fixedDt * 2) _acc = ArcheryK.fixedDt * 2;
}
```

### 4.4 Hit detection — segment crossing the target plane (no tunnelling)

At 62 m/s the arrow moves ~26 cm per 240 Hz step, so **never** test "is the arrow inside the target". Test whether the segment `prevPos → pos` crosses the plane `z = D`:

```dart
if (prevPos.z < D && pos.z >= D) {
  final f = (D - prevPos.z) / (pos.z - prevPos.z);   // 0..1
  final hx = prevPos.x + (pos.x - prevPos.x) * f;
  final hy = prevPos.y + (pos.y - prevPos.y) * f;
  hitLocalX = hx - 0.0;
  hitLocalY = hy - ArcheryK.targetCenterY;
  // inside boss square?  -> stick + score.  outside? -> keep flying to backstop/ground.
}
```

Also check ground (`y <= 0`) → arrow sticks in the grass at a shallow angle (0 points). Add a backstop plane at `z = D + 3` so arrows never fly forever.

### 4.5 Orientation (visual only)

```
pitch = atan2(vel.y, sqrt(vel.x² + vel.z²))
yaw   = atan2(vel.x, vel.z)
```

**Archer's paradox wobble** (sells the realism, purely visual):
`wobbleYaw = A · e^(−t/τ) · sin(2π·f·t)` with `A = 2°`, `f = 12 Hz`, `τ = 0.15 s`. Add it to the *render* yaw only.

**On impact:** freeze orientation at the impact direction. Push the arrow `0.06–0.12 m` into the boss (scale by speed) so part of the shaft disappears. The shaft then **quivers** (visual only): tail offset = `B · e^(−t/0.25) · sin(2π·18·t)`, `B = 1.5 cm`.

### 4.6 Scoring (`target_scoring.dart`)

```dart
final r = sqrt(hitLocalX*hitLocalX + hitLocalY*hitLocalY);
if (r > faceRadius) ring = 0;                         // boss or miss
else ring = (10 - (r / ringWidth).floor()).clamp(1, 10);
isX = r <= xRingRadius;
```

**Line-cutter rule (archery convention, feels fair):** use the arrow shaft radius (`~0.0035 m`) so touching a line scores the higher ring: `r_eff = max(0, r - shaftRadius)`.
X counts as 10; store the X count as the tiebreaker.

---

## 5. Sight solver — "the sight is calibrated for this distance" (`sight_solver.dart`)

Real archers set a sight mark per distance. We do the same, so **at full draw with no wind, the arrow lands exactly where the reticle points.** The player then only fights **wind, sway and under-drawing**. That is where the skill and fun are.

- The reticle is the screen centre, i.e. the camera's forward ray.
- At round start, solve once for `sightPitchOffset` (radians): the extra upward angle added to the launch direction so a full-draw, no-wind arrow from `launch` hits the point where the eye ray meets the plane `z = D` at the target centre.
- Because of drag (and the launch point sitting below the eye), solve **numerically using the real simulation** (the same `ArrowPhysics3D` with wind = 0):
  1. Initial guess (no-drag closed form, low arc):
     `θ = atan( (v² − sqrt(v⁴ − g(g·D² + 2·Δy·v²))) / (g·D) )`
  2. Secant iterations (5–6 max): simulate → measure vertical error at `z = D` → adjust θ. Stop when |error| < 1 mm.
- Cache per distance. Unit-test it (section 12).

**Launch direction at release:**
`launchPitch = cameraPitch + sightPitchOffset + swayPitch`
`launchYaw   = cameraYaw + swayYaw`
`speed = fullDrawSpeed · lerp(minDrawSpeedRatio, 1.0, drawCurve(draw))`, where `drawCurve(d) = d >= plateau ? 1 : d / plateau`.
An under-drawn arrow is slower, so it **drops low**. That is the punishment for releasing early, and players read it instantly.

---

## 6. Wind & sway (deterministic)

### 6.1 Wind (`wind_model.dart`)
- Per round: `seed` → `Random(seed)` → base wind `W ∈ [−Wmax, Wmax]` m/s (sign = direction), plus gust phases.
- Gusts during flight: `windX(t) = W · (1 + 0.15·sin(2.1t + φ1) + 0.08·sin(5.3t + φ2))`, where `t = timeSinceRelease`.
- Difficulty sets `Wmax`: easy 2 m/s, medium 4, hard 6, pro 8.
- Show wind as an **arrow + number** in the HUD (display in mph: `W × 2.237`), **and** visually through the flag and drifting particles. Players should be able to *feel* the wind, not only read it.
- Later (online): the seed is stored in the match document so both players face identical wind.

### 6.2 Sway / fatigue (`sway_model.dart`)
- While drawn, the aim drifts in a smooth, deterministic Lissajous pattern:
  ```
  swayYaw   = A(h) · ( sin(1.3h + p1) + 0.5·sin(2.9h + p2) ) / 1.5
  swayPitch = A(h) · ( sin(1.1h + p3) + 0.5·sin(3.7h + p4) ) / 1.5
  ```
  where `h` = seconds held at draw and `p1..p4` come from the seed.
- `A(h) = baseSwayRad` until `fatigueStartSeconds`, then ramps up to `baseSwayRad × fatigueSwayMultiplier` by `fatigueFullSeconds`. This creates the "shoot before your arms shake" tension.
- The sway moves the **camera/reticle** (so the player sees it and can counter-steer) and is included in the launch direction. Nothing is hidden or random at release.

---

## 7. Input: hold-to-draw, drag-to-aim, release-to-fire (`draw_aim_controller.dart`)

One-finger gesture, phone-friendly:

| Phase | Gesture | Effect |
|---|---|---|
| Idle | — | Wide view (idle FOV), bow lowered. |
| Touch down (anywhere) | hold | Bow raises; `draw` rises from 0 → 1 over `autoDrawSeconds` (ease-out). The camera zooms in as draw rises. |
| While held | drag | Rotates the camera (aim). `Δyaw = −dx · aimSensitivity / focalPx`, `Δpitch = dy · aimSensitivity / focalPx`. Dividing by the current focal length in pixels keeps reticle motion steady at any zoom. |
| Full draw | — | Light haptic + soft "click" sound once; draw meter flashes cyan (`#00FFCC`). |
| Release | lift finger | Fire. Medium haptic, string twang. |
| Cancel | drag to the bottom 12% of the screen and release | Let down without firing (no arrow used). |

- Clamp aim to ±12° yaw and −5° to +10° pitch around the target.
- Only light or medium haptics, and only on intentional actions (full draw, release). Skip haptics on web as `AudioEngine._safeHaptic` already does.

---

## 8. Camera (`archery_camera.dart`, `camera_rig.dart`)

Do **not** reuse `PerspectiveCamera3D`. Its rim elevation correction is hard-wired to the basketball hoop. Archery needs a camera that **rotates** (yaw/pitch) and **zooms** (FOV).

### 8.1 Projection (zero-alloc, write results into fields)

```dart
class ArcheryCamera {
  double eyeX = 0, eyeY = 1.60, eyeZ = 0;
  double yaw = 0, pitch = 0;      // radians
  double fovY = 42 * pi / 180;    // vertical FOV
  double screenW = 0, screenH = 0;
  double _f = 0, _cy = 1, _sy = 0, _cp = 1, _sp = 0;

  // call once per frame after yaw/pitch/fov change
  void prepare() {
    _f = (screenH / 2) / tan(fovY / 2);   // focal length in px
    _cy = cos(yaw); _sy = sin(yaw); _cp = cos(pitch); _sp = sin(pitch);
  }

  double sx = 0, sy = 0, depth = 0; // outputs
  bool project(double x, double y, double z) {
    // translate
    double dx = x - eyeX, dy = y - eyeY, dz = z - eyeZ;
    // rotate by -yaw around Y
    final x1 =  _cy * dx - _sy * dz;
    final z1 =  _sy * dx + _cy * dz;
    // rotate by -pitch around X
    final y2 =  _cp * dy - _sp * z1;
    final z2 =  _sp * dy + _cp * z1;
    depth = z2;
    if (z2 <= 0.05) return false;          // behind camera
    sx = screenW / 2 + _f * (x1 / z2);
    sy = screenH / 2 - _f * (y2 / z2);
    return true;
  }
  double pxPerMeterAt(double depth) => _f / depth;
}
```

### 8.2 Zoom during draw
- FOV for the target to fill `faceScreenFraction` of screen height at distance `D`:
  `fovZoomed = 2 · atan( (2·faceRadius / faceScreenFraction) / 2 / D )`
- `targetFov = lerp(idleFov, fovZoomed, easeOutCubic(draw))`
- Smooth with a **critically damped spring** (no overshoot, frame-rate independent):
  ```
  a = ω²(target − fov) − 2ω·fovVel
  fovVel += a·dt; fov += fovVel·dt
  ```
- After release: hold the zoom for ~0.15 s, then ease back out *unless* shot cam triggers.

### 8.3 Shot cam (the "wow" moment)
- Predict the hit at release by running the simulation ahead (it is deterministic; this is cheap, ~240 steps).
- If the predicted ring is **≥ 9**, or it is the round's last arrow: run **slow motion** (`timeScale = 0.3`; physics still uses fixed steps, only fed less time) and a **chase camera** that follows behind and above the arrow (`offset = (0.25, 0.12, −0.9)` m from the arrow, looking at the arrow tip). Then cut to a **target close-up** for 0.8 s showing the hit.
- Otherwise: stay on the scope view and show the hit popup at the hit point.
- Give the player a "skip" (tap) on slow-mo.

### 8.4 Shake
Reuse `ScreenFx` from `lib/game/fx/game_feel.dart`: tiny shake on release (string recoil), slightly bigger "thunk" on impact, scaled by ring (an X gets a short zoom punch).

---

## 9. Rendering & layers

Priority order (lowest drawn first):

| Priority | Layer |
|---|---|
| 0 | Sky gradient + far skyline (parallax) |
| 1 | Treeline / stadium wall (parallax) |
| 2 | Ground, lanes and distance markers (projected 3D quads) |
| 3 | Target stand + straw boss |
| 4 | Target face (procedural) |
| 5 | Stuck arrows |
| 6 | Flying arrow + trail (switch to drawing *behind* layer 4 if it misses and passes behind the boss; sort by `depth`) |
| 7 | Wind particles (near ones) |
| 10 | Bow overlay (foreground, screen-space) |
| — | Flutter HUD overlay |

### 9.1 Target face: procedural, not an image
Draw the face as concentric circles (crisp at any zoom). **Cache it** as a `ui.Image` with `PictureRecorder` at the needed size, and re-rasterize only when the on-screen size changes by more than ~15%.
World Archery colours (outer → inner pairs): white `#F5F5F0` (1–2), black `#1A1A1A` (3–4, with white lines), blue `#2E7DD7` (5–6), red `#E0322B` (7–8), gold `#F7D000` (9–10), plus a thin X ring line. Thin dividing lines between every ring.
Then draw a **paper-texture image** over it at low opacity (multiply blend) for realism, and the **straw boss image** behind it.
Because the camera nearly faces the target, a circle (not an ellipse) is fine. Use `pxPerMeterAt(depth)` for the radius.

### 9.2 Arrow sprite drawn between two projected points
- Project the **tip** and **nock** 3D points (shaft length `0.75 m` along the velocity direction).
- Draw the side-view arrow image **stretched and rotated** between the two screen points. Perspective foreshortening happens automatically: as the arrow flies away it shortens and shrinks.
- When the projected length is less than ~25% of its unforeshortened length (you are looking at it from behind), crossfade to a **rear-view sprite** (nock + 3 fletches as seen from behind).
- **Trail:** ring buffer of the last 12 tip positions in a `Float64List`, drawn as fading thin lines (cached `Paint`, update `color` alpha only).

### 9.3 Bow overlay
- A foreground bow image (vertical, centre-left, partly off-screen like a first-person view).
- Draw the **string** as two line segments from the limb tips to the nock point. The nock point moves back with `draw`, giving visible string tension.
- Limbs: either 3 pre-drawn frames (rest / half / full) cross-faded by draw, or rotate the upper and lower limb images slightly toward the archer (±6°) with draw.
- On release: the string snaps forward with a quick damped oscillation (`sin(2π·25t)·e^(−t/0.08)`); the bow kicks forward 2–3% then settles.
- Bow lowers and slides down when idle; raises with an ease-out on touch.

### 9.4 Background
- Treat sky and treeline layers as "at infinity": on yaw change, shift them by `f · tan(Δyaw)` px. They move with camera rotation but do not change size with distance.
- The ground is real 3D: project lane lines and distance markers (`20m`, `40m`, `60m` boards) using the camera, so zoom and rotation look correct.
- **Recommended setting:** a *night range under floodlights*. It matches the obsidian UI, hides background art imperfections, and floodlight glow sprites (reuse `glow_sprite.dart`) look premium.

### 9.5 Wind visuals
- **Flag** on a thin pole beside the target: small verlet cloth (8 × 5 points, preallocated `Float64List`), the same technique as `fx/net_simulation.dart`. Wind force on the cloth = current `windX`.
- **Particles:** 30–40 dust motes or leaves in structure-of-arrays typed lists (like `streak_celebration.dart`), drifting with the wind across the range at several depths, with additive glow under floodlights.

---

## 10. Static images to get (`assets/archery/images/`)

All **WebP with transparency** (PNG source is fine), sized at about **2× the largest on-screen size** (web DPR is capped at 1.5, so going bigger wastes memory).

| File | What | Approx. size |
|---|---|---|
| `bow_recurve.webp` | Recurve bow, first-person view, vertical, no string (string is drawn in code) | 600 × 1600 |
| `bow_limb_upper.webp` / `bow_limb_lower.webp` | *(optional)* separate limbs for bending | 300 × 800 each |
| `bow_hand.webp` | *(optional)* gloved hand gripping the riser | 400 × 400 |
| `arrow_side.webp` | Arrow side view, tip pointing right, carbon shaft, 3 vanes | 1200 × 60 |
| `arrow_rear.webp` | Arrow seen from behind: nock + 3 vanes at 120° | 200 × 200 |
| `target_boss.webp` | Square straw/foam boss, front view | 1024 × 1024 |
| `target_stand.webp` | Wooden A-frame stand | 1024 × 1024 |
| `target_paper_texture.webp` | Subtle paper grain (grayscale, tileable) | 512 × 512 |
| `bg_sky_night.webp` | Night sky gradient with faint haze | 1024 × 1024 |
| `bg_treeline.webp` | Dark treeline / stadium silhouette strip, transparent top | 2048 × 512 |
| `floodlight.webp` | Floodlight head (glow added in code) | 256 × 256 |
| `distance_board.webp` | Blank distance sign (number drawn in code) | 256 × 128 |
| `grass_tile.webp` | Tileable dark grass texture | 512 × 512 |

**Sources:** generate with an image tool using one consistent style prompt for every asset (same lighting and colour temperature), or use CC0 packs (e.g. Kenney.nl, OpenGameArt; check each licence). Keep one art style; mixing styles is what makes indie games look cheap.

**Audio (`assets/archery/audio/`, short WAV):** `draw_creak`, `full_draw_click`, `release_twang`, `arrow_whoosh`, `impact_boss` (thunk), `impact_face` (crisp thwack), `impact_ground`, `x_ding`. Use the existing audio backend pattern. If `AudioBackend` is keyed by the basketball `Sfx` enum, **do not modify it**; write a proposal for a generic string-keyed loader instead.

---

## 11. Game feel checklist (this is what makes it fun)

- [ ] The draw has weight: ease-out draw curve, string creak, zoom tied to draw.
- [ ] The full-draw moment is clear: click, flash, light haptic.
- [ ] Release is instant: no frame delay between finger lift and the arrow leaving.
- [ ] The impact sound reaches the player with a delay at long distance: delay impact SFX by `D / 340 s` (sound travel). Small, real, and players feel it.
- [ ] The hit popup shows the ring number in ring colour; X gets gold text + glow + short zoom punch.
- [ ] Stuck arrows stay on the target for the whole round (cap at 3), so players see their grouping.
- [ ] Slow-mo shot cam only on great shots, so it stays special.
- [ ] Sway grows if they hold too long; the tension is felt, not explained.
- [ ] A miss is readable: the player can see *why* (wind push, drop from under-draw).
- [ ] Constant 60 FPS on a mid-range Android phone in Chrome.

---

## 12. Tests (pure Dart, run with `flutter test test/archery/`)

1. **Sight solver accuracy:** for D = 20, 40, 60, a full draw with no wind aimed at the centre hits within **±1 mm** of centre.
2. **Determinism:** the same inputs (aim, draw, seed) give a **bit-identical** hit point across 100 runs, with frame dt sequences of 1/60, 1/30 and random jitter.
3. **No tunnelling:** an arrow at 90 m/s still registers a hit (plane-crossing test).
4. **Scoring:** `r = 0 → 10 + X`; `r = 0.0609 → 10`; `r = 0.0611 → 9` (and with line-cutter, `0.0611 → 10`); `r = 0.62 → 0`.
5. **Wind direction:** positive wind pushes the hit point to +X, and drift at 60 m > drift at 20 m.
6. **Under-draw:** draw = 0.5 lands below centre.

---

## 13. Milestones (build in this order; each ends with something playable)

1. **Camera + static scene:** dev entry, background, procedural target at 20 m, touch to zoom, drag to rotate the camera. *Done when:* aiming feels smooth at 60 FPS.
2. **Arrow flight, no wind:** release fires, arrow sprite between tip and nock, plane-crossing hit, arrow sticks. Sight solver + tests 1–3. *Done when:* a perfect full-draw shot hits the reticle at all 3 distances.
3. **Scoring + round loop:** 3 arrows × 3 distances, HUD score, hit popup, stuck arrows, round summary. Tests 4 and 6.
4. **Wind + sway:** seeded wind, flag, particles, HUD wind readout, fatigue sway. Test 5.
5. **Art + audio pass:** replace placeholders with the images in section 10, bow string animation, sounds, impact sound delay.
6. **Feel pass:** shot cam slow-mo, shake, X celebration, tuning numbers in `archery_constants.dart`.
7. **Telemetry:** `ArrowShot` record `{t, yaw, pitch, draw, seed, holdTime, ring, x}` with short JSON keys, plus a "replay last arrow" button that re-simulates from the record. This proves it is ready for multiplayer.

**Stop after milestone 7.** No routing, Firebase or inbox work. That integration gets reviewed and planned separately.

---

## 14. What *not* to do

- Don't use Forge2D, `audioplayers` or `just_audio`.
- Don't use `Random()` unseeded or `DateTime.now()` in gameplay logic.
- Don't put physics in `render()`, or rendering maths that allocates in `update()`.
- Don't use images for the target rings (procedural only; textures sit on top).
- Don't touch basketball files, `main.dart`, Firebase files or deploy configs.
- Don't add trajectory-preview lines on normal difficulty (wind reading is the skill). An "easy" ghost preview is allowed later as an option.
