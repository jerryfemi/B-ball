import React from "react";
import { Video, staticFile, useCurrentFrame, useVideoConfig, interpolate, spring, Easing } from "remotion";

interface Stage3DProps {
  videoSrc: string;
  startFrom?: number;
  rotateIntensity?: number;
  zoomScale?: number;
  tiltDirection?: "left" | "right" | "center";
  punchFrame?: number; // Frame where camera punches toward hoop & snaps back
  accentColor?: string;
  playbackRate?: number;
  focusTarget?: "center" | "top";
}

export const Stage3D: React.FC<Stage3DProps> = ({
  videoSrc,
  startFrom = 0,
  rotateIntensity = 1,
  zoomScale = 1,
  tiltDirection = "left",
  punchFrame,
  accentColor = "#ff6b00",
  playbackRate = 1,
  focusTarget = "center",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // 1. Subtle natural breathing motion for the floating 3D screen
  const isTopFocus = focusTarget === "top";
  const breathe = Math.sin(frame / 22) * 1.5;
  const baseRotY = tiltDirection === "left" ? 6 : tiltDirection === "right" ? -6 : 0;
  const baseRotX = isTopFocus ? 1.2 : 3.5;

  const rotY = (isTopFocus ? baseRotY * 0.35 : baseRotY) * rotateIntensity + breathe * 0.3;
  const rotX = baseRotX * rotateIntensity + Math.cos(frame / 26) * 0.5;

  // 2. Base camera push-in & Top Focus Zoom
  const baseScale = interpolate(frame, [0, 150], [1, 1.05], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  }) * zoomScale;

  // Top Focus Zoom & Pan Timing (starts at 24.20 / frame 8, peaks at 27.00 / frame 78 at 1.45x, then returns to 1.0x normal resolution)
  let topZoomMultiplier = 1;
  let topTranslateY = 0;

  if (isTopFocus) {
    if (frame < 8) {
      topZoomMultiplier = 1;
      topTranslateY = 0;
    } else if (frame <= 78) {
      // 24.20 to 27.00: Smooth ramp up to +45% max zoom (1.45x) and 130px downward framing
      const p = interpolate(frame, [8, 78], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
        easing: Easing.inOut(Easing.cubic),
      });
      topZoomMultiplier = 1 + 0.45 * p;
      topTranslateY = 130 * p;
    } else if (frame <= 135) {
      // 27.00 to 29.05: Smooth return journey back to normal resolution (1.0x)
      const p = interpolate(frame, [78, 135], [1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
        easing: Easing.inOut(Easing.cubic),
      });
      topZoomMultiplier = 1 + 0.45 * p;
      topTranslateY = 130 * p;
    } else {
      // Back at normal resolution
      topZoomMultiplier = 1;
      topTranslateY = 0;
    }
  }

  let currentScale = baseScale * topZoomMultiplier;

  // 3. Dynamic Camera Punch & Impact Snap-back (if punchFrame is set)
  let shakeX = 0;
  let shakeY = 0;

  if (punchFrame !== undefined) {
    if (frame < punchFrame) {
      // Zoom in toward basket smoothly during shot flight (+15% punch)
      const punchProgress = interpolate(
        frame,
        [Math.max(0, punchFrame - 25), punchFrame],
        [1, 1.16],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
      );
      currentScale *= punchProgress;
    } else {
      // Snap-back with spring overshoot on net impact!
      const snapSpring = spring({
        frame: frame - punchFrame,
        fps,
        config: { damping: 12, stiffness: 200, mass: 0.7 },
      });
      const snapScale = interpolate(snapSpring, [0, 1], [1.16, 1.02]);
      currentScale *= snapScale;

      // Net impact trauma camera shake (decays in 8 frames)
      const shakeFramesPassed = frame - punchFrame;
      if (shakeFramesPassed >= 0 && shakeFramesPassed < 10) {
        const decay = interpolate(shakeFramesPassed, [0, 10], [1, 0]);
        shakeX = Math.sin(shakeFramesPassed * 3.5) * 8 * decay;
        shakeY = Math.cos(shakeFramesPassed * 4.2) * 6 * decay;
      }
    }
  }

  const badgeOpacity = isTopFocus
    ? interpolate(topZoomMultiplier, [1.02, 1.15], [1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 1;

  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        perspective: 1400,
        transform: `translate(${shakeX}px, ${shakeY + topTranslateY}px)`,
      }}
    >
      {/* Subtle Atmospheric Stadium Court Depth Orbs */}
      <div
        style={{
          position: "absolute",
          width: 900,
          height: 520,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${accentColor}12 0%, ${accentColor}05 50%, transparent 75%)`,
          filter: "blur(90px)",
          transform: "translate(-140px, -30px)",
          pointerEvents: "none",
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 800,
          height: 480,
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(0, 229, 255, 0.08) 0%, rgba(0, 140, 255, 0.02) 50%, transparent 75%)",
          filter: "blur(85px)",
          transform: "translate(240px, 90px)",
          pointerEvents: "none",
        }}
      />

      {/* Floating 3D Device Screen Container */}
      <div
        style={{
          position: "relative",
          width: 1440,
          height: 810,
          borderRadius: 26,
          overflow: "hidden",
          border: "1.5px solid rgba(255, 255, 255, 0.18)",
          boxShadow: `
            0 35px 90px -15px rgba(0, 0, 0, 0.95),
            0 0 35px ${accentColor}15,
            0 0 60px rgba(0, 229, 255, 0.06),
            inset 0 1.5px 2px rgba(255, 255, 255, 0.25)
          `,
          transform: `rotateY(${rotY}deg) rotateX(${rotX}deg) scale(${currentScale})`,
          transformOrigin: isTopFocus ? "center 12%" : "center center",
          transformStyle: "preserve-3d",
          background: "#0c0e14",
        }}
      >
        {/* The Muted Gameplay Video (Smooth Hardware Accelerated) */}
        <Video
          src={staticFile(videoSrc)}
          startFrom={startFrom}
          playbackRate={playbackRate}
          volume={0}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            display: "block",
          }}
        />

        {/* Dynamic Glass Glare Sheen Reflection */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "linear-gradient(125deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.02) 35%, rgba(0,0,0,0.15) 100%)",
            pointerEvents: "none",
          }}
        />

        {/* Stadium Corner Live Badge (fades during top zoom to avoid covering game UI) */}
        {badgeOpacity > 0 && (
          <div
            style={{
              position: "absolute",
              top: 18,
              right: 22,
              display: "flex",
              alignItems: "center",
              gap: 7,
              background: "rgba(5, 8, 15, 0.75)",
              backdropFilter: "blur(12px)",
              padding: "5px 12px",
              borderRadius: 999,
              border: "1px solid rgba(255, 255, 255, 0.15)",
              fontSize: 12,
              fontWeight: 800,
              letterSpacing: "0.12em",
              color: "#ffffff",
              boxShadow: "0 4px 15px rgba(0,0,0,0.5)",
              opacity: badgeOpacity,
            }}
          >
            <span
              style={{
                width: 7,
                height: 7,
                borderRadius: "50%",
                background: "#00e5ff",
                boxShadow: "0 0 10px #00e5ff",
              }}
            />
            DUNKVERSE
          </div>
        )}
      </div>
    </div>
  );
};
