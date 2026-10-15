#version 410 core
// depth_copy: written by ae3d.gpu from its quote.

uniform sampler2D depth;

in vec2 uv;

void main() {
    gl_FragDepth = texelFetch(depth, ivec2(gl_FragCoord.xy), 0).x;
}
