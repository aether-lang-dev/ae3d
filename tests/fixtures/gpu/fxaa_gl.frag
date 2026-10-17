#version 410 core
// fxaa: written by ae3d.gpu from its quote.

uniform vec2 texel;
uniform float edge_min;
uniform float edge;
uniform float subpixel;
uniform sampler2D screen;

float ae3d_shaders_fxaa_luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec3 c = texture(screen, uv).rgb;
    vec3 n = texture(screen, uv + vec2(0.0, -1.0) * texel).rgb;
    vec3 s = texture(screen, uv + vec2(0.0, 1.0) * texel).rgb;
    vec3 e = texture(screen, uv + vec2(1.0, 0.0) * texel).rgb;
    vec3 w = texture(screen, uv + vec2(-1.0, 0.0) * texel).rgb;
    float lc = ae3d_shaders_fxaa_luma(c);
    float ln = ae3d_shaders_fxaa_luma(n);
    float ls = ae3d_shaders_fxaa_luma(s);
    float le = ae3d_shaders_fxaa_luma(e);
    float lw = ae3d_shaders_fxaa_luma(w);
    float lo = min(lc, min(min(ln, ls), min(le, lw)));
    float hi = max(lc, max(max(ln, ls), max(le, lw)));
    float range = hi - lo;
    if (range < max(edge_min, hi * edge)) {
        FragColor = vec4(c, 1.0);
        return;
    }
    float avg = (ln + ls + le + lw) * 0.25;
    float blend = smoothstep(0.0, 1.0, clamp(abs(avg - lc) / range, 0.0, 1.0));
    blend = blend * blend * subpixel;
    float horiz = abs(-2.0 * lw + lc) + abs(-2.0 * lc + le) * 2.0 + abs(-2.0 * le + lc);
    float vert = abs(-2.0 * ln + lc) + abs(-2.0 * lc + ls) * 2.0 + abs(-2.0 * ls + lc);
    bool along = horiz >= vert;
    float g1 = (along ? ls : le) - lc;
    float g2 = (along ? ln : lw) - lc;
    float dir = abs(g1) >= abs(g2) ? sign(g1) : sign(g2);
    float step = blend * dir;
    vec2 off = along ? vec2(0.0, step * texel.y) : vec2(step * texel.x, 0.0);
    FragColor = vec4(texture(screen, uv + off).rgb, 1.0);
}
