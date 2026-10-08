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
    
    // Apply rotations to get the physical point on the texture
    vec3 spherePos = rotY * rotX * normal;
    
    // --- Draw the Basketball Seams ---
    float lineThickness = 0.06;
    bool isSeam = false;
    
    // Equator seam
    if (abs(spherePos.y) < lineThickness) isSeam = true;
    // Vertical seam
    if (abs(spherePos.x) < lineThickness) isSeam = true;
    
    // The curved side seams (roughly mimicking the U-shape of a real basketball)
    // We can simulate this by checking distance from two specific points
    float distLeft = distance(spherePos.xz, vec2(-0.8, 0.0));
    float distRight = distance(spherePos.xz, vec2(0.8, 0.0));
    if (abs(distLeft - 0.6) < lineThickness) isSeam = true;
    if (abs(distRight - 0.6) < lineThickness) isSeam = true;
    
    // Base colors
    vec3 orangeColor = vec3(0.9, 0.4, 0.05); // Deep basketball orange
    vec3 seamColor = vec3(0.15, 0.15, 0.15); // Dark grey/black for lines
    
    vec3 color = isSeam ? seamColor : orangeColor;
    
    // --- 3D Lighting (Phong Shading) ---
    // The light stays fixed relative to the camera, so we use the unrotated 'normal'
    vec3 lightDir = normalize(vec3(0.5, 0.8, 1.0)); // Light coming from top-right-front
    float diff = max(dot(normal, lightDir), 0.0);
    
    // Ambient + Diffuse
    vec3 finalColor = color * (0.35 + 0.65 * diff);
    
    // Add specular highlight for rubbery shininess
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 12.0); // 12.0 is shininess factor
    finalColor += vec3(0.3) * spec; // slight white highlight
    
    // Final output with anti-aliasing on the edge
    float alpha = smoothstep(1.0, 0.98, radius);
    fragColor = vec4(finalColor * alpha, alpha);
}
