#version 330

layout(std140) uniform DynamicTransforms {
    mat4 ModelViewMat;
    vec4 ColorModulator;
    vec3 ModelOffset;
    mat4 TextureMat;
};

uniform sampler2D Sampler0;

in vec2 texCoord0;
in vec4 vertexColor;

out vec4 fragColor;

void main() {
    // Distance field stored in alpha: 0.5 is the glyph edge, larger values are inside.
    float distance = texture(Sampler0, texCoord0).a;
    float width = max(fwidth(distance) * 0.7, 0.002);
    float coverage = smoothstep(0.5 - width, 0.5 + width, distance);
    vec4 color = vec4(vertexColor.rgb, vertexColor.a * coverage);
    if (color.a <= 0.002) {
        discard;
    }
    fragColor = color * ColorModulator;
}
