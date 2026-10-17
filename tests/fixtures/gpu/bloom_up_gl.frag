#version 410 core
// bloom_up: written by ae3d.gpu from its quote.

uniform vec2 texel;
uniform float top;
uniform sampler2D screen;
uniform sampler2D level;

vec3 ae3d_shaders_bloom_tap(sampler2D screen, vec2 uv, vec2 texel, vec2 offset) {
    return texture(screen, uv + offset * texel).rgb;
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec3 tent = ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 0.0)) * 4.0 + (ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(0.0, 1.0))) * 2.0 + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(-1.0, 1.0)) + ae3d_shaders_bloom_tap(screen, uv, texel, vec2(1.0, 1.0));
    vec3 sum = texture(level, uv).rgb + tent / 16.0;
    if (top > 0.0) {
        sum = sum / top;
    }
    FragColor = vec4(sum, 1.0);
}
