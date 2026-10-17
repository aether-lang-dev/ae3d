#version 450
// bloom_up: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    vec2 texel;
    float top;
};
layout(set = 0, binding = 1) uniform sampler2D screen;
layout(set = 0, binding = 2) uniform sampler2D level;

vec3 ae3d_shaders_bloom_tap(sampler2D screen, vec2 uv, vec2 texel, vec2 offset) {
    return texture(screen, uv + offset * texel).rgb;
}

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

void main() {
    vec3 tent = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 0.0)) * 4.0 + (ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 1.0))) * 2.0 + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, 1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, 1.0));
    vec3 sum = texture(level, uv).rgb + tent / 16.0;
    if (top > 0.0) {
        sum = sum / top;
    }
    FragColor = vec4(sum, 1.0);
}
