# Archery Code Review — Round 1

> Scope: everything in `lib/archery/`, `lib/main_archery.dart`, `shaders/archery_ground.frag`, `assets/archery/`.
> Hand this to the implementing assistant together with `ARCHERY_PLAN.md` (v2).
> **The physics core is good** (`arrow_physics.dart`, `sight_solver.dart`, `target_scoring.dart`). Most problems are in the camera flow, aiming maths, rendering, responsiveness and leftover boilerplate.

Work through the sections in the order given in **§8**.

---

## 1. The developer's complaints → causes → fixes

### 1.1 "Full screen shows more of the scene; small screens / phones show less"
**Cause:** `ArcheryCamera.prepare()` derives the focal length from the **vertical** FOV only (`_f = (H/2)/tan(30°)`). On a wide desktop window the horizontal view becomes ~100°; on a portrait phone it shrinks to ~30°, so the trees and lane edges get cut off.

**Fix:** guarantee a **minimum horizontal FOV** as well, and take whichever focal length is smaller (the "contain" rule):
```dart
// archery_constants.dart
static const double fovYDeg    = 60.0;
static const double minFovXDeg = 56.0;   // never show less than this horizontally

// archery_camera.dart
double zoom = 1.0;            // 1 = normal, >1 = aiming zoom (see 1.4)
double _baseF = 0.0;

void prepare() {
  if (screenW <= 0 || screenH <= 0) return;
  final fV = (screenH * 0.5) / math.tan(ArcheryK.fovYRad * 0.5);
  final fH = (screenW * 0.5) / math.tan(ArcheryK.minFovXRad * 0.5);
  _baseF = math.min(fV, fH);
  _f = _baseF * zoom;
  _cx = screenW * 0.5;
  _cy = screenH * ArcheryK.horizonFrac;
}
double get baseFocal => _baseF;
```
- A phone in portrait now sees the same width of the range as a desktop, plus extra sky and grass above and below. Desktop is unchanged.
- **Sky must "cover", not "fit width"** (`range_background.dart:130`): `scale = max(screenW / imgW, (horizonY + 40) / (imgH * 0.78))`, centred horizontally, mountain base on the horizon. Fill any gap above with the fallback gradient (already there).
- Add one **UI scale** used by every canvas overlay (crosshair, steady ring, wind pill text, bow, popup):
  `uiScale = (min(screenW, screenH) / 400).clamp(0.85, 1.6)`. Compute it in `onGameResize` and pass it in; don't use hard-coded pixel sizes.

### 1.2 "I need max width: on full screen the dialog and scoreboard should not stretch; on small screens they should be fluid"
`archery_hud.dart:38` pins the score bar to `left: 16, right: 16`, so on desktop it stretches to 1900 px. Wrap every HUD block:
```dart
Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: scoreBar),
  ),
)
```
- Score bar: `maxWidth: 520`. Set-end card: `maxWidth: 420`. Bottom hint: intrinsic width (already fine).
- Below 520 px they fill the width minus 12 px margins (fluid). Above, they stay centred.
- Inside the bar, use `Expanded`/`Flexible` for the centre column so small phones don't overflow. Test at 320, 390, 768 and 1920 px wide.

### 1.3 "The arrow is awful"
Causes (`flying_arrow.dart`, `stuck_arrow.dart`, `bow_overlay.dart`):
1. **Size clamps fight perspective.** In the chase cam the arrow is ~1.2 m from the camera, so it should be thick and large. But `shaftWidth.clamp(1.5, 5.0)` and `vaneLen.clamp(6, 24)` turn it into a long hairline with tiny vanes.
2. **Flat 2D vanes.** Vanes are drawn as two side triangles. Seen from behind (the chase view), a real arrow shows **three vanes 120° apart around the shaft**.
3. **Off-style colours:** a cyan "index" vane, cyan nock and blue trail. GamePigeon uses all-red vanes and no trail.
4. **Pop-in:** the arrow launches at z = 0.35 m, *behind* the aiming camera (z = 1.0). For a few frames the tip is a few centimetres in front of the camera and projects enormous.
5. **The nocked arrow at the shooting line** uses fixed pixel offsets (`tipX = -260, tipY = -120`), so on narrow screens it points across the screen instead of at the target (visible in screenshot 2).

