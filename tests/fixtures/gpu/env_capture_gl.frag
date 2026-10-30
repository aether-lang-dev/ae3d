#version 410 core
// env_capture: written by ae3d.gpu from its quote.

uniform float half_v;
uniform float yaw;
uniform float lod;
uniform float intensity;
uniform sampler2D env;

vec3 ae3d_shaders_skyprobe_oct_decode(vec2 p) {
    vec3 d = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        d = vec3((1.0 - abs(d.z)) * (d.x >= 0.0 ? 1.0 : -1.0), d.y, (1.0 - abs(d.x)) * (d.z >= 0.0 ? 1.0 : -1.0));
    }
    return normalize(d);
}

vec3 ae3d_shaders_skyprobe_oct_texel_direction(vec2 uv, float size) {
    float px = (uv.x * size - 1.0) / (size - 2.0) * 2.0 - 1.0;
    float py = (uv.y * size - 1.0) / (size - 2.0) * 2.0 - 1.0;
    if (px > 1.0) {
        px = 2.0 - px;
        py = -py;
    }
    if (px < -1.0) {
        px = -2.0 - px;
        py = -py;
    }
    if (py > 1.0) {
        py = 2.0 - py;
        px = -px;
    }
    if (py < -1.0) {
        py = -2.0 - py;
        px = -px;
    }
    return ae3d_shaders_skyprobe_oct_decode(vec2(px, py));
}

vec2 ae3d_shaders_envmap_equirect_uv(vec3 d, float half_v, float yaw) {
    float u = (atan(d.z, d.x) + 3.14159265 - yaw) / 6.28318531;
    float v = (asin(clamp(d.y, -1.0, 1.0)) + 1.57079633) / 3.14159265;
    return vec2(u, clamp(v, half_v, 1.0 - half_v));
}

in vec2 uv_in;
out vec4 FragColor;

void main() {
    vec2 fc = gl_FragCoord.xy;
    vec3 dir = ae3d_shaders_skyprobe_oct_texel_direction(vec2(fc.x / 256.0, fc.y / 256.0), 256.0);
    vec3 light = textureLod(env, ae3d_shaders_envmap_equirect_uv(dir, half_v, yaw), lod).rgb;
    FragColor = vec4(max(light * intensity, vec3(0.0)), 1.0);
}
