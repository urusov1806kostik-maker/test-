#version 330

// Shadow Visuals shape shader. Uniform blocks are copied (not imported) like vanilla GUI shaders.
layout(std140) uniform DynamicTransforms {
    mat4 ModelViewMat;
    vec4 ColorModulator;
    vec3 ModelOffset;
    mat4 TextureMat;
};
layout(std140) uniform Projection {
    mat4 ProjMat;
};

in vec3 Position;
in vec4 Color;
in vec2 UV0;   // fragment position relative to the shape center, in GUI units
in ivec2 UV1;  // half size * 8
in ivec2 UV2;  // corner radius * 8, mode * 8 (0 fill, >0 outline width, <0 shadow softness)

out vec4 vertexColor;
out vec2 localPos;
flat out vec2 halfSize;
flat out vec2 shapeParams;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
    vertexColor = Color;
    localPos = UV0;
    halfSize = vec2(UV1) / 8.0;
    shapeParams = vec2(UV2) / 8.0;
}
