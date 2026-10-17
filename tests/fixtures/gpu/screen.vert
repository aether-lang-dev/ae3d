#version 450
// screen: written by ae3d.gpu from its quote.

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;

layout(location = 0) out vec2 uv;

void main() {
    gl_Position = vec4(vec3(inPosition.x, inPosition.y, 0.0), 1.0);
    uv = inTexCoord;
}