**Fix: one shared 3D arrow renderer** (`components/arrow_renderer.dart`) used by the flying arrow, stuck arrows and the bow:
```
forward f = vel / |vel|      (stuck arrow: impact direction)
right   r = normalize(f × worldUp),   up u = r × f
tip  = pos
nock = pos − f * L                     L = 0.75 m

Shaft: project tip and nock. Width at each end = pxPerMeterAt(depth) * shaftR * 2.
       Draw a 4-point polygon (perspective taper), dark carbon #1F2937, plus a 1 px
       lighter highlight line. If projected length < nock width (looking straight down
       the shaft), draw a circle at the nock instead.
Point: last 0.04 m at the tip, steel #94A3B8, 1.3× shaft width.
Vanes: 3 vanes at roll angles θ0 + k·120°. Radial direction d_k = cos θ·r + sin θ·u.
       Corners (arrow-local, metres):
         A = nock + f·0.015 + d·shaftR
         B = nock + f·0.110 + d·shaftR
         C = nock + f·0.045 + d·(shaftR + 0.024)
         D = nock + f·0.020 + d·(shaftR + 0.024)
       Project 4 corners → filled Path, red #EF4444, shaded by facing
       (lerp to #B91C1C when the vane faces away from the camera).
Order: vanes whose d points away from the camera → shaft → remaining vanes.
Roll:  in flight θ0 = 2π · 3 · t (visual spin; looks great in the chase cam). Stuck: θ0 fixed.
Cull:  skip drawing while nock depth < 0.35 m (fixes the pop-in).
No min/max clamps: let perspective size it. Arcade-thick constants: shaftR = 0.0045, vane height 0.024.
```
- Delete the blue trail (or make it a barely visible white streak at most).
- Bow overlay at the line: draw the nocked arrow from the bow's nock **toward the projected target centre** (`camera.project(0, targetCenterY, D)`), length ≈ 30% of the screen-space distance, not toward fixed pixels.
- The bow itself should be the `bow_recurve.webp` image (plan §10), sized by `screenH * 0.75 * uiScale`, not 14 px procedural strokes.

### 1.4 "On hold it should zoom a bit more"
Today "zoom" is only a dolly from z = −2 to z = +1 (×1.21). At 50 ft a ring is about **2 px wide** on a 900 px-high screen, so aiming is pixel-hunting.
- **Zoom with focal length, not dolly** (this also avoids the arrow-behind-camera problem): keep `camAimZ = 1.0` and ease `camera.zoom` from 1 → `aimZoom` during `raising` (same 0.6 s easeInOutCubic). Ease it back to 1 during the first 0.25 s of `chase`.
- **Size the zoom by the screen, not a constant**, so every device sees the same target size:
  ```dart
  // face diameter while aiming = aimFaceFrac × the smaller screen side
  static const double aimFaceFrac = 0.26;   // tune 0.22–0.32
  final depth = ArcheryK.distanceM - ArcheryK.camAimZ;
  aimZoom = (aimFaceFrac * math.min(W, H) * depth) / (2 * ArcheryK.faceRadius * camera.baseFocal);
  ```
- **Make aim sensitivity screen-independent** (`draw_aim_controller.dart:105`): express it as "thumb pixels to reach the target edge":
  ```dart
  static const double thumbPxToFaceEdge = 22.0;  // tune 16–30
  final faceRadiusPx = camera.pxPerMeterAt(depth) * ArcheryK.faceRadius; // at aim zoom
  final gain = faceRadiusPx / thumbPxToFaceEdge;
  ```
- The ground shader already reads `camera.focal`, so it zooms correctly for free.

### 1.5 "The grass has no texture, too generic"
Measured: `grass_detail.webp` is **256×256 and almost flat** (green-channel std-dev = 8/255). The shader multiplies it by `0.7 + 0.6·g`, which gives about ±2% brightness variation, so it's invisible. It's also sampled at one scale (a 2.9 m tile), so it would look repetitive even with contrast.

