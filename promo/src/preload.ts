import { prefetch, staticFile } from "remotion";

/**
 * Preload all video assets into browser memory so switching sequences
 * in Remotion Studio is instantaneous without any audio hitching.
 */
export const preloadVideoAssets = () => {
  const clips = [
    "clips/shooting.mp4",
    "clips/replay.mp4",
    "clips/create_room_code.mp4",
    "clips/accept_invite.mp4",
    "clips/reply_chat.mp4",
    "clips/my turn.mp4",
    "clips/opp_reaction_2_me.mp4",
    "clips/react_2_opp.mp4",
    "clips/podium.mp4",
  ];

  clips.forEach((clip) => {
    try {
      prefetch(staticFile(clip), { method: "blob-url" });
    } catch (e) {
      // Ignore in non-browser context
    }
  });
};

preloadVideoAssets();
