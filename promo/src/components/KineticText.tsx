import React from "react";
import { spring, useCurrentFrame, useVideoConfig, interpolate } from "remotion";

interface KineticTextProps {
  badge?: string;
  title: string;
  subtitle?: string;
  accentColor?: string;
  position?: "top-left" | "bottom-center" | "top-center" | "bottom-left";
}

export const KineticText: React.FC<KineticTextProps> = ({
  badge,
  title,
  subtitle,
  accentColor = "#ff6b00",
  position = "top-left",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Split title into individual words for staggered elastic spring punches
  const words = title.split(" ");

  const positionStyles: Record<string, React.CSSProperties> = {
    "top-left": { top: 65, left: 80, textAlign: "left" },
    "bottom-center": { bottom: 70, left: "50%", transform: "translateX(-50%)", textAlign: "center" },
    "top-center": { top: 65, left: "50%", transform: "translateX(-50%)", textAlign: "center" },
    "bottom-left": { bottom: 70, left: 80, textAlign: "left" },
  };

  // Badge animation
  const badgeSpring = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 180, mass: 0.8 },
  });
  const badgeOpacity = interpolate(badgeSpring, [0, 1], [0, 1]);
  const badgeScale = interpolate(badgeSpring, [0, 1], [0.8, 1]);

  // Subtitle animation
  const subSpring = spring({
    frame: frame - 12,
    fps,
    config: { damping: 14, stiffness: 160, mass: 0.9 },
  });
  const subOpacity = interpolate(subSpring, [0, 1], [0, 1]);
  const subTranslateY = interpolate(subSpring, [0, 1], [25, 0]);

  return (
    <div
      style={{
        position: "absolute",
        zIndex: 60,
        pointerEvents: "none",
        ...positionStyles[position],
      }}
    >
      {/* Stadium Badge */}
      {badge && (
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "6px 16px",
            borderRadius: 999,
            background: "rgba(10, 15, 25, 0.75)",
            border: `1.5px solid ${accentColor}`,
            backdropFilter: "blur(16px)",
            color: accentColor,
            fontSize: 14,
            fontWeight: 900,
            fontStyle: "italic",
            letterSpacing: "0.16em",
            textTransform: "uppercase",
            marginBottom: 10,
            opacity: badgeOpacity,
            transform: `scale(${badgeScale})`,
            boxShadow: `0 0 25px ${accentColor}44, inset 0 0 10px ${accentColor}22`,
          }}
        >
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: accentColor,
              boxShadow: `0 0 12px ${accentColor}`,
            }}
          />
          {badge}
        </div>
      )}

      {/* Staggered Elastic Words Punch */}
      <h1
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: "0.3em",
          justifyContent: position.includes("center") ? "center" : "flex-start",
          fontSize: 66,
          fontWeight: 900,
          fontStyle: "italic",
          lineHeight: 1.02,
          letterSpacing: "-0.02em",
          color: "#ffffff",
          textTransform: "uppercase",
          margin: 0,
        }}
      >
        {words.map((word, i) => {
          // Staggered elastic spring punch requested by user
          const wordSpring = spring({
            frame: frame - i * 4,
            fps,
            config: { damping: 14, stiffness: 180, mass: 0.8 },
          });

          const wordY = interpolate(wordSpring, [0, 1], [45, 0]);
          const wordScale = interpolate(wordSpring, [0, 1], [0.65, 1]);
          const wordOpacity = interpolate(wordSpring, [0, 1], [0, 1]);
          const wordRot = interpolate(wordSpring, [0, 1], [-8, 0]);

          return (
            <span
              key={i}
              style={{
                display: "inline-block",
                transform: `translateY(${wordY}px) scale(${wordScale}) rotate(${wordRot}deg)`,
                opacity: wordOpacity,
                textShadow: `
                  0 4px 20px rgba(0, 0, 0, 0.95),
                  0 0 35px ${accentColor}66,
                  0 0 60px ${accentColor}33
                `,
              }}
            >
              {word}
            </span>
          );
        })}
      </h1>

      {/* Subtitle */}
      {subtitle && (
        <p
          style={{
            marginTop: 12,
            fontSize: 22,
            fontWeight: 700,
            color: "rgba(255, 255, 255, 0.85)",
            letterSpacing: "0.04em",
            textTransform: "uppercase",
            textShadow: "0 2px 12px rgba(0, 0, 0, 0.9)",
            opacity: subOpacity,
            transform: `translateY(${subTranslateY}px)`,
          }}
        >
          {subtitle}
        </p>
      )}
    </div>
  );
};
