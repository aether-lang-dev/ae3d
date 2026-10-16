#version 450
// depth_resolve: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    int samples;
};
layout(set = 0, binding = 1) uniform sampler2DMS depth;

layout(location = 0) in vec2 uv;

void main() {
    float nearest = 1.0;
    int s = 0;
    while (s < samples) {
        nearest = min(nearest, texelFetch(depth, ivec2(gl_FragCoord.xy), s).x);
        s = s + 1;
    }
    gl_FragDepth = nearest;
}
