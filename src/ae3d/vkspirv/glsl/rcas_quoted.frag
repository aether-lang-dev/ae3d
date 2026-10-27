#version 450
// rcas: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    vec2 size;
    float sharpness;
};
layout(set = 0, binding = 1) uniform sampler2D screen;

vec3 ae3d_shaders_upscale_root3(vec3 c) {
    return vec3(sqrt(max(c.x, 0.0)), sqrt(max(c.y, 0.0)), sqrt(max(c.z, 0.0)));
}

vec3 ae3d_shaders_upscale_tap_root(sampler2D screen, vec2 p, vec2 size) {
    vec2 q = clamp(p, vec2(0.0, 0.0), size - vec2(1.0, 1.0));
    return ae3d_shaders_upscale_root3(texelFetch(screen, ivec2(q), 0).rgb);
}

float ae3d_shaders_upscale_sharpen_channel(float c, float n, float e, float s, float w, float lobe) {
    float mn = min(c, min(min(n, e), min(s, w)));
    float mx = max(c, max(max(n, e), max(s, w)));
    float range = mx - mn;
    float hi = mx + range * 0.1;
    float lo = max(mn - range * 0.25, 0.0);
    float around = n + e + s + w;
    float up = (hi - c) / max(4.0 * hi - around, 0.00000001);
    float down = 1000.0;
    if (around - 4.0 * lo > 0.00000001) {
        down = (c - lo) / (around - 4.0 * lo);
    }
    float l = max(min(lobe, min(up, down)), 0.0);
    return (c - l * around) / (1.0 - 4.0 * l);
}

vec3 ae3d_shaders_upscale_square3(vec3 c) {
    return vec3(c.x * c.x, c.y * c.y, c.z * c.z);
}

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

void main() {
    vec2 p = gl_FragCoord.xy - vec2(0.5, 0.5);
    vec3 c = ae3d_shaders_upscale_tap_root(screen, p, size);
    vec3 n = ae3d_shaders_upscale_tap_root(screen, p + vec2(0.0, -1.0), size);
    vec3 e = ae3d_shaders_upscale_tap_root(screen, p + vec2(1.0, 0.0), size);
    vec3 s = ae3d_shaders_upscale_tap_root(screen, p + vec2(0.0, 1.0), size);
    vec3 w = ae3d_shaders_upscale_tap_root(screen, p + vec2(-1.0, 0.0), size);
    float lobe = clamp(sharpness, 0.0, 1.0) * 0.2;
    float r = ae3d_shaders_upscale_sharpen_channel(c.x, n.x, e.x, s.x, w.x, lobe);
    float g = ae3d_shaders_upscale_sharpen_channel(c.y, n.y, e.y, s.y, w.y, lobe);
    float b = ae3d_shaders_upscale_sharpen_channel(c.z, n.z, e.z, s.z, w.z, lobe);
    FragColor = vec4(ae3d_shaders_upscale_square3(vec3(r, g, b)), 1.0);
}
