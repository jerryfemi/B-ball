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
    
    // --- 2. Authentic Composite Leather Color Grading ---
    // Deep Wilson / Spalding composite orange palette
    vec3 leatherDark = vec3(0.70, 0.27, 0.03);  // Deep burnt sienna
    vec3 leatherMid  = vec3(0.88, 0.40, 0.08);  // Warm composite orange body
    vec3 leatherPeak = vec3(0.96, 0.48, 0.12);  // Highlight tops
    
    // Smooth leather tonal falloff based on sphere curvature and seam proximity
    vec3 leatherColor = mix(leatherMid, leatherPeak, normal.z * 0.35);
    leatherColor += vec3(0.06, 0.03, 0.01) * seamRidge;
    
    // Matte charcoal black rubber seam with subtle edge gradient
    vec3 rubberSeamColor = vec3(0.12, 0.12, 0.12);
    vec3 baseColor = mix(leatherColor, rubberSeamColor, seamMask);
    
    // --- 3. Recessed Seam Normal (subtle groove shading) ---
    vec3 perturbedNormal = normal;
    if (seamMask > 0.05) {
        perturbedNormal = normalize(normal - spherePos * seamMask * 0.2);
    }
    
    // --- 4. Volumetric Arena Lighting & Dual Specular ---
    // Overhead arena floodlight: top-left and slightly in front
    vec3 lightDir = normalize(vec3(-0.25, 0.92, 0.65));
    float diff = max(dot(perturbedNormal, lightDir), 0.0);
    
    // Soft upward bounce light from the hardwood court
    vec3 bounceLightDir = normalize(vec3(0.0, -0.85, 0.50));
    float bounceDiff = max(dot(perturbedNormal, bounceLightDir), 0.0) * 0.16;
    
    // Ambient + Diffuse illumination
    vec3 litColor = baseColor * (0.34 + 0.66 * diff + bounceDiff);
    
    // Specular reflections: Fast power-of-4 and power-of-16 calculations
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 reflectDir = reflect(-lightDir, perturbedNormal);
    float specDot = max(dot(viewDir, reflectDir), 0.0);
    float spec2 = specDot * specDot;
    float spec4 = spec2 * spec2;
    float spec16 = spec4 * spec4;
    
    // Soft sheen + focused highlight
    float sheen = (spec4 * 0.08 + spec16 * 0.14) * (1.0 - seamMask);
    
    vec3 finalColor = litColor + vec3(sheen);
    
    // Smooth anti-aliased edge
    float alpha = smoothstep(1.0, 0.985, radius);
    fragColor = vec4(finalColor * alpha, alpha);
}
