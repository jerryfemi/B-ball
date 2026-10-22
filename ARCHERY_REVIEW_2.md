# Archery Code Review — Round 2

> Follows `ARCHERY_REVIEW.md` (round 1). Most round-1 items are done well: contain-FOV, focal zoom, `_enter()` from→to easing, set-end flow, crosshair start point, shared 3D arrow renderer, canvas popup, Riverpod notifier, HUD max width, stand stroke widths, single face rasterization.
> This round covers the developer's new complaints (bow, nocked arrow, scoreboard, aim zoom) and the bugs left in the new code.

---

## 1. Aim zoom: reduce slightly
`archery_constants.dart`: `aimFaceFrac = 0.26` → **`0.235`** (about 10% less zoom). Nothing else changes; aim gain is derived from it.

Related: in the aiming view the **trees directly behind the target** fill the frame, blurry and oversized (`venue_theme.dart`: `tree_3` at x −1.8 and `tree_1` at x 2.2, z D+14/15). Push the behind-target trees out to **|x| ≥ 3.5 m**, so the target sits against the hedge and hills while aiming, like GamePigeon. Keep the side trees as they are.

---

## 2. Bow: asset fixed, placement and orientation still wrong

### 2.1 What was wrong with the image (fixed in the repo)
`bow_recurve.webp` was **518×1600, but the bow only filled the left 120 px**. The code centres the whole image on `bowBaseX`, so the visible bow landed ~0.15·W left of where it was meant to be, near the middle of the screen. The edges also had **magenta fringing** from the generator background.
**Done:** the image is now cropped to **127×1566**, with the magenta un-blended and removed. Anchor points in the new image (fractions of width/height):
| Point | (x, y) fraction |
|---|---|
| top tip | (0.50, 0.00) |
| bottom tip | (0.50, 0.99) |
| arrow shelf (just above the leather grip) | (0.66, 0.47) |
| grip centre | (0.60, 0.53) |

### 2.2 Placement (GamePigeon-style: big, on the right edge, partly off-screen)
The image is a **side profile** with the shelf on its right. From the archer's point of view the arrow must pass on the **target side** of the riser, so:
```dart
// bow_overlay.dart render()
final bowH   = screenH * 1.05 * uiScale.clamp(0.9, 1.2);   // taller than the screen: bottom limb runs off-screen
final bowW   = bowH * img.width / img.height;
final anchorX = screenW * 0.86 + slideOffsetX;               // grip sits near the right edge
final anchorY = screenH * 0.70 + slideOffsetY;
canvas.save();
canvas.translate(anchorX, anchorY);
canvas.rotate(-11 * math.pi / 180);   // top leans toward the target
canvas.scale(-scale, scale);          // MIRROR: shelf now faces the screen centre / target
// draw so the GRIP point (0.60, 0.53) sits at the origin
canvas.drawImageRect(img, srcRect,
    Rect.fromLTWH(-bowW * 0.60, -bowH * 0.53, bowW, bowH), _bowPaint); // cache both Rects in resize()
canvas.restore();
```
Compute the **shelf's screen position** with the same transform (rotate + mirror the offset `((0.66 − 0.60)·bowW, (0.47 − 0.53)·bowH)`) and keep it in `shelfSx/shelfSy` for the arrow below.

### 2.3 Nocked arrow: use the real 3D arrow, not 2D lines
The current arrow is a 70 px stub (30% of the screen distance) with oversized 2D vanes floating to the right of the bow. Replace `_renderNockedArrow` with `ArrowRenderer3D`, so it matches the flying arrow and points exactly at the target with correct perspective:
```dart
// target centre on screen (line camera)
camera.project(0, ArcheryK.targetCenterY, ArcheryK.distanceM);
final tSx = camera.sx, tSy = camera.sy;

// nock point on screen: on the line target→shelf, 35% beyond the shelf (lower right, near the camera)
const k = 1.35;
final nSx = tSx + (shelfSx - tSx) * k;
final nSy = tSy + (shelfSy - tSy) * k;

// lift that screen point to 3D at 0.45 m in front of the camera
const d = 0.45;
final nx = camera.eyeX + (nSx - camera.opticalCenterX) * d / camera.focal;
final ny = camera.eyeY - (nSy - camera.opticalCenterY) * d / camera.focal;
final nz = camera.eyeZ + d;

// direction toward the target centre
var fx = 0 - nx, fy = ArcheryK.targetCenterY - ny, fz = ArcheryK.distanceM - nz;
final inv = 1 / math.sqrt(fx*fx + fy*fy + fz*fz); fx *= inv; fy *= inv; fz *= inv;

ArrowRenderer3D.render(
  canvas: canvas, camera: camera,
  tipX: nx + fx * ArcheryK.arrowLength,
  tipY: ny + fy * ArcheryK.arrowLength,
  tipZ: nz + fz * ArcheryK.arrowLength,
  forwardX: fx, forwardY: fy, forwardZ: fz,
);
```
With these numbers the arrowhead lands about a third of the way from the shelf to the target, and the vanes sit near the bottom-right corner, large and chunky like GamePigeon. Because it's built from the bow's screen points, it **slides out with the bow** automatically.
- Draw order: bow → arrow, so the shaft lies on top of the shelf.
- Fade: `ArrowRenderer3D` needs an `opacity` parameter (multiply the alpha of its cached paints) so it fades with the bow.

