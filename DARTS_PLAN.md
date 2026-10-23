# DARTS_PLAN.md — GameVerse Darts (`/darts`)

Third game in GameVerse after Hoops (`/hoops`) and Archery (`/archery`).
Reference feel: GamePigeon Darts 301 (front-on board filling the width, dart
resting at the bottom, flick to throw, score badges in the bottom corners,
segment flash + number pop on every hit, BUST resets the turn).

Archery (`lib/archery/`) is the template. Copy its *patterns*, not its code:
darts has no wind, no camera dolly and no distance per set.

---

## 0. Kickoff prompt for Antigravity (paste this first)

> You are building Darts in the GameVerse Flutter Web app at
> `C:\Users\jerem\StudioProjects\b_ball`. Read `DARTS_PLAN.md` (this file)
> fully, then read these archery files as the reference for structure and
> style before writing anything: `lib/archery/archery_constants.dart`,
> `lib/archery/physics/sway_model.dart`, `lib/archery/physics/target_scoring.dart`,
> `lib/archery/state/archery_rules.dart`, `lib/archery/state/archery_match_state.dart`,
> `lib/archery/state/archery_match_notifier.dart`, `lib/archery/audio/archery_audio.dart`,
> `lib/archery/online/archery_live_event.dart`, `lib/archery/online/archery_online_controller.dart`,
> `lib/archery/archery_game.dart`, `lib/archery/archery_game_screen.dart`,
> `lib/archery/ui/archery_tour.dart`.
> Do **one step at a time** from section 4. After each step: run
> `flutter analyze` and `flutter test`, report what you changed and the
> results, and stop. Follow every rule in section 3. Never run
> `firebase deploy`. Do not edit anything in `lib/archery/` or
> `lib/game/basketball_game.dart` unless the step says so.

---

## 1. Gameplay (decided)

### 1.1 Mode: **301, straight in, straight out, equal turns**
- Each player starts at **301**. A turn is **3 darts**. Points scored come off your total.
- **Straight out** (no double needed to finish) — this is what GamePigeon does and it keeps casual games short. 501 takes ~2× as long per match, which is too long for async play.
- **Bust**: if a dart would take you **below 0**, the turn ends immediately, scores **0**, and your total goes back to what it was at the start of the turn.
- **Checkout**: landing on exactly **0** ends your turn immediately.
- **Equal turns** (fairness fix GamePigeon lacks): a *round* is P1's turn then P2's turn. If P1 checks out, P2 still gets that round's turn. At the end of a round:
  - one player at 0 → they win;
  - both at 0 → fewer darts used in their final turn wins; same → draw.
- **Round cap**: 20 rounds. After round 20, the lower remaining total wins; equal → draw.
- Turn order is **fixed** for the whole match: P1 (host) throws first every round. A rematch swaps who is P1. (Archery alternates the leader per set — darts must **not**; see step 16.)

### 1.2 Throw gesture: **hold-aim, flick-up to throw**
1. **Touch anywhere** in the lower 60% of the screen → the dart lifts and an **aim reticle** appears on the board (starts at the board centre, or where the last dart was aimed).
2. **Drag** moves the reticle relative to the finger (thumb-roll like archery: `aimGain` ≈ 1.6 board-mm per screen px, scaled by board size), so the finger never covers the board.
3. **Flick up and release** to throw. Throw = release with upward speed ≥ `minFlick`. Lift without a flick → dart drops back, nothing thrown (no penalty).
4. The flick decides two errors on top of the reticle position:
   - **Power** (flick speed, measured in screen-heights/second so every device feels the same): inside the **sweet band** (0.8×–1.3× ideal) there is no error. Too soft → the dart lands **low**; too hard → **high**. Error grows linearly outside the band (target: 25% outside the band ≈ 30 mm off).
   - **Angle** (flick direction vs straight up): within ±6° no error; beyond that, lateral error ≈ 2.5 mm per extra degree.
5. These errors come out of the physics, not a random roll: the solver aims the launch at the reticle at ideal speed; the flick changes the real launch speed and yaw; the 240 Hz integration decides where it lands.

