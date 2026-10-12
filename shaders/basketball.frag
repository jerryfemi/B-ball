#include <flutter/runtime_effect.glsl>

uniform vec2 u_center; // center of the ball in screen pixels
uniform float u_radius; // radius of the ball in screen pixels
uniform vec2 u_rotation; // x = yaw (spin around Y), y = pitch (spin around X)
uniform float u_local_radius; // radius in local canvas coordinates

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 uv;

    // Detect if FlutterFragCoord is in local coordinates (Impeller engine)
    // or global screen pixels (Skia / CanvasKit engine):
    if (abs(coord.x) <= u_local_radius * 2.5 && abs(coord.y) <= u_local_radius * 2.5 && length(u_center) > u_radius * 2.0) {
        uv = coord / u_local_radius;
    } else {
        uv = (coord - u_center) / u_radius;
    }

    float radius = length(uv);
    if (radius > 1.0) {
        // Outside the sphere, return transparent
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    
    // Calculate 3D Z-coordinate on the sphere surface (x^2 + y^2 + z^2 = r^2)
    float z = sqrt(1.0 - radius * radius);
    vec3 normal = vec3(uv, z); // The unrotated normal vector pointing at the camera
    
    // Build rotation matrices
    // Pitch (around X axis)
    float cx = cos(u_rotation.y);
    float sx = sin(u_rotation.y);
    mat3 rotX = mat3(
        1.0, 0.0, 0.0,
        0.0, cx, -sx,
        0.0, sx,  cx
    );
    
    // Yaw (around Y axis)
    float cy = cos(u_rotation.x);
    float sy = sin(u_rotation.x);
    mat3 rotY = mat3(
        cy, 0.0, sy,
        0.0, 1.0, 0.0,
        -sy, 0.0, cy
    );
    
    // Physical surface coordinate on the spinning sphere
    vec3 spherePos = rotY * rotX * normal;
    
    // --- 1. Authentic Seams (Recessed Rubber Grooves with Raised Lip) ---
    float distToSeam = 1.0;
    
    // Equator seam
    distToSeam = min(distToSeam, abs(spherePos.y));
    // Vertical seam
    distToSeam = min(distToSeam, abs(spherePos.x));
    // Curved side seams
    float distLeft = abs(distance(spherePos.xz, vec2(-0.8, 0.0)) - 0.6);
    float distRight = abs(distance(spherePos.xz, vec2(0.8, 0.0)) - 0.6);
    distToSeam = min(distToSeam, min(distLeft, distRight));
    
    float lineThickness = 0.052;
    // Seam channel factor: 1.0 inside groove, 0.0 on leather
    float seamMask = smoothstep(lineThickness, lineThickness * 0.72, distToSeam);
    
    // Raised leather ridge directly adjacent to the recessed seam
    float seamRidge = smoothstep(lineThickness * 1.45, lineThickness, distToSeam) * (1.0 - seamMask) * 0.22;
    
    // --- 2. Microscopic Pebbled Leather Texture (Dimpled Bumps) ---
    // Frequency tuned for authentic basketball pebble density
    vec3 pebbleP = spherePos * 54.0;
    vec3 f = fract(pebbleP) - 0.5;
    float distToPebbleCenter = length(f);
    
    // Smooth hemispherical pebble dome
    float pebbleBump = clamp(1.0 - distToPebbleCenter * 2.15, 0.0, 1.0);
    pebbleBump = pebbleBump * pebbleBump * (3.0 - 2.0 * pebbleBump); // Smooth cubic S-curve
    
    // Suppress pebbles inside the rubber seam channel
    pebbleBump *= (1.0 - seamMask);
    
    // --- 3. Normal Vector Perturbation (Bump Mapping) ---
    // Perturb the normal with pebble dome gradients so it catches highlights individually
    vec3 bumpOffset = vec3(f.x, f.y, 0.0) * pebbleBump * 0.38;
    
    // Recess the seam into the sphere surface
    if (seamMask > 0.01) {
        bumpOffset -= normal * seamMask * 0.15;
    }
    
    vec3 perturbedNormal = normalize(normal + bumpOffset);
    
    // --- 4. Authentic Composite Leather Color Grading ---
    // Deep Wilson / Spalding composite orange palette
    vec3 leatherDark = vec3(0.70, 0.27, 0.03);  // Deep burnt sienna between pebbles
    vec3 leatherMid  = vec3(0.86, 0.38, 0.07);  // Warm composite orange body
    vec3 leatherPeak = vec3(0.96, 0.47, 0.11);  // Slightly worn pebble highlight tops
    
    vec3 leatherColor = mix(leatherDark, leatherMid, pebbleBump);
    leatherColor = mix(leatherColor, leatherPeak, pow(pebbleBump, 2.5));
    // Add subtle raised ridge brightness
    leatherColor += vec3(0.06, 0.03, 0.01) * seamRidge;
    
    // Matte charcoal black rubber seam with subtle edge gradient
    vec3 rubberSeamColor = vec3(0.12, 0.12, 0.12);
    
    vec3 baseColor = mix(leatherColor, rubberSeamColor, seamMask);
    
    // --- 5. Volumetric Arena Lighting & Dual-Lobe Specular ---
    // Overhead arena floodlight: top-left and slightly in front
    vec3 lightDir = normalize(vec3(-0.25, 0.92, 0.65));
    float diff = max(dot(perturbedNormal, lightDir), 0.0);
    
    // Soft upward bounce light from the hardwood court
    vec3 bounceLightDir = normalize(vec3(0.0, -0.85, 0.50));
    float bounceDiff = max(dot(perturbedNormal, bounceLightDir), 0.0) * 0.16;
    
    // Ambient + Diffuse illumination
    vec3 litColor = baseColor * (0.34 + 0.66 * diff + bounceDiff);
    
    // Specular reflections
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 reflectDir = reflect(-lightDir, perturbedNormal);
    float specDot = max(dot(viewDir, reflectDir), 0.0);
    
    // A. Broad soft matte sheen (characteristic of composite microfiber leather)
    float broadSheen = pow(specDot, 10.0) * 0.09 * (1.0 - seamMask);
    
    // B. Sharp micro-glint highlights on individual pebble tops
    float pebbleGlint = pow(specDot, 36.0) * pebbleBump * 0.24;
    
    vec3 finalColor = litColor + vec3(broadSheen + pebbleGlint);
    
    // Smooth anti-aliased edge
    float alpha = smoothstep(1.0, 0.985, radius);
    fragColor = vec4(finalColor * alpha, alpha);
}
