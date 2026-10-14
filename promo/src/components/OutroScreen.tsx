import React from "react";
import { Img, staticFile, useCurrentFrame, useVideoConfig, interpolate, spring, Easing } from "remotion";
import { KineticText } from "./KineticText";

interface OutroScreenProps {
  imageSrc: string;
  badge: string;
  title: string;
  subtitle: string;
  accentColor?: string;
  showAppIcon?: boolean;
}

export const OutroScreen: React.FC<OutroScreenProps> = ({
  imageSrc,
  badge,
  title,
  subtitle,
  accentColor = "#00e5ff",
  showAppIcon = false,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Subtle natural camera push-in and float
  const scale = interpolate(frame, [0, 80], [1, 1.04], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  });
  const floatY = Math.sin(frame / 22) * 5;

  // Flash entrance transition
  const flashOpacity = interpolate(frame, [0, 6], [0.45, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  });

  // App icon spring-in animation
  const iconSpring = spring({
    frame: frame - 10,
    fps,
    config: { damping: 13, stiffness: 170, mass: 0.8 },
  });
  const iconScale = interpolate(iconSpring, [0, 1], [0.7, 1]);
  const iconOpacity = interpolate(iconSpring, [0, 1], [0, 1]);

  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        backgroundColor: "#07080c",
        overflow: "hidden",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {/* Cinematic Flash Transition */}
      {flashOpacity > 0 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            zIndex: 90,
            background: `radial-gradient(circle at 50% 50%, rgba(255, 255, 255, 0.7) 0%, ${accentColor}55 40%, transparent 70%)`,
            mixBlendMode: "screen",
            opacity: flashOpacity,
            pointerEvents: "none",
          }}
        />
      )}

      {/* Atmospheric Stadium Court Glow Orbs */}
      <div
        style={{
          position: "absolute",
          width: 900,
          height: 600,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${accentColor}26 0%, transparent 70%)`,
          filter: "blur(90px)",
          transform: "translate(-200px, 0)",
          pointerEvents: "none",
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 800,
          height: 500,
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(255, 107, 0, 0.2) 0%, transparent 70%)",
          filter: "blur(80px)",
          transform: "translate(300px, 80px)",
          pointerEvents: "none",
        }}
      />

      {/* Kinetic Text Overlay */}
      <KineticText
        badge={badge}
        title={title}
        subtitle={subtitle}
        accentColor={accentColor}
        position="top-left"
      />

      {/* Central 3D Device Screenshot Mockup */}
      <div
        style={{
          position: "relative",
          zIndex: 20,
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${scale}) translateY(${floatY}px)`,
          transformOrigin: "center center",
        }}
      >
        <Img
          src={staticFile(imageSrc)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "contain",
            filter: "drop-shadow(0 25px 60px rgba(0, 0, 0, 0.9))",
          }}
        />
      </div>

      {/* App Icon Showcase (pops in during Add to Home Screen beat) */}
      {showAppIcon && (
        <div
          style={{
            position: "absolute",
            zIndex: 50,
            bottom: 75,
            right: 90,
            display: "flex",
            alignItems: "center",
            gap: 18,
            padding: "12px 24px 12px 16px",
            borderRadius: 28,
            background: "rgba(10, 14, 24, 0.82)",
            border: `1.5px solid ${accentColor}66`,
            backdropFilter: "blur(20px)",
            boxShadow: `0 25px 70px rgba(0, 0, 0, 0.9), 0 0 40px ${accentColor}33`,
            opacity: iconOpacity,
            transform: `scale(${iconScale})`,
          }}
        >
          {/* Squircle App Icon */}
          <div
            style={{
              width: 82,
              height: 82,
              borderRadius: 20,
              overflow: "hidden",
              border: "1.5px solid rgba(255, 255, 255, 0.3)",
              boxShadow: "0 8px 24px rgba(0, 0, 0, 0.7)",
              flexShrink: 0,
            }}
          >
            <Img
              src={staticFile("app_icon.png")}
              style={{
                width: "100%",
                height: "100%",
                objectFit: "cover",
              }}
            />
          </div>

          <div>
            <div
              style={{
                fontSize: 22,
                fontWeight: 900,
                letterSpacing: "0.06em",
                color: "#ffffff",
                fontStyle: "italic",
                textTransform: "uppercase",
              }}
            >
              ARCADE B-BALL
            </div>
            <div
              style={{
                fontSize: 13,
                fontWeight: 700,
                letterSpacing: "0.12em",
                color: accentColor,
                textTransform: "uppercase",
                marginTop: 3,
                display: "flex",
                alignItems: "center",
                gap: 6,
              }}
            >
              <span style={{ width: 6, height: 6, borderRadius: "50%", background: accentColor }} />
              INSTALL ON YOUR HOME SCREEN
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
