import React from "react";
import { Sequence, Audio, staticFile, interpolate } from "remotion";
import { Stage3D } from "./components/Stage3D";
import { KineticText } from "./components/KineticText";
import { OutroScreen } from "./components/OutroScreen";

/**
 * BBallPromo — Multi-Shot Sound Synced & Speed-Optimized Trailer (1920x1080 @ 30fps)
 *
 * Sequence Timings & Speeds:
 * 01: shooting.mp4          -> 263 frames (0 - 263)      ~8.78s (1.0x)
 * 02: replay.mp4            -> 201 frames (263 - 464)    ~6.69s (1.0x)
 * 03: create_room_code.mp4  -> 268 frames (464 - 732)    ~8.93s (1.3x speed)
 * 04: accept_invite.mp4     -> 202 frames (732 - 934)    ~6.73s (1.0x)
 * 05: reply_chat.mp4        -> 252 frames (934 - 1186)   ~8.40s (1.3x speed)
 * 06: my turn.mp4           -> 231 frames (1186 - 1417)  ~7.71s (1.0x)
 * 07: opp_reaction_2_me.mp4 -> 165 frames (1417 - 1582)  ~5.50s (1.0x)
 * 08: react_2_opp.mp4       -> 135 frames (1582 - 1717)  ~4.50s (1.0x)
 * 09: podium.mp4            -> 103 frames (1717 - 1820)  ~3.43s (reduced by 2s)
 * 10A: Play in Browser      -> 70 frames (1820 - 1890)   ~2.33s
 * 10B: Add to Home Screen   -> 80 frames (1890 - 1970)   ~2.67s
 *
 * Total Frames: 1970 (~65.7s)
 */
