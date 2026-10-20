#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;        // canvas size px
uniform float uHorizonY;    // px (= horizonFrac * height)
uniform float uFocal;       // px
uniform float uEyeX;        // m
uniform float uEyeY;        // m (camera height)
uniform float uEyeZ;        // m
uniform float uStripeLen;   // m, e.g. 2.0
uniform vec4  uGrassA;      // light stripe color RGBA
uniform vec4  uGrassB;      // dark stripe color RGBA
uniform vec4  uHaze;        // haze color (sky-ish) RGBA
uniform float uHazeDist;    // m, e.g. 45.0
uniform float uTargetZ;     // m (D = 15.24m)
uniform sampler2D uGrassTex;// tileable grass detail texture

out vec4 fragColor;

float lineMask(float x, float halfW, float pxPerM) {
  // anti-aliased line of half-width halfW (m)
  float d = abs(x) - halfW;
  return 1.0 - clamp(d * pxPerM + 0.5, 0.0, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float dy = p.y - uHorizonY;
  if (dy <= 0.5) { 
    fragColor = vec4(0.0); 
    return; 
  }

  float dist   = uEyeY * uFocal / dy;                 // distance ahead (m)
  float wx     = uEyeX + (p.x - uSize.x * 0.5) * dist / uFocal;
  float wz     = uEyeZ + dist;
  float pxPerM = uFocal / dist;

  // mowed stripes (bands across the lane)
  float stripe = mod(floor(wz / uStripeLen), 2.0);
  vec3 col = mix(uGrassA.rgb, uGrassB.rgb, stripe);

  // grass detail, faded with distance to avoid shimmer (no mipmaps)
  vec3 tex = texture(uGrassTex, fract(vec2(wx, wz) * 0.35)).rgb;
  float detail = exp(-dist / 18.0);
  col *= mix(1.0, 0.7 + 0.6 * tex.g, detail);

  // lane lines: centre line + two lines converging toward the target legs (the "V")
  float onLane = step(0.0, wz) * step(wz, uTargetZ);
  float t = clamp(wz / uTargetZ, 0.0, 1.0);
  float sideX = mix(3.2, 0.55, t);                     // from wide at the line to the legs
  float lines = max(lineMask(wx, 0.025, pxPerM),
                max(lineMask(wx - sideX, 0.04, pxPerM),
                    lineMask(wx + sideX, 0.04, pxPerM))) * onLane;
                    
  // shooting line across the lane at z = 0
  lines = max(lines, lineMask(wz, 0.05, pxPerM) * step(abs(wx), 6.0));
  col = mix(col, vec3(0.97), lines * 0.92);

  // atmospheric haze
  float haze = 1.0 - exp(-dist / uHazeDist);
  col = mix(col, uHaze.rgb, haze * 0.55);

  fragColor = vec4(col, 1.0);
}