### 1.3 Wobble: **deterministic hand sway on the reticle**
Re-use the archery `SwayModel` shape (settle → steady → fatigue), in board millimetres:
- 0–0.6 s after touch: settling wobble, amplitude ~18 mm.
- 0.6–3.0 s: steady window, ~4 mm.
- 3.0–5.0 s: fatigue ramps up to ~20 mm, then stays (no auto-throw).
- Seeded by `(matchSeed, round, dartIndex)` so it is reproducible in tests.
- Draw a thin steady ring around the reticle that shrinks into the steady window (same idea as archery's ring), in `#38BDF8`.

### 1.4 Solo: **you vs one bot, alternating turns**
- You throw your 3 darts, then the bot throws its 3 on screen with real flights (~0.7 s between darts), then back to you. Same 301 / bust / equal-turn rules.
- **Bot aim** (pure Dart, `state/darts_bot.dart`):
  - remaining > 60 → aim **T20**;
  - otherwise pick the target that **finishes exactly** with the best hit chance, in this order: fat single (r ≈ 135 mm), outer bull (25), double, treble, bull (50);
  - no finish possible this dart → aim the **fat single** that leaves ≤ 40 (prefer ≤ 20); never aim a target whose value is greater than remaining.
- **Bot accuracy**: hit = aim + 2-D Gaussian scatter, σ = **20 mm** (≈ 50 points a turn, finishes in ~8–11 rounds). Seeded per `(seed, round, dartIndex)`, exactly like `ArcheryMatchNotifier.botShot`.
- The bot's dart is flown with the **inverse solver** (launch that lands exactly on its hit point), so it looks like a real throw.

### 1.5 Screen layout (portrait, per the reference video)
- Board centred horizontally, diameter = 92% of the reference width (`refW = min(width, height * 0.62)` like archery), centre at ~40% screen height.
- Resting dart bottom-centre, pointing up.
- Bottom-left: your avatar + **remaining** badge. Bottom-right: opponent's. The thrower's badge glows (`#38BDF8` you, `#F59E0B` opponent) and shows the running turn score (`+45`) under it.
- Top-left: 3 dart icons (darts left this turn). Top-right: menu button → pause menu (Resume, How to play, Play a friend, Settings, Lobby).
- On every hit: the hit area flashes (`#38BDF8` at ~35% alpha, 450 ms fade) and a score pop rises from the dart (`T20`, `D16`, `25`, `BULL`, `MISS`). Bust: red `#EF4444` **BUST** banner and the badge counts back up.
- Backdrop: dark obsidian wall (`#0A0E1A` → `#0F172A` gradient) with a soft warm amber spotlight on the board and a black board surround. Not wood.

---

## 2. File structure (mirrors `lib/archery/`)

```
lib/darts/
  darts_constants.dart          DartsK: every tunable (board mm, physics, flick, wobble, layout)
  darts_game.dart               FlameGame: input, physics, drawing; implements DartsOnlineGame
  darts_game_screen.dart        HookConsumerWidget (replaces today's teaser) + DartsChallenge
  audio/
    darts_audio.dart            DartsAudio: init/leave/unlock + play* wrappers on AudioEngine
  components/
    dartboard.dart              board recorded once into a ui.Picture; hit-area flash
    board_backdrop.dart         wall + spotlight, recorded once into a ui.Picture
    dart_sprites.dart           loads darts_atlas.png + .json once; cached src Rects per frame
    dart_renderer.dart          draws one atlas frame at (x, y, scale, angle) with zero allocations
    resting_dart.dart           the dart in hand at the bottom of the screen (aim phase)
    flying_dart.dart            the dart in flight (spin frames, perspective-scaled)
    stuck_dart.dart             a landed dart (max 3 in the board at a time) + impact wobble
    aim_reticle.dart            reticle + steady ring
    hit_popup_canvas.dart       score pop text + BUST banner
  input/
    flick_controller.dart       touch → aim, pointer-sample ring buffer → flick speed/angle
  physics/
    dart_physics.dart           3-D ballistic dart, fixed 240 Hz step, no allocations
    flick_solver.dart           aim point → launch velocity; flick → speed/yaw change; inverse for bot/remote
    wobble_model.dart           SwayModel-style deterministic wobble (mm)
    dart_scoring.dart           hit (x,y mm) → DartHit {segment, multiplier, points, label}
  scene/
    board_projection.dart       board mm ↔ screen px, depth scale for the flying dart
  state/
    darts_rules.dart            pure Dart: 301, bust, checkout, round end, winner, seed
    darts_match_state.dart      immutable state (like ArcheryMatchState)
    darts_match_notifier.dart   Riverpod Notifier owning all scoring (implements DartsGameEvents)
    darts_players.dart          names/avatars provider (copy of archery_players pattern)
    darts_bot.dart              bot target choice + seeded scatter
  online/
    darts_live_event.dart       'aim' ping + 'dart' landed event (hit mm only)
    darts_online_controller.dart  turn sync, per-dart shot clock, leave/rejoin clock restore
  ui/
    darts_hud.dart              badges, dart icons, menu button, live pill, shot clock
    darts_pause_menu.dart       CleanDialog-based, same items as archery
    darts_turn_banner.dart      "YOUR TURN" / "BOT'S TURN" / "LAST CHANCE: 32 TO TIE"
    darts_tour.dart             how-to-play, once per device, pref key 'darts_tour_seen_v1'
lib/main_darts.dart             standalone dev harness (copy of main_archery.dart)
test/darts/
  scoring_test.dart  rules_test.dart  bot_test.dart  flick_solver_test.dart
  physics_test.dart  wobble_test.dart  match_notifier_test.dart  live_event_test.dart
assets/darts/                   sfx_*.wav + ambience_pub.mp3 (supplied by Oyindamola, see step 13)
assets/darts/sprites/           darts_atlas.png + darts_atlas.json (rendered by Oyindamola from a CC-BY Sketchfab model, see step 10)
```

Generic archery widgets (`ui/pulse.dart`, `ui/claim_button.dart`, `ui/live_pill.dart`) are **imported from `lib/archery/ui/`**, not copied. Moving them to `lib/game/ui/common/` is a later refactor, not part of this build.

Shared files touched (only in the steps that name them): `lib/routes/match_route_screen.dart`, `lib/lobby/game_catalog.dart`, `lib/game/ui/match/match_setup_dialog.dart`, `lib/models/cloud_match.dart`, `lib/services/firestore_match_service.dart`, `lib/game/audio/audio_engine.dart`, `firestore.rules`, `pubspec.yaml` (assets).

---

## 3. Guardrails (Antigravity must follow all of these)

**Performance**
1. No `Paint()`, `Path()`, `Rect.*`, `Offset(...)` in hot loops, `TextPainter`, `List`, `Vector2/3` or closures created inside any `render()` or `update()`. Cache them as `final` fields or `static final`. Reuse `Vector3`s with `setValues`.
2. The board and backdrop are **recorded once** into a `ui.Picture` on load and on resize, then drawn with `canvas.drawPicture`. Never rebuild the 82 board areas or 20 number labels per frame.
3. Number labels: lay out the 20 `TextPainter`s once at record time, never in `render()`.
4. Physics: fixed 240 Hz accumulator, frame `dt` clamped to 1/20 s, max 8 substeps (copy `ArcheryK.fixedDt` / `maxSubstepsPerFrame`).
5. Read `devicePixelRatio` once (on load/resize) and cache it. Do not touch the 1.5 DPR cap in `web/index.html`.
6. Pointer samples go into a fixed-size preallocated ring buffer (e.g. 8 slots of x, y, t as `Float64List`).

**Architecture**
7. All match rules live in pure Dart (`state/darts_rules.dart`, `state/darts_bot.dart`, `physics/dart_scoring.dart`): no Flutter, no Flame imports there. The Flame game only reports darts; the notifier decides scores.
8. Riverpod `Notifier` + `hooks_riverpod`/`flutter_hooks` for screen state, same as archery. No `setState` games in the screen beyond what archery already does.
9. Every random thing is seeded (`DartsRules.seedFromMatchId`, bot scatter, wobble). Never `Random()` without a seed outside `_newSeed()`.
10. Scores sent online are **always recomputed from hit position** on the receiver and in the Firestore transaction. Never trust a sent `points` field.

**Audio**
11. Only the shared `AudioEngine`. Never add `audioplayers` or `just_audio`. Music via `AudioEngine.claimSoundtrack(owner, track:, ambience:)` on open and `releaseSoundtrack(owner)` on close. SFX preloaded into memory through a `loadDartsSfx()` that mirrors `loadArcherySfx()` exactly (including the "wanted" flag re-checked when SFX is switched back on).
12. Call `DartsAudio.unlock()` on every pointer down and up.

**Multiplayer**
13. Never delete a match. Completed matches keep `status = completed`. No `deleteMatch()` anywhere in darts.
14. Chat stays in `/matches/{id}/chat`. Darts live events go in `/matches/{id}/live_shots` with `game: 'darts'`.
15. Darts live event doc ids start with `t_` (throw) and `p_` (aim ping). **Not** `a_`/`d_` — archery already uses those prefixes.

**UI**
16. Palette only: surfaces `#0A0E1A`, `#0F172A`, `#1E2638`; accents `#38BDF8`, `#00FFCC`, `#F59E0B`, `#EF4444`; text `#FFFFFF` / `#94A3B8`. The current teaser's purple `#A855F7` goes away.
17. No `SnackBar`/`ScaffoldMessenger`. Errors show inside the card (`AnimatedSwitcher`) with an icon, one line and a **RETRY** button (see `InlineErrorPanel`).
18. Dialogs use `lib/game/ui/common/clean_ui.dart` (`CleanDialog`, `CleanSegmented`, `CleanRow`, `CleanButton`).
19. Haptics: `lightImpact` on taps, `mediumImpact` on a treble/bull, nothing else.

**Process**
20. One step per turn. `flutter analyze` clean and `flutter test` green before reporting.
21. Never run `firebase deploy`. When rules change, print the command for Oyindamola instead.
22. Don't touch `lib/archery/**` or `lib/game/basketball_game.dart` except where a step says so.

---

## 4. Build steps

Each step is small and ends with a check you can run. Steps 1–6 are pure Dart and fully unit-tested before any drawing happens.

### Phase A — Rules and maths (no UI)

**Step 1 — Constants.** Create `darts_constants.dart` with `abstract final class DartsK`:
- Board (mm): `innerBullR 6.35`, `outerBullR 15.9`, `trebleInR 99`, `trebleOutR 107`, `doubleInR 162`, `doubleOutR 170`, `boardR 225.5`, `segmentOrder = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5]` (clockwise from top, 20 centred on 12 o'clock, 18° each).
- Physics: `throwDistanceM 2.37`, `gravity 9.81`, `idealSpeed 7.0` m/s, `fixedDt 1/240`, `maxSubstepsPerFrame 8`, `dtClamp 0.05`.
- Flick: `minFlick`, `idealFlick`, `sweetLow 0.8`, `sweetHigh 1.3`, `powerErrorPerUnit`, `angleSweetDeg 6`, `angleErrorMmPerDeg 2.5`, `aimGain`.
- Wobble: `wobbleSettle 18`, `wobbleSettleTau 0.6`, `wobbleBase 4`, `wobbleFatigue 20`, `fatigueStart 3.0`, `fatigueFull 5.0` (mm / s).
- Layout: `refAspect 0.62`, `boardFrac 0.92`, `boardCenterYFrac 0.40`.
✅ Check: `flutter analyze` clean.

**Step 2 — Scoring.** `physics/dart_scoring.dart`: `DartHit` (immutable: `x`, `y`, `segment` 0/1–20/25, `multiplier` 0–3, `points`, `label` like `T20`/`D16`/`S5`/`25`/`BULL`/`MISS`, `isTreble`, `isBull`) and `DartScoring.score(x, y)`. Angle measured clockwise from 12 o'clock, offset by +9° so 20 spans −9°..+9°. Boundaries: `r <= innerBullR` → 50, `<= outerBullR` → 25, treble/double bands inclusive of inner edge, `> doubleOutR` → MISS (0).
✅ Check: `test/darts/scoring_test.dart` — centre = BULL 50; (0, 103) up = T20 60; (0, −166) down = D3 6; (103, 0) right = T6 18; a point at 9.1° right of top = 1, not 20; r = 171 = MISS; every segment centre at r = 135 scores its single.

**Step 3 — Rules.** `state/darts_rules.dart` (pure Dart), mirroring `ArcheryRules`:
- `startScore 301`, `dartsPerTurn 3`, `maxRounds 20`, `shotClockSeconds 20`, `onlineTurnSeconds 90`.
- `applyDart(remainingAtTurnStart, turnSoFar, points)` → `{newTurnTotal, bust, checkout, turnOver}`.
- `remaining(List<int> turnScores)` = 301 − sum.
- `isMatchOver(p1Turns, p2Turns, p1LastDarts, p2LastDarts)` — only evaluated after a full round (both lists same length) or at round 20.
- `winner(...)` → +1 / −1 / 0 with the equal-turns and darts-used tiebreak from §1.1.
- `seedFromMatchId` — copy archery's.
✅ Check: `rules_test.dart` — 20 left + T20 → bust, turn = 0, turn over; 40 left + D20 → checkout; 2 left + S1 + S1 → checkout on dart 2; P1 checks out round 6, P2 doesn't → P1 wins only after P2's round-6 turn; both check out round 6, P1 with 2 darts and P2 with 3 → P1; round 20 cap → lower remaining wins.

**Step 4 — Wobble.** `physics/wobble_model.dart`: same shape as `SwayModel` (two sines per axis, seeded phases), output `dx`, `dy` in mm. Seed from `(matchSeed, round, dartIndex)`.
✅ Check: `wobble_test.dart` — amplitude at 0.1 s > at 1.5 s; at 4.8 s > at 1.5 s; same seed → identical outputs; zero allocations is reviewed by eye (no `new` in `update`).

**Step 5 — Physics + solver.** `physics/dart_physics.dart`: position/velocity `Vector3` (z = distance to board), gravity only (no drag needed), fixed-step integrate until z ≤ 0, report hit (x, y) in board mm. `physics/flick_solver.dart`:
- `launchFor(aimX, aimY, speed)` → launch velocity that lands on the aim point at that speed (closed-form flat-ground ballistic, low arc).
- `applyFlick(launch, flickPower, flickAngleDeg)` → modified launch: outside the sweet band, scale speed; outside ±6°, rotate yaw.
✅ Check: `flick_solver_test.dart` + `physics_test.dart` — ideal flick lands within 1 mm of aim; power 0.8 and 1.3 land within 1 mm; power 0.6 lands lower than aim by 20–45 mm; power 1.6 lands higher; 6° off lands within 1 mm, 16° off lands 20–30 mm sideways on that side; result identical across 30, 60 and 120 fps frame splits.

**Step 6 — Bot.** `state/darts_bot.dart`: `DartsBot.aimFor(remaining)` → aim point (mm) + intended target label; `DartsBot.dart(seed, round, dartIndex, remaining)` → `DartHit` via Box–Muller σ = 20 mm (copy archery's `botShot` hashing).
✅ Check: `bot_test.dart` — `aimFor(301)` is T20; `aimFor(16)` is a 16 (single or double), never a target worth more than remaining; same seed → same darts; simulate 1,000 solo bot games: median finish 8–11 rounds, never more than 20.

### Phase B — State

**Step 7 — Match state + notifier.** `darts_match_state.dart`, `darts_players.dart`, `darts_match_notifier.dart` copying the archery shapes:
- State: `round`, `thrower` (you/opponent), `turnDarts` (current turn's `DartHit`s), `yourTurns` / `theirTurns` (turn scores), `yourLastDarts` / `theirLastDarts`, `bustFlash` id, `matchOver`, `winner`, `matchSeed`, plus the online fields from `ArcheryMatchState` (`online`, `liveStatus`, `joinCode`, `bannerId`, `forfeitWinner`).
- `DartsGameEvents` interface: `matchSeed`, `round`, `dartIndex`, `isMyTurn`, `dartLanded(DartHit) → DartResult {bust, checkout, turnOver}`, `botNextDart() → DartHit?`, `nextTurn()`, `restartMatch()`.
✅ Check: `match_notifier_test.dart` with a `ProviderContainer` — three darts T20/T20/T20 → you 121 remaining, turn over, thrower = opponent; bust restores the turn-start total; checkout in round N waits for the bot's round-N turn before `matchOver`.

### Phase C — On screen (solo, dev harness)

**Step 8 — Harness + empty game.** `lib/main_darts.dart` (copy `main_archery.dart`), `darts_game.dart` (empty `FlameGame` with the clamped fixed-step loop), `scene/board_projection.dart` (board mm ↔ screen px from §1.5, recomputed only in `onGameResize`).
✅ Check: `flutter run -d chrome -t lib/main_darts.dart` shows an obsidian screen; resizing does not crash.

**Step 9 — Board + backdrop.** `components/board_backdrop.dart` and `components/dartboard.dart`: record both into `ui.Picture` in `onLoad`/`onGameResize`; render = `drawPicture`. Standard colours: black/cream singles, red/green alternating doubles & trebles, green outer bull, red bull, thin silver wires, white numbers on the black surround. Add `flashArea(DartHit)` that draws the precomputed path for that area (paths for all 82 areas built at record time) with a fading `#38BDF8` alpha.
✅ Check: board looks right against a real board (20 at top, 3 at bottom, 6 at right, 11 at left); Chrome DevTools Performance shows no per-frame Picture recording; 60 fps on a mid phone.

**Step 10 — Dart rendering (pre-rendered 3D sprites).** The dart is a real 3D model ("GAME READY RED DART ASSET" by oxxycodone, Sketchfab, CC-BY 4.0) rendered ahead of time into one sprite sheet. Do **not** draw the dart with vector paths and do **not** add any 3D/glTF package.
- Assets (supplied by Oyindamola, already rendered; the chosen sheet has the dart upright, tip up toward the board, flights at the bottom, as in GamePigeon): `assets/darts/sprites/darts_atlas.png` and `darts_atlas.json`. Register the folder in `pubspec.yaml`. The JSON gives `cellWidth`, `cellHeight`, `spinFrames`, `stuckFrames` and a `frames` map keyed `p1_rest`, `p1_spin_0..N`, `p1_stuck_0..M`, then the same for `p2`, each `{x, y, w, h}` in sheet pixels. Row 0 = player 1 (you), row 1 = player 2 (opponent/bot).
- `dart_sprites.dart`: in `onLoad`, load the image once (`images.load`) and parse the JSON once; build every source `Rect` **once** into fixed lists (`rest[2]`, `spin[2][N]`, `stuck[2][M]`). Nothing else ever touches the JSON.
- `dart_renderer.dart`: `static void draw(Canvas c, ui.Image sheet, Rect src, double cx, double cy, double scale, double angle, Paint paint)`. Implementation: `c.save(); c.translate(cx, cy); c.rotate(angle); c.scale(scale); c.drawImageRect(sheet, src, dstAtOrigin, paint); c.restore();` where `dstAtOrigin` is a cached `Rect` per frame size, centred on the dart's **tip** (anchor computed once from the cell). One shared `static final Paint` with `filterQuality = FilterQuality.medium`. No `Sprite.render`, no new `Vector2`/`Rect`/`Paint` per frame.
- `resting_dart.dart` (aim phase): `p?_rest` frame at bottom-centre, scale so the dart is ~38 % of screen height. It follows the reticle horizontally a little (±12 % of width) and leans toward it (±6°), and adds the wobble offset so the hand visibly shakes with fatigue. During the flick it pulls back ~4 % for 80 ms before release.
- `flying_dart.dart`: each frame, `BoardProjection` maps the physics position (x, y, z mm) to a screen point and `depthScale = f / (f + z)`; draw scale = `restScale * depthScale` (about 1.0 at release, ~0.15 at the board). Spin frame index = `(flightTime * 18 * spinFrames).floor() % spinFrames` (≈ 4.5 turns/s; the frames loop because the four flights repeat every 90°). Tilt the nose down as the dart falls: `angle = atan2(vy, vz) * 0.35`. Draw a soft shadow on the board under the target point: one pre-blurred ellipse `ui.Image` made in `onLoad` (never a per-frame `MaskFilter`), growing darker and smaller as `z → 0`.
- `stuck_dart.dart`: on landing, switch to a `p?_stuck_k` frame picked from where it hit, which matches real perspective (the tail is nearer the thrower, so it splays away from the board centre): `x < -60 mm` → `stuck_0` (tip leans right, toward centre), `x > 60 mm` → `stuck_2` (tip leans left), otherwise `stuck_1` (straight). It depends only on the hit position, so both online players see the same pose, drawn at the board scale with its tip on the hit point. Impact wobble: rotate by `3° * e^(−t/0.12) * sin(t * 60)` for 0.35 s. Keep max 3 per turn; at turn end fade them out over 200 ms (the "pull").
- Draw order (component priorities, fixed): backdrop 0 → board 1 → area flash 2 → board shadows 3 → stuck darts 4 → flying dart 5 → resting dart 6 → reticle 7 → popups 8.
- Credit: add "Dart model by oxxycodone (Sketchfab), CC-BY 4.0" to the darts tour's last page (and the lobby footer credits if one exists). The licence requires it.
✅ Check: a debug key throws a dart at the bull with the ideal launch; it leaves the hand at full size, spins smoothly while shrinking, casts a shadow that tightens as it arrives, and sticks in the bull with a short wobble. Player 2/bot darts use row 1 colours. DevTools Performance: no allocations growing per frame, 60 fps on a mid phone.

**Step 11 — Input.** `input/flick_controller.dart` + `components/aim_reticle.dart`: §1.2 touch/drag/flick, wobble applied to the reticle, steady ring. On flick: build launch via `flick_solver`, fly, on landing score with `DartScoring`, call `events.dartLanded`, show flash + pop (`hit_popup_canvas.dart`), handle bust/checkout banners.
✅ Check: on a phone, a gentle straight flick from a steady reticle hits where aimed; a weak flick drops low; a sideways flick drifts; lifting without a flick throws nothing.

**Step 12 — Bot turns + turn flow.** After your 3rd dart (or bust/checkout): 0.8 s pause, darts pulled out (fade), `darts_turn_banner.dart`, bot throws 3 darts via `DartsBot` + inverse solver with 0.7 s gaps, then back to you. Match end → result card with REMATCH (solo) and PLAY A FRIEND.
✅ Check: full solo game to the end; equal-turns rule visible ("LAST CHANCE" banner when bot can still tie).

**Step 13 — Audio.** Oyindamola supplies (small, 44.1 kHz mono WAV like archery): `assets/darts/sfx_throw.wav` (whoosh), `sfx_hit.wav` (sisal thunk), `sfx_bull.wav` (thunk + short bright ding), `sfx_miss.wav` (wall thud), `sfx_bust.wav` (low buzz), `sfx_pull.wav` (darts pulled out); `assets/darts/ambience_pub.mp3` (quiet room murmur loop, mono 64 kbps); `assets/music/short/darts_<name>.mp3` (60 s loop, 128 kbps). Antigravity must not generate or download audio.
In `audio_engine.dart` add `Sfx.dartThrow…` entries, `_dartsSfxAssets`, `_dartsSfxWanted/_dartsSfxLoaded`, `loadDartsSfx()`, and the `playDart*` methods — mirror every archery touch point (init path, SFX-on toggle, dispose/reset). `audio/darts_audio.dart` mirrors `ArcheryAudio`. Register assets in `pubspec.yaml`.
✅ Check: sounds fire with no lag on iPhone Safari after the first tap; music stops when you go back to the lobby and basketball's music comes back on `/hoops`; muting SFX then unmuting still plays darts SFX.

**Step 14 — HUD, pause, tour.** `darts_hud.dart` (§1.5 layout), `darts_pause_menu.dart` (copy archery pause items), `darts_tour.dart` (4 cards: HOLD TO AIM, FLICK TO THROW, 301 TO ZERO — bust explained, PLAY A FRIEND; pref key `darts_tour_seen_v1`; solo only).
✅ Check: tour shows once per device; pause freezes the game; no SnackBars anywhere (`grep -rn SnackBar lib/darts` is empty).

**Step 15 — Screen + route.** Replace the teaser in `darts_game_screen.dart` with a `HookConsumerWidget` like `ArcheryGameScreen` (optional `CloudMatch? match`, solo when null, players provider sync, `DartsAudio.init/leave`, `DartsChallenge.start/rematch`). In `match_route_screen.dart` pass the match: `DartsGameScreen(match: match)`.
✅ Check: `/darts` opens solo; back returns to `/`; `flutter build web --release` builds.

### Phase D — Online

**Step 16 — Service + live events.** `online/darts_live_event.dart`: kinds `aim` (ping, id `p_{uid}_{round}_{dart}_{ms}`) and `dart` (id `t_{uid}_{round}_{dart}`, fields `hitX`, `hitY` mm, `thrown` bool for shot-clock timeouts). Score always recomputed via `DartScoring`. In `firestore_match_service.dart` add `extension DartsMatchService` with `broadcastDartsEvent`, `streamDartsEvents`, `getDartsThrows`, and `submitDartsTurn`:
- transaction recomputes the turn from the thrown darts (bust → 0), appends `roundScores` and a `RoundSummaryStats` (`score` = points, `totalShots` = darts used, `madeShots` = darts scoring, `swishes` = trebles, `bestStreak` = bulls);
- **fixed order**: after P1's turn → P2, same round; after P2's turn → evaluate `DartsRules.isMatchOver`, else `currentRound + 1` and P1. (Different from `submitArcherySet`, which hands the next set to whoever shot second.)
- Also change line ~1013 (`if (data['game'] == 'archery') continue;`) to skip every non-basketball event.
✅ Check: `live_event_test.dart` round-trips `toMap/fromMap`; ignored for `game != 'darts'`.

**Step 17 — Firestore rules.** In `firestore.rules`: add `isPlausibleDartsTurn()` (new entry is int 0..180) next to `isPlausibleArcherySet()` and require it in `isSubmittingTurn()`; add `isValidDartsEvent()` in `live_shots` (own uid, active turn, current round, `dartIndex` 0–2, id pattern `t_…` for darts) and gate `create` on it when `game == 'darts'` — today a darts event would pass with **no** validation.
✅ Check: Oyindamola runs `firebase emulators:start --only firestore` and the app against it, then deploys the rules with `firebase deploy --only firestore:rules`.

**Step 18 — Online controller.** `online/darts_online_controller.dart` modelled on `ArcheryOnlineController`: match stream, live-event stream per (thrower, round), per-dart **20 s** shot clock with the saved-clock restore on leave/rejoin (copy `_SavedClock` and `_restoreClock`), opponent `aim` ping → their reticle appears, their `dart` event → flown with the inverse solver to the exact hit, claim-win when they go quiet, status pill states.
✅ Check (two browsers, two accounts): play a full match; leave mid-turn to the lobby and come back — clock continues, thrown darts are still in the board; refresh the opponent mid-turn — they see the darts already thrown without replays.

**Step 19 — Model, setup dialog, podium.** `cloud_match.dart`: darts `outcome` from `DartsRules.winner` (not total score). `match_setup_dialog.dart`: add a DARTS segment, fixed rules (`totalRounds: DartsRules.maxRounds`, `roundDurationSeconds: DartsRules.onlineTurnSeconds`), subtitle "Darts 1v1: 301, straight out, 3 darts a turn", share text "🎯 Throw darts with me on GameVerse!". Inbox card and podium show **remaining** for darts (301 − sum), not total points.
✅ Check: create from the dialog, join with code on another device, play to the end, both players land on the podium, REMATCH works for both and swaps who throws first; the completed match stays in COMPLETED history.

### Phase E — Ship

**Step 20 — Lobby + polish pass.** `game_catalog.dart`: `available: true`, tagline "301 to zero. Flick, don't fling.", pitch "Three darts a turn, straight out. Bust and you start the turn over.", `heroLabel: 'New'` (leave archery as featured until you decide). Profile on a mid Android phone in Chrome DevTools (60 fps while aiming and during flights, no GC spikes).
✅ Check: `flutter analyze`, `flutter test`, `flutter build web --release` all clean. Then Oyindamola deploys with:
```
flutter build web --release
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

---

## 5. What I'll check in review (bring each step's diff back)

- Allocations in `render()`/`update()` (Paint, Path, Rect, Offset, TextPainter, lists, closures, `Vector3(...)`).
- Board drawn from a cached `Picture`; numbers laid out once.
- Fixed-step physics and dt clamp intact; results frame-rate independent.
- Rules only in pure Dart; Flame game never decides scores; online scores recomputed from hit position.
- Turn order fixed (P1 then P2) in `submitDartsTurn`; equal-turns ending correct.
- `loadDartsSfx` mirrors every archery touch point in `AudioEngine`; soundtrack claimed/released.
- Darts doc-id prefixes don't collide with archery (`t_`/`p_` vs `a_`/`d_`); rules validate darts events.
- No `deleteMatch`, no SnackBars, palette only, Clean UI kit used.
