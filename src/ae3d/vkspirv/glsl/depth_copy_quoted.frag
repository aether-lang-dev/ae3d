#version 450
// depth_copy: written by ae3d.gpu from its quote.

layout(set = 0, binding = 0) uniform sampler2D depth;

layout(location = 0) in vec2 uv;

void main() {
    gl_FragDepth = texelFetch(depth, ivec2(gl_FragCoord.xy), 0).x;
}