**Asset:** replace it with a **512×512 tileable, greyscale** grass texture with **strong contrast (std-dev ≥ 40/255)** and short blade strokes running roughly vertically (along the lane). Colour comes from the shader.

**Shader** (`archery_ground.frag`): two scales + mowing sheen + correct anti-aliasing. Replace the stripe and detail section with:
```glsl
float pxPerMx = uFocal / dist;                    // px per metre across the lane
float pxPerMz = uFocal * uEyeY / (dist * dist);   // px per metre ALONG the lane (foreshortened)

// mowed stripes with anti-aliased edges (hard edges shimmer while the camera moves)
float s     = wz / uStripeLen;
float band  = mod(floor(s), 2.0);
float dEdge = min(fract(s), 1.0 - fract(s)) * uStripeLen * pxPerMz;   // px to nearest edge
float stripe = mix(0.5, band, clamp(dEdge, 0.0, 1.0));
vec3 col = mix(uGrassA.rgb, uGrassB.rgb, stripe);

// two-scale detail: blades (~0.8 m tile) + patches (~9 m tile)
float fine  = texture(uGrassTex, fract(vec2(wx, wz) * 1.25)).r;
float patch = texture(uGrassTex, fract(vec2(wx, wz) * 0.11 + 0.37)).r;
float fineFade = clamp((pxPerMx - 25.0) / 60.0, 0.0, 1.0);   // fade blades before they alias
col *= mix(1.0, 0.72 + 0.56 * fine, fineFade * 0.9);
col *= 0.86 + 0.28 * patch;
// mowing sheen: blades on light stripes catch more light
col *= mix(1.0, 1.06, stripe < 0.5 ? 1.0 : 0.0);
// subtle hue drift so it isn't one flat green
col = mix(col, col * vec3(1.10, 1.03, 0.82), patch * 0.35);
```
Also use `pxPerMz` (not `pxPerM`) for the **shooting line** mask, because it's a horizontal line. Otherwise it flickers and changes thickness as the camera moves:
```glsl
lines = max(lines, (1.0 - clamp(abs(wz) * pxPerMz - 0.05 * pxPerMz + 0.5, 0.0, 1.0)) * step(abs(wx), 6.0));
```
Add soft **contact darkening** under the target stand (multiply by `0.8` within 0.6 m of `(0, D)`) so the board looks grounded.

### 1.6 "The trees have white edges, like they were cropped out of a background"
**Confirmed by pixel analysis of `tree_1.webp`:** the semi-transparent edge pixels average RGB (246, 252, 236), which is almost pure white, and there's a 1–2 px **fully opaque white rim** left by the background-removal tool. The haze filter and the code are not the cause; it's in the images.

**Fix (asset pipeline):** run `tools/defringe.py` (in the repo) on every cut-out image:
```
pip install pillow numpy
python tools/defringe.py assets/archery/park/tree_1.webp assets/archery/park/tree_1.webp
python tools/defringe.py assets/archery/park/tree_2.webp assets/archery/park/tree_2.webp
python tools/defringe.py assets/archery/park/tree_3.webp assets/archery/park/tree_3.webp
python tools/defringe.py assets/archery/park/hills.webp  assets/archery/park/hills.webp
```
It un-blends the white out of the edge pixels, shaves the opaque white rim (`--erode 2`, increase to 3 if any rim remains), bleeds real leaf colours into the transparent area so scaling never pulls white back in, and saves WebP with `exact=True`. It was tested on `tree_1.webp` and the rim is gone.

For future AI-generated assets, ask for **"on a solid magenta (#FF00FF) background"** (then `--bg 255,0,255`) or a mid-grey background rather than white, and cut out at 2× size.

---

## 2. Bugs & bad maths (ranked)

| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | `draw_aim_controller.dart:88-95` | The crosshair starts at the **horizon** (`camera.opticalCenterY`), not the target centre. The target centre is 0.3 m lower, so every shot starts ~**7 rings high** and the player must pull down. | Start at `camera.project(0, targetCenterY, D)` **computed with the aiming pose** (eyeZ = camAimZ, zoom = aimZoom). Clamp around that same point. |
| 2 | `camera_rig.dart:661 + 783` | `cancelAim()` → `returning`, but `returning` always starts from the **close-up position** (`startZ = D − 2.2`). Lifting the finger before the raise finishes makes the camera **teleport to the target** and fly back. | Store `_fromX/_fromY/_fromZ/_fromZoom` when *any* phase starts, and have every eased phase lerp `from → to`. |
| 3 | `camera_rig.dart:768-781` | The close-up "ease" is `current += (target − current) * ease(t)` every frame. That's a compounding lerp: frame-rate dependent and not an ease (it snaps after ~3 frames). | Same as #2: `pos = lerp(from, to, ease(t))`. |
| 4 | `archery_game.dart:254` + rig | Set-end flow: last arrow → close-up → **returns to the line** → callback → `setEnd` **snaps the camera back to the close-up**. | After the 3rd arrow: `closeup → setEnd` directly (stay at the target). Return to the line only after "Continue". |
| 5 | `archery_hud.dart:68` | The set-end card condition reads `cameraRig.phaseTime > 1.0` inside `build()`. `build` only runs on notifications, so the card appears late and at random. | Drive the card from an explicit `setEnd` phase/state (see §5). |
| 6 | `hit_popup` + `archery_game.dart:421` | The popup position is projected **at impact, while the camera is still in chase**. The camera then moves to the close-up, so the "+10" floats somewhere other than the arrow. | Draw the popup on the Flame canvas, re-projecting `hitPoint` every frame (cached `TextPainter` per label), or project with the known close-up pose. |
| 7 | `main_archery.dart:61` | The `Listener` wraps the **whole Stack, HUD included**, so taps on HUD buttons also start an aim. | Put the `Listener` around `GameWidget` only. Mark non-interactive HUD parts `IgnorePointer`. |
| 8 | `flying_arrow.dart:376` | `updateTrail()` (state change) runs inside `render()`. Render and update don't always run 1:1. | Move to `update()` (or delete the trail; see 1.3). |
| 9 | `target_board.dart:33-41` | Leg and cross-brace stroke widths are **fixed pixels** (8 px / 5 px), so they're too thick at the line and hairlines in the close-up. | `strokeWidth = pxPerM * 0.05` (legs), `* 0.035` (brace), set per frame on the cached Paint. |
| 10 | `target_board.dart:204-276` | `picture` is never disposed (leak). The face re-rasterizes asynchronously several times during the close-up dolly, so it's briefly blurry. | Rasterize **once** at close-up size (cap 1024), `picture.dispose()`, then always draw scaled with `FilterQuality.medium`. Delete `_isRasterizing` and the 15% logic. |
| 11 | `draw_aim_controller.dart:178` / `camera_rig.dart` | `fireShot()` is called twice (controller + game callback). | Call it in one place only (the game). |
| 12 | `archery_game.dart:139` | `matchSeed = 101` is constant, so every match has identical winds. | Pick a random seed at match start and keep it in state (needed later for online replays). |
| 13 | `target_scoring.dart` comments, `stuck_arrow`, rig comments | Comments still say "122 cm / 0.61 m / 20 m". | Update or delete stale comments. |

**What's correct (keep):** fixed-step integration and the substep cap, plane-crossing hit detection, secant sight solver (yaw path-length error is under 0.1 mm, negligible), scoring with line-cutter, wind sign conventions (dial ↔ physics match), seeded sway phases.

---

## 3. Performance