### 2.4 Better asset later (recommended)
A side-profile bow can't show the string believably (a straight line tip-to-tip would cut through the riser). For the final look, generate:
> "Wooden recurve bow seen from the archer's point of view, three-quarter rear view, bow held upright, string toward the viewer, arrow rest visible, painted stylized game art, soft daylight from upper left, on a solid #FF00FF background, 1200×2400"

Then `python tools/defringe.py in.webp out.webp --bg 255,0,255`.

---

## 3. Scoreboard redesign
Problems now: it's a full-width bar with the score left of centre, three tiny 8 px set dots, the arrow bubbles in an odd spot, **no opponent score**, "50ft" crammed into the title, and empty space everywhere.

**Target layout** (GamePigeon structure, obsidian styling), compact and centred, **intrinsic width, max 360 px**:
```
   ╭────╮ ┌──────────────────┐ ╭────╮
   │ YOU│ │      SET 1        │ │ BOT│
   ╰────╯ │   18  –  26       │ ╰────╯
    (●2)  │   ◉10 ◉8 ○        │  (●1)
          └──────────────────┘
```
- **Avatars** (44 px circles) sit *outside* the centre box and overlap its left and right edges by 8 px. Use DunkVerse's avatar images (`assets/avatars/dunk_heads (n).webp`) instead of "YOU"/"BOT" text, with a small 9 px label under each.
- **Set points:** one **gold coin badge** (18 px, `#F59E0B`, dark number) under each avatar showing the count. Hide it at 0. Replace the 3 tiny dots.
- **Centre box:** `#0F172A` at 92%, radius 16, padding 14×8.
  - `SET 1`: 10 px, w800, letter-spacing 1.2, `#94A3B8`.
  - Score `18 – 26`: 26 px, w900, `FontFeature.tabularFigures()` so digits don't jitter while counting up. Show the leader's number in `#00FFCC` and the other in white.
  - **Arrow pips** under the score: 3 × 16 px circles (ring number in the ring colour; the next arrow pulses cyan; future arrows dim).
- **Distance** moves out of the scoreboard to a red **"50ft" ground tag** at the shooting line (bottom-left, world-anchored), as in GamePigeon.
- Hide with fade + 8 px upward slide (`AnimatedSlide` + `AnimatedOpacity`, 220 ms).

```dart
class ArcheryScoreboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(archeryMatchProvider.select((s) => (s.setIndex, s.currentSetScore, s.botSetScore, s.userSets, s.botSets)));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Avatar(image: userAvatar, label: 'YOU', sets: s.$4, accent: const Color(0xFF00FFCC)),
        Transform.translate(offset: const Offset(-8, 0), child: _CenterBox(...)), // overlap
        Transform.translate(offset: const Offset(-16, 0), child: _Avatar(image: botAvatar, label: 'BOT', sets: s.$5, accent: const Color(0xFF8B5CF6))),
      ]),
    );
  }
}
```
(Records in `select` compare by value, so it only rebuilds when one of those five fields changes.)

### 3.1 The bot needs a real score
The HUD can't show `you – bot` because the bot is a constant `26` hidden in `ArcheryGame`. Give it shots:
- In the notifier, `botShots: List<int>` is generated per set from the match seed: `ring = 10 − floor(|N(0, σ)| / 0.04)`, with σ by difficulty (easy 0.09 m, medium 0.06 m, hard 0.04 m), clamped 0–10.
- Reveal one bot arrow after each of yours (count-up on the bot score), so the race is visible.
- The set winner comes from the real totals.

