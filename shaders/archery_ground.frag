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

  float dist    = uEyeY * uFocal / dy;                 // distance ahead (m)
  float wx      = uEyeX + (p.x - uSize.x * 0.5) * dist / uFocal;
  float wz      = uEyeZ + dist;

  float pxPerMx = uFocal / dist;                       // px per metre across the lane
  float pxPerMz = uFocal * uEyeY / (dist * dist);      // px per metre ALONG the lane (foreshortened)

  // mowed stripes with anti-aliased edges (eliminates edge shimmer)
  float s      = wz / uStripeLen;
  float band   = mod(floor(s), 2.0);
  float dEdge  = min(fract(s), 1.0 - fract(s)) * uStripeLen * pxPerMz;
  float stripe = mix(0.5, band, clamp(dEdge, 0.0, 1.0));
  vec3 col     = mix(uGrassA.rgb, uGrassB.rgb, stripe);

  // two-scale detail: fine blades (~0.8 m tile) + broad patches (~9 m tile)
  float fine       = texture(uGrassTex, fract(vec2(wx, wz) * 1.25)).r;
  float patchNoise = texture(uGrassTex, fract(vec2(wx, wz) * 0.11 + 0.37)).r;
  float fineFade   = clamp((pxPerMx - 25.0) / 60.0, 0.0, 1.0); // fade fine blades before aliasing
  col *= mix(1.0, 0.72 + 0.56 * fine, fineFade * 0.9);
  col *= 0.86 + 0.28 * patchNoise;

  // mowing sheen: blades on light stripes catch more light
  col *= mix(1.06, 1.0, stripe);

  // subtle hue drift so the field is not a single uniform flat green
  col = mix(col, col * vec3(1.10, 1.03, 0.82), patchNoise * 0.35);

  // lane lines: centre line + two lines converging toward target legs (the "V")
  // lanes start at the painted shooting line (z = 4.0, see ArcheryK.shootingLineZ)
  float onLane = step(4.0, wz) * step(wz, uTargetZ);
  float t      = clamp((wz - 4.0) / (uTargetZ - 4.0), 0.0, 1.0);
  float sideX  = mix(1.6, 0.55, t);                    // ArcheryK.laneHalfWidthAtLine -> target legs
  float lines  = max(lineMask(wx, 0.025, pxPerMx),
                 max(lineMask(wx - sideX, 0.04, pxPerMx),
                     lineMask(wx + sideX, 0.04, pxPerMx))) * onLane;
                     
  // shooting line across the lane at z = 0 (using pxPerMz for horizontal line AA)
  // (z = 4.0 m must match ArcheryK.shootingLineZ)
  lines = max(lines, (1.0 - clamp(abs(wz - 4.0) * pxPerMz - 0.05 * pxPerMz + 0.5, 0.0, 1.0)) * step(abs(wx), 6.0));
  col = mix(col, vec3(0.97), lines * 0.92);

  // soft contact darkening under the target stand (grounds the target board)
  float targetDistM = length(vec2(wx, wz - uTargetZ));
  float contactDark = smoothstep(0.7, 0.2, targetDistM);
  col *= mix(1.0, 0.80, contactDark);

  // atmospheric haze
  float haze = 1.0 - exp(-dist / uHazeDist);
  col = mix(col, uHaze.rgb, haze * 0.55);

  fragColor = vec4(col, 1.0);
}