| Issue | Where | Fix |
|---|---|---|
| `saveLayer` every frame during the bow slide | `bow_overlay.dart:576` | With the bow as an image, fade it with the image `Paint`'s colour alpha: no layer. |
| `Rect`/`Offset`/`RRect` allocations per frame | billboards (`billboard_renderer.dart:524,566`), board, crosshair (`draw_aim_controller.dart:202-230`), wind pill | Use `canvas.save(); translate(x,y); scale(s); drawImage(img, Offset.zero, paint); restore()` for billboards. For crosshair and ring: translate to the centre, then draw with **const** offsets; draw the arc in a const unit rect with `canvas.scale(r)` and `strokeWidth = 4 / r`. |
| New `Color` per trail segment per frame | `flying_arrow.dart:485` | Delete the trail, or precompute 12 colours once. |
| `HitPopupOverlay` rebuilds two `Text` widgets and allocates a `Paint()` every animation frame; `Opacity` widget = saveLayer | `hit_popup.dart:388-436` | Move to canvas (bug #6). If it stays a widget, use `FadeTransition`/`ScaleTransition`/`SlideTransition` and pass the text as `child`. |
| Wind particles + wind flag still running | `components/wind_particles.dart`, `wind_flag.dart` | **Delete both** (plan v2 dropped them). The floating **cyan dots** in the screenshots are these particles. |
| Fallback ground: ~80 lines with a `Paint()` and gradient allocated every frame | `range_background.dart:202-282` | Shaders work on CanvasKit web and on mobile. Delete the fallback, or reduce it to one solid rect. |
| `FlameGame` with no Flame components | `archery_game.dart` | Fine, but `extends FlameGame` creates an unused World and CameraComponent. `class ArcheryGame extends Game` is enough. |

---

## 4. Boilerplate to delete

- **Compatibility shims nobody calls:** `CameraRig.addAimDelta`, `currentYaw/currentPitch`, `swayYaw/swayPitch`; `ArcheryCamera.yaw/pitch`, the duplicate `focal` vs `focalLengthPx`; controller `onFullDraw`, `onFire`, `draw`; game getters `currentRoundIndex/roundScores/isRoundComplete`; `WindModel` dual-mode factory + `baseWind/baseWindMps/windMph/getWindAt`; `SightSolver.getSightPitchOffset`; `ArrowPhysics3D.windProvider` + `startPos`; `BowOverlay.onRelease()` and the unused `update` params; `TargetBoard.updateDistance` (distance is fixed).
- **Dead code:** `physics/sway_model.dart` (sway is re-implemented inside the controller; keep **one**, the model, and call it from the controller); constants `distNear`, `roundDistances`, `fullDrawPlateau`, `minDrawSpeedRatio`; `colorX` ints (use `const Color` constants).
- **Duplicate tail-quiver maths** in `ArrowPhysics3D` and `StuckArrow`: keep it in `StuckArrow` only.
- **Image loading copy-pasted 4×** (`rootBundle.load → instantiateImageCodec → getNextFrame`): one helper `Future<ui.Image> loadImage(String path)`, or Flame's `images.load()`.
- **Doc-comment noise** ("Build Plan v2 §…", "zero allocation" claims on code that allocates): keep comments that explain *why*.

Expected result: about 30% less code.

---

## 5. Riverpod + hooks architecture (the developer uses `hooks_riverpod`)

Today the HUD listens to a `ValueNotifier<int>` tick counter and reads **mutable game fields** inside `build()`. That's fragile: bug #5 comes from this. Make it one-directional:

```
Flame game ──events──▶ ArcheryMatchNotifier (immutable state) ──watch/select──▶ HUD widgets
   ▲                                                                          │
   └──────────────── commands (continueToNextSet, restart) ◀──────────────────┘
```

```dart
// lib/archery/state/archery_match_state.dart
@immutable
class ArcheryMatchState {
  final ShotPhase phase;
  final int setIndex;
  final List<ShotScore> setShots;     // shots in the current set
  final int userSets, botSets;
  final double windDisplay;
  final bool matchOver;
  // const constructor + copyWith
}

// lib/archery/state/archery_match_notifier.dart
class ArcheryMatchNotifier extends Notifier<ArcheryMatchState> {
  @override
  ArcheryMatchState build() => ArcheryMatchState.initial();
  void phaseChanged(ShotPhase p) => state = state.copyWith(phase: p);
  void shotScored(ShotScore s) => state = state.copyWith(setShots: [...state.setShots, s]);
  void windChanged(double d) => state = state.copyWith(windDisplay: d);
  void setFinished({required bool userWon, required bool tie}) { ... }
}
final archeryMatchProvider =
    NotifierProvider<ArcheryMatchNotifier, ArcheryMatchState>(ArcheryMatchNotifier.new);
```
- **Game:** takes an events interface in its constructor (`ArcheryGame(events: ref.read(archeryMatchProvider.notifier))`) and calls it **only on discrete events**: phase change, impact, wind change, set end. It never reads Flutter state. The canvas visuals (crosshair, ring, popup) stay inside Flame.
- **Screen:** `class ArcheryScreen extends HookConsumerWidget`, with `final game = useMemoized(() => ArcheryGame(events: ref.read(archeryMatchProvider.notifier)));`. `Listener` only around `GameWidget`.
- **HUD:** small widgets each watching a slice, e.g. `ref.watch(archeryMatchProvider.select((s) => s.phase))`, so a score change doesn't rebuild the hint pill.
- **Animated widgets:** `HookWidget` + `useAnimationController(duration: …)`, which removes the `StatefulWidget` + `SingleTickerProviderStateMixin` + `dispose` boilerplate.
- `flame_riverpod` is already in `pubspec.yaml`. The constructor-injection approach above is simpler and keeps the game testable without Riverpod. Either is fine; don't mix both.
- Keep the game and state in `lib/archery/`. Wrap the dev entry in `ProviderScope`.

---

## 6. Camera flow rewrite (fixes bugs #2–#4)

One pattern for every eased phase:
```dart
void _enter(ShotPhase p) {
  phase = p; phaseTime = 0;
  _fromX = eyeX; _fromY = eyeY; _fromZ = eyeZ; _fromZoom = zoom;
  events.phaseChanged(p);
}
// in update, e.g. raising (0.6 s):
final e = easeInOutCubic((phaseTime / 0.6).clamp(0, 1));
eyeZ = lerp(_fromZ, ArcheryK.camAimZ, e);
zoom = lerp(_fromZoom, aimZoom, e);
```
Flow: `atLine → raising → aiming → chase → closeup → (arrows 1–2) returning → atLine` and `closeup → (arrow 3) setEnd → [Continue] → returning → atLine`.
Cancel (finger lifted during `raising`): `_enter(returning)`, which eases from wherever the camera is.

---

## 7. Small polish

- The wind pill text is a fixed 12 px; scale it by `uiScale`.
- `'SET n • 50ft'` is hard-coded; use `ArcheryK.distanceLabel`.
- The popup says `+10 (X)`; GamePigeon just says `+10`. Show X with a small gold "X" badge instead.
- Use the `Positioned(top: MediaQuery.paddingOf(context).top + 10)` form (`paddingOf` rebuilds less than `.of(context).padding`).
- `SystemChrome.setPreferredOrientations` does nothing on web. That's fine for native later, but don't rely on it.

---

## 8. Order of work

1. **Assets:** run `tools/defringe.py` on the trees and hills; replace `grass_detail.webp` (§1.5, §1.6).
2. **Delete:** wind particles, wind flag, fallback ground, all shims and dead code (§4).
3. **Camera:** contain-FOV + `zoom`, `_enter`/from→to easing, set-end flow, aim zoom (§1.1, §1.4, §6).
4. **Aim maths:** crosshair start at the projected target, gain from face size, clamp around the target (bug #1, §1.4).
5. **Arrow renderer** (shared 3D arrow), bow as image, nocked arrow aimed at the target (§1.3).
6. **Shader:** two-scale grass, stripe AA, shooting-line AA, contact darkening (§1.5).
7. **Riverpod/hooks** HUD + max-width layout + popup on canvas (§1.2, §5, bugs #5–#7).
8. **Performance** list (§3), then test on a phone (iPhone Safari + Android Chrome) at 60 FPS.

**Acceptance check:** the same screenshot taken at 390×844 (phone), 768×1024 (tablet) and 1920×1080 (desktop) shows the same range width, the same target size while aiming, and a score bar no wider than 520 px.
