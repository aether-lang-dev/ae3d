#version 410 core
// depth_resolve: written by ae3d.gpu from its quote.

uniform int samples;
uniform sampler2DMS depth;

in vec2 uv;

void main() {
    float nearest = 1.0;
    int s = 0;
    while (s < samples) {
        nearest = min(nearest, texelFetch(depth, ivec2(gl_FragCoord.xy), s).x);
        s = s + 1;
    }
    gl_FragDepth = nearest;
}
