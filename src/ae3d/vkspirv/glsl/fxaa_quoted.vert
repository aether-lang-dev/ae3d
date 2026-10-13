#version 450
// fxaa's full-screen pass: written by ae3d.gpu.

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;

layout(location = 0) out vec2 uv;

void main() {
    uv = inTexCoord;
    gl_Position = vec4(inPosition.xy, 0.0, 1.0);
}