export const BBallPromo: React.FC = () => {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: "#07080b",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Global Background Track — Music Takes Me Up (cropped 10s so singing hits at 20s mark, -10% volume) */}
      <Audio
        src={staticFile("music/Mr Scruff - Music Takes Me Up - JoeStephens78.mp3")}
        startFrom={300}
        volume={(f) =>
          interpolate(f, [0, 30, 1890, 1970], [0.09, 0.225, 0.225, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        }
      />

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* ─── TACTILE UI CLICKS (USER TIMESTAMPS - REDUCED BY 20% TO 0.68) ─ */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* 09.26 (Replay UI) -> Frame 288 */}
      <Sequence from={288}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 16.03 (Create Room) -> Frame 475 */}
      <Sequence from={475}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 17.15 (Invite Button) -> Frame 517 */}
      <Sequence from={517}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 18.21 (Share Link) -> Frame 553 */}
      <Sequence from={553}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 23.04 (Room Confirm) -> Frame 686 */}
      <Sequence from={686}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 27.22 (Accept Invite Chip) -> Frame 824 */}
      <Sequence from={824}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 29.13 (Join Lobby) -> Frame 875 */}
      <Sequence from={875}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 32.21 (Open Chat) -> Frame 973 */}
      <Sequence from={973}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 33.19 (Chat Input) -> Frame 1001 */}
      <Sequence from={1001}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>
      {/* 34.17 (Send Message) -> Frame 1029 */}
      <Sequence from={1029}>
        <Audio src={staticFile("audio/click.mp3")} volume={0.68} />
      </Sequence>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* ─── FRIEND CHAT TYPING AUDIO (Advanced 0.25s / 8 frames earlier) ─ */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* Frame 1084 to 1129 (was 1092 - 8) */}
      <Sequence from={1084} durationInFrames={45}>
        <Audio
          src={staticFile("audio/typing.mp3")}
          volume={(f) =>
            interpolate(f, [0, 4, 38, 45], [0, 0.58, 0.58, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          }
        />
      </Sequence>

      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* ─── LIVE MATCH REACTIONS CHIME AUDIO (RINGING OUT @ 0.8) ───────── */}
      {/* ══════════════════════════════════════════════════════════════════ */}
      {/* 052.25: Reaction 0 Chime -> Frame 1585 (Rings out musically for 22 frames) */}
      <Sequence from={1585} durationInFrames={22}>
        <Audio
          src={staticFile("audio/chime.mp3")}
          volume={(f) =>
            interpolate(f, [0, 2, 16, 22], [0, 0.8, 0.8, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          }
        />
      </Sequence>
      {/* 053.10: Reaction 1 Chime -> Frame 1600 (Rings out musically for 25 frames) */}
      <Sequence from={1600} durationInFrames={25}>
        <Audio
          src={staticFile("audio/chime.mp3")}
          volume={(f) =>
            interpolate(f, [0, 2, 18, 25], [0, 0.8, 0.8, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          }
        />
      </Sequence>
      {/* 054.01: Reaction 2 Chime -> Frame 1621 (Rings out musically for 30 frames) */}
      <Sequence from={1621} durationInFrames={30}>
        <Audio
          src={staticFile("audio/chime.mp3")}
          volume={(f) =>
            interpolate(f, [0, 2, 22, 30], [0, 0.8, 0.8, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          }
        />
      </Sequence>

      {/* ─── 01: SHOOTING (Full 263 frames with multi-shot SFX) ───── */}
      <Sequence from={0} durationInFrames={263} name="01 — Shooting (Clean Shot & Streak)">
        {/* 1. First Shot Clean Swish: 02.12 (Frame 72 - perfectly on time) */}
        <Sequence from={72}>
          <Audio src={staticFile("audio/swish.wav")} volume={0.62} />
        </Sequence>

        {/* 2. Bank Shot strikes backboard: 05.02 (Frame 152 - nudged tiny fraction later) */}
        <Sequence from={152}>
          <Audio src={staticFile("audio/backboard.wav")} volume={0.58} />
        </Sequence>

        {/* 3. Bank Shot drops into net: 05.19 (Frame 169 - nudged 0.5s later as ball ripples cords) */}
        <Sequence from={169}>
          <Audio src={staticFile("audio/swish.wav")} volume={0.55} />
        </Sequence>

        {/* 4. Third shot strikes the rim: 07.06 (Frame 216 - nudged 0.25s later to front rim clank) */}
        <Sequence from={216}>
          <Audio src={staticFile("audio/rim_clank.wav")} volume={0.35} />
        </Sequence>

        {/* 5. Third shot swishes through net: 07.17 (Frame 227 - streak swish through bottom cords) */}
        <Sequence from={227}>
          <Audio src={staticFile("audio/swish.wav")} volume={0.58} />
        </Sequence>

        <Stage3D
          videoSrc="clips/shooting.mp4"
          startFrom={0}
          tiltDirection="left"
          punchFrame={72}
          accentColor="#00e5ff"
        />

        {/* First Shot Caption: CLEAN SHOT. */}
        <Sequence from={0} durationInFrames={120}>
          <KineticText
            badge="Solo Arcade"
            title="CLEAN SHOT."
            subtitle="Precision trajectory physics"
            accentColor="#00e5ff"
            position="top-left"
          />
        </Sequence>

        {/* Second Shot Streak Caption: IN A ROW. */}
        <Sequence from={120} durationInFrames={143}>
          <KineticText
            badge="Multiplier"
            title="IN A ROW."
            subtitle="Stack streaks and ignite fire bonuses"
            accentColor="#ff6b00"
            position="top-left"
          />
        </Sequence>
      </Sequence>

      {/* ─── 02: REPLAY (201 frames) ──────────────────────────────── */}
      <Sequence from={263} durationInFrames={201} name="02 — Replay">
        <Stage3D
          videoSrc="clips/replay.mp4"
          startFrom={0}
          tiltDirection="right"
          accentColor="#ffd000"
        />
        <KineticText
          badge="Playback"
          title="SEE INSTANT REPLAYS"
          subtitle="Analyze your arc frame-by-frame"
          accentColor="#ffd000"
          position="top-left"
        />
      </Sequence>

      {/* ─── 03: CREATE ROOM CODE (268 frames @ 1.3x speed) ───────── */}
      <Sequence from={464} durationInFrames={268} name="03 — Create Room Code (1.3x)">
        <Stage3D
          videoSrc="clips/create_room_code.mp4"
          startFrom={0}
          playbackRate={1.3}
          tiltDirection="left"
          accentColor="#00ff88"
        />
        <KineticText
          badge="Instant Matchmaking"
          title="CREATE A ROOM & INVITE FRIENDS"
          subtitle="Share room codes with 1 click"
          accentColor="#00ff88"
          position="top-left"
        />
      </Sequence>

      {/* ─── 04: ACCEPT INVITE (202 frames) ───────────────────────── */}
      <Sequence from={732} durationInFrames={202} name="04 — Accept Invite">
        <Stage3D
          videoSrc="clips/accept_invite.mp4"
          startFrom={0}
          tiltDirection="center"
          focusTarget="top"
          accentColor="#00d2ff"
        />
        <KineticText
          badge="Lobby"
          title="ACCEPT INVITE & JOIN"
          subtitle="Jump directly into your friend's court"
          accentColor="#00d2ff"
          position="bottom-left"
        />
      </Sequence>

      {/* ─── 05: REPLY CHAT (252 frames @ 1.3x speed) ─────────────── */}
      <Sequence from={934} durationInFrames={252} name="05 — Friend Chat (1.3x)">
        <Stage3D
          videoSrc="clips/reply_chat.mp4"
          startFrom={0}
          playbackRate={1.3}
          tiltDirection="left"
          accentColor="#a855f7"
        />
        <KineticText
          badge="Social"
          title="CHAT WITH FRIENDS"
          subtitle="Real-time in-game messaging"
          accentColor="#a855f7"
          position="top-left"
        />
      </Sequence>

      {/* ─── 06: MY TURN 3-2-1 (231 frames) ───────────────────────── */}
      <Sequence from={1186} durationInFrames={231} name="06 — 321 Countdown">
        <Stage3D
          videoSrc="clips/my turn.mp4"
          startFrom={0}
          tiltDirection="center"
          accentColor="#ff3366"
        />
        <KineticText
          badge="Showdown"
          title="TURN BASED SHOWDOWN"
          subtitle="Shot for shot, round by round"
          accentColor="#ff3366"
          position="bottom-center"
        />
      </Sequence>

      {/* ─── 07: OPP REACTION TO ME (165 frames) ──────────────────── */}
      <Sequence from={1417} durationInFrames={165} name="07 — Live 1v1 Match">
        <Stage3D
          videoSrc="clips/opp_reaction_2_me.mp4"
          startFrom={0}
          tiltDirection="left"
          accentColor="#00e5ff"
        />
        <KineticText
          badge="Multiplayer"
          title="LIVE 1V1 MATCHES"
          subtitle="Compete head-to-head in real time"
          accentColor="#00e5ff"
          position="top-left"
        />
      </Sequence>

      {/* ─── 08: REACT TO OPP (135 frames) ────────────────────────── */}
      <Sequence from={1582} durationInFrames={135} name="08 — Live Match Reactions">
        <Stage3D
          videoSrc="clips/react_2_opp.mp4"
          startFrom={0}
          tiltDirection="right"
          accentColor="#ff9900"
        />
        <KineticText
          badge="Expressions"
          title="LIVE MATCH REACTIONS"
          subtitle="Fire off emojis & emotes on every play"
          accentColor="#ff9900"
          position="top-left"
        />
      </Sequence>

      {/* ─── 09: PODIUM STATS (103 frames - reduced by 2s) ───────── */}
      <Sequence from={1717} durationInFrames={103} name="09 — Game Stats">
        <Audio src={staticFile("audio/buzzer.wav")} volume={0.42} />
        <Stage3D
          videoSrc="clips/podium.mp4"
          startFrom={0}
          tiltDirection="center"
          accentColor="#ffd700"
        />
        <KineticText
          badge="Results"
          title="VIEW YOUR GAME STATS & SCORES"
          subtitle="Round breakdown, accuracy, and podium"
          accentColor="#ffd700"
          position="top-left"
        />
      </Sequence>

      {/* ─── 10A: PLAY IN BROWSER (70 frames: 1820 - 1890) ────────── */}
      <Sequence from={1820} durationInFrames={70} name="10A — Play in Browser">
        <OutroScreen
          imageSrc="web.png"
          badge="Web First"
          title="PLAY IN BROWSER"
          subtitle="Instant access on any device • No download"
          accentColor="#00e5ff"
        />
      </Sequence>

      {/* ─── 10B: ADD TO HOME SCREEN (80 frames: 1890 - 1970) ───────── */}
      <Sequence from={1890} durationInFrames={80} name="10B — Add to Home Screen">
        <OutroScreen
          imageSrc="add.png"
          badge="Home Screen Web App"
          title="ADD TO HOME SCREEN"
          subtitle="for better experience"
          accentColor="#ff6b00"
          showAppIcon={true}
        />
      </Sequence>
    </div>
  );
};
