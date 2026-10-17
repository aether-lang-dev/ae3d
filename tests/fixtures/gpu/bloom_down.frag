#version 450
// bloom_down: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    vec2 texel;
    int first;
    float exposure;
    float threshold;
};
layout(set = 0, binding = 1) uniform sampler2D screen;

vec3 ae3d_shaders_bloom_tap(sampler2D screen, vec2 uv, vec2 texel, vec2 offset) {
    return texture(screen, uv + offset * texel).rgb;
}

float ae3d_shaders_bloom_luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 ae3d_shaders_bloom_group(int first, vec3 a, vec3 b, vec3 c, vec3 d) {
    if (first == 0) {
        return (a + b + c + d) * 0.25;
    }
    float wa = 1.0 / (1.0 + ae3d_shaders_bloom_luma(a));
    float wb = 1.0 / (1.0 + ae3d_shaders_bloom_luma(b));
    float wc = 1.0 / (1.0 + ae3d_shaders_bloom_luma(c));
    float wd = 1.0 / (1.0 + ae3d_shaders_bloom_luma(d));
    return (a * wa + b * wb + c * wc + d * wd) / (wa + wb + wc + wd);
}

vec3 ae3d_shaders_bloom_past_threshold(vec3 c, float exposure, float threshold) {
    float light = ae3d_shaders_bloom_luma(c) * exposure;
    float knee = max(threshold * 0.5, 0.0001);
    float soft = clamp(light - threshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float over = max(soft, light - threshold) / max(light, 0.0001);
    return c * over;
}

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

void main() {
    vec3 a = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-2.0, -2.0));
    vec3 b = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, -2.0));
    vec3 c = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(2.0, -2.0));
    vec3 d = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, -1.0));
    vec3 e = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, -1.0));
    vec3 f = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-2.0, 0.0));
    vec3 g = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 0.0));
    vec3 h = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(2.0, 0.0));
    vec3 i = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, 1.0));
    vec3 j = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, 1.0));
    vec3 k = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-2.0, 2.0));
    vec3 l = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 2.0));
    vec3 m = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(2.0, 2.0));
    vec3 sum = ae3d_shaders_bloom_group(first, d, e, i, j) * 0.5 + ae3d_shaders_bloom_group(first, a, b, f, g) * 0.125 + ae3d_shaders_bloom_group(first, b, c, g, h) * 0.125 + ae3d_shaders_bloom_group(first, f, g, k, l) * 0.125 + ae3d_shaders_bloom_group(first, g, h, l, m) * 0.125;
    if (first != 0) {
        sum = ae3d_shaders_bloom_past_threshold(sum, exposure, threshold);
    }
    FragColor = vec4(sum, 1.0);
}
