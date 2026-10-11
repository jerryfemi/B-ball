# B-Ball Arcade — Project Architecture & Roadmap

## 🏀 Game Overview
An authentic GamePigeon-style arcade basketball game built with Flutter and Flame. Features deterministic 2.5D arc physics, swish/rim collision dynamics, shot telemetry recording, ghost ball spectator replays, multi-round match progression, and cross-platform multiplayer (Web / PWA & Mobile).

---

## 🚀 Project Milestones & Progress

### ✅ Phase 0: Core Engine & Physics (Completed)
- Custom 2.5D isometric court projection and depth scaling.
- Ball launch solver with realistic drag, gravity, and Magnus backspin.
- High-fidelity dual-collider rim physics (front lip clank, back rim ricochet, backboard bank).
- Metallic rim clank (`rim_clank.wav`) and court bounce (`bounce.wav`) audio at 60% master volume.

### ✅ Phase 1: Telemetry & Ghost Ball System (Completed)
- High-resolution shot logging via `RecordedShot` and `RoundTelemetry`.
- Deterministic ghost ball playback engine with trailing neon motion effects.
- Skip replay overlay for fast turn turnaround.

### ✅ Phase 2: Local Pass-and-Play Loop (Completed)
- Alternating shooter turn loop with round timers (30s Blitz / 60s Standard).
- Round intermission modal with cumulative score breakdown and handoff guidance.

### ✅ Phase 3: Match Progression & UI Overhaul (Completed)
- Configurable 2, 3, or 4-round matches via `MatchConfig` and `MatchSession`.
- Neon LED `MatchSetupDialog` with round selector pills, shot clock toggle, and player avatar customization.
- Grand `MatchWinnerPodiumOverlay` with round-by-round score matrix, per-round crown indicators, shooting accuracy analytics, swish count, and best streaks.
- Stadium scoreboard with reactive round pills (`ROUND X OF Y`) and player avatars.

---

## 🎯 Current Milestone: Phase 4 — Online Multiplayer & Social (In Progress)

### 1. Anonymous Cloud Identity (100% Auth-Free)
- **Silent Background Guest Auth**: `FirebaseAuth.instance.signInAnonymously()` on first launch. Zero sign-up forms, zero passwords, zero friction.
- **Web / PWA IndexedDB Persistence**: Retains guest identity across browser reloads.
- **Optional Account Linking**: One-tap Google/Apple link to persist career records across devices if desired.

### 2. Cloud Firestore Async Turns (GamePigeon Model)
- **Turn-Based Cloud Sync**: Player 1 shoots Round 1 $\to$ writes `RoundTelemetry` to `matches/{matchId}`.
- **Opponent Turn & Ghost Playback**: Player 2 receives turn $\to$ spectates Player 1's ghost ball round $\to$ shoots their turn $\to$ sends back.
- **Match Inbox**: Displays active matches ("Your Turn" vs "Waiting for Opponent") and match history.
- **Shareable Match Links & 6-Digit Codes**:
  - Web URL: `https://bball.web.app/#/join?code=842910`
  - 6-character arcade code for instant cross-device joining.

### 3. Quick-Tap Arcade Reactions & Chat
- **Banter Chips**: One-tap instant reaction pills (🧱 "BRICK!", 🎯 "SWISH!", 🔥 "ON FIRE!", 🥶 "ICE IN MY VEINS", 🍀 "LUCKY BOUNCE!", 👑 "REMATCH?").
- **Visual & Audio Feedback**: Floats dynamic reaction pills across the arena with punchy sound effects.
- **Match Chat Drawer**: Optional text chat thread stored inside the match document.

---

## 🔮 Future Milestone: Phase 5 — Live Head-to-Head Duel Mode (Real-Time Spectating)

> **Concept**: While User A is shooting their live round, User B is connected simultaneously as a live spectator!

### Key Features:
1. **Live Trajectory Streaming**:
   - Because our physics engine uses deterministic parameters (`startX`, `startY`, `startZ`, `vx`, `vy`, `vz`, `spin`), streaming a single lightweight JSON packet the instant User A releases the ball allows User B's screen to simulate the shot in real-time with zero lag or bandwidth waste.
2. **Real-Time Score & Clock Sync**:
   - Opponent watches the live countdown clock and sees the scoreboard tick up the instant a swish hits the net.
3. **Live Heckle & Hype Reaction Spam**:
   - While User A is taking aim or in mid-flick, User B can spam live reactions (🧱 "BRICK!", 🥶 "COLD!", 😱, 🎯).
   - Reactions float up across User A's court with neon particle bursts and audio stingers, creating intense arcade banter and psychological pressure!
4. **Sudden Death / Overtime Shootouts**:
   - Real-time 15-second clutch shot duels if rounds end in a tie.
