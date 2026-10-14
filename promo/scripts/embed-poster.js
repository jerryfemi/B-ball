const { execFileSync } = require("child_process");
const path = require("path");
const fs = require("fs");

try {
  const { RenderInternals } = require("@remotion/renderer");
  const ffmpegPath = RenderInternals.getExecutablePath({ type: "ffmpeg" });
  
  const outDir = path.resolve(__dirname, "../out");
  const inputVideo = path.join(outDir, "bball_promo.mp4");
  const posterImage = path.join(outDir, "bball_promo_thumbnail.png");
  const tempOutput = path.join(outDir, "bball_promo_with_poster.mp4");

  if (!fs.existsSync(inputVideo)) {
    console.error(`Input video not found: ${inputVideo}`);
    process.exit(1);
  }

  if (!fs.existsSync(posterImage)) {
    console.error(`Poster image not found: ${posterImage}`);
    process.exit(1);
  }

  console.log("Embedding Frame 40 poster into bball_promo.mp4...");
  execFileSync(
    ffmpegPath,
    [
      "-i", inputVideo,
      "-i", posterImage,
      "-map", "0",
      "-map", "1",
      "-c", "copy",
      "-disposition:v:1", "attached_pic",
      tempOutput,
      "-y",
    ],
    { stdio: "inherit" }
  );

  // Replace original file with the new file containing embedded poster
  fs.copyFileSync(tempOutput, inputVideo);
  fs.unlinkSync(tempOutput);

  console.log("✓ Frame 40 embedded as the official MP4 poster stream in out/bball_promo.mp4!");
} catch (err) {
  console.error("Failed to embed poster:", err.message);
  process.exit(1);
}
