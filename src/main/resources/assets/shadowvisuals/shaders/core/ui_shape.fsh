#version 330

layout(std140) uniform DynamicTransforms {
    mat4 ModelViewMat;
    vec4 ColorModulator;
    vec3 ModelOffset;
    mat4 TextureMat;
};

in vec4 vertexColor;
in vec2 localPos;
flat in vec2 halfSize;
flat in vec2 shapeParams;

out vec4 fragColor;

// Signed distance to a rounded box centered at the origin.
float roundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float radius = clamp(shapeParams.x, 0.0, min(halfSize.x, halfSize.y));
    float dist = roundedBox(localPos, halfSize, radius);
    // Width of one screen pixel in GUI units: keeps edges anti-aliased at every GUI scale.
    float pixel = max(fwidth(dist), 1e-4);
    float mode = shapeParams.y;
    float coverage;
    if (mode < 0.0) {
        float softness = -mode;
        float t = clamp((dist + softness * 0.35) / (softness * 1.35), 0.0, 1.0);
        coverage = (1.0 - t) * (1.0 - t);
    } else if (mode > 0.0) {
        float outer = clamp(0.5 - dist / pixel, 0.0, 1.0);
        float inner = clamp(0.5 - (dist + mode) / pixel, 0.0, 1.0);
        coverage = outer - inner;
    } else {
        coverage = clamp(0.5 - dist / pixel, 0.0, 1.0);
    }
    vec4 color = vec4(vertexColor.rgb, vertexColor.a * coverage);
    if (color.a <= 0.001) {
        discard;
    }
    fragColor = color * ColorModulator;
}