---

## 4. Bugs in the new code

| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | `arrow_renderer.dart:152` | Vane facing is **inverted**. `v = nock − eye` points *away* from the camera, so `dot > 0` means the vane points away, yet those vanes are drawn **last** (on top of the shaft) and **brighter**. | Use `vane.dot = −(d·v)/|v|` (or swap the two draw loops and the shading lerp). |
| 2 | `archery_game.dart:182-203` + `archery_match_notifier.dart:51` | **Two sources of truth for set points**: the notifier increments `userSets/botSets` in `setCompleted`, and the game increments its own `userSetPoints/opponentSetPoints` again in `advanceNextSet`. Match-over is computed twice. They agree only by luck. | The **notifier owns all scoring and set rules** (pure Dart, unit-testable). The game only reports `shotScored` and asks `notifier.isLastArrowOfSet`. Delete `setScores`, `userSetPoints`, `opponentSetPoints`, `isMatchComplete`, `currentSetScore`, `totalScore`, `totalXCount` from the game. |
| 3 | notifier `build()` vs `ArcheryGame()` | **Two different match seeds** (each calls `Random()`), so `state.matchSeed` is not the seed the winds come from. That breaks replays later. | Create the seed once in the notifier; the game reads it (`events.matchSeed`) or receives it in the constructor. |
| 4 | `camera_rig.dart:267-278` | Camera **shake is computed but never applied**: nothing reads `shakeOffsetX/Y`. | In `ArcheryGame.render`: `canvas.save(); canvas.translate(rig.shakeOffsetX, rig.shakeOffsetY);` around the world layers (background → arrows), `restore()` before the bow, crosshair and popup. Or delete the shake. |
| 5 | `draw_aim_controller.dart:568` | Steady ring min radius `24·uiScale` sits **inside the target face** while aiming (≈95 px radius), so red rings draw over red/blue rings (see screenshot 2). | `minRadius = faceRadiusPxAtAim * 1.18`, so the ring settles just around the face like GamePigeon. Draw the timer arc 5 px outside it. |
| 6 | `archery_game.dart` | Leftovers: `hudNotifier` + `_notifyHud()` (no listeners now), `lastShotScore`, `lastHitScreenPos` (allocates `Offset` on impact), `clearLastHitPopup`, `flyingArrow.resetTrail()` (empty), `controller.draw` ("legacy"), `ArcheryK.bossWidth/bossHeight` aliases, `ui/hit_popup.dart` (replaced by the canvas popup). | Delete them all. |
| 7 | `range_background.dart:194+` | Fallback ground still present (round-1 §3). | Delete it. |
| 8 | `archery_ground.frag:56` | `stripe < 0.5 ? 1.0 : 0.0` is a hard branch that brings back the stripe-edge shimmer the AA just removed. | `col *= mix(1.06, 1.0, stripe);` |
| 9 | `arrow_renderer.dart:280` | `Color.lerp` allocates a `Color` per vane per frame. | Precompute 8 shades once; index by `(t * 7).round()`. |
| 10 | `target_board.dart` | The rear strut projects as a **third front leg** (looks like an easel; screenshot 2). | Draw the rear strut first, darker (`#3A2614`) and 70% width, or drop it. GamePigeon shows 2 legs. |

---

## 5. Assets still to fix
- **`hills.webp`:** still has its **semi-transparent painted sky** over the top third, which hides `sky_mountains.webp` (no mountains visible in the screenshots). An automatic cut-out of that sky leaves streaks, so **regenerate** the hills strip on solid magenta and run `defringe.py --bg 255,0,255`.
- **Trees:** done (round 1).
- **Bow:** cropped and cleaned (§2.1). A rear 3/4 asset is recommended later (§2.4).

---

## 6. Order of work
1. `aimFaceFrac = 0.235` and move the behind-target trees (§1).
2. Bow placement + mirrored image + 3D nocked arrow with opacity (§2.2–2.3).
3. Arrow vane facing fix (bug #1) and steady ring radius (bug #5).
4. Scoring ownership in the notifier + single seed + bot shots (bugs #2–#3, §3.1).
5. Scoreboard redesign + "50ft" ground tag (§3).
6. Shake on or off (bug #4), cleanup (bugs #6–#10).

**Check:** at the line on a 390×844 screen, the bow's grip sits at the right edge with the bottom limb off-screen, the arrowhead points at the target, and the scoreboard is a compact centred block ≤ 360 px wide showing both scores.
