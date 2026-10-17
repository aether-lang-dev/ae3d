#version 410 core
// ssr: written by ae3d.gpu from its quote.

uniform float strength;
uniform mat4 inv_view_projection;
uniform vec3 view_pos;
uniform float road_height;
uniform mat4 view_projection;
uniform sampler2D screen;
uniform sampler2D depth;
uniform sampler2D blur;

vec3 ae3d_shaders_ssao_world_at(mat4 inv_view_projection, vec2 uv, float depth) {
    vec4 world = (inv_view_projection * vec4(vec3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, (depth * 2.0 - 1.0)), 1.0));
    return world.xyz / world.w;
}

float ae3d_shaders_ssr_hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ae3d_shaders_ssr_value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (vec2(3.0, 3.0) - f * 2.0);
    return mix(mix(ae3d_shaders_ssr_hash2(i), ae3d_shaders_ssr_hash2(i + vec2(1.0, 0.0)), f.x), mix(ae3d_shaders_ssr_hash2(i + vec2(0.0, 1.0)), ae3d_shaders_ssr_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ae3d_shaders_ssr_puddle(vec2 xz) {
    float n = ae3d_shaders_ssr_value_noise(xz * 0.35) * 0.6 + ae3d_shaders_ssr_value_noise(xz * 0.9) * 0.3 + ae3d_shaders_ssr_value_noise(xz * 2.7) * 0.1;
    return smoothstep(0.55, 0.62, n);
}

vec3 ae3d_shaders_ssr_reflection_at(sampler2D screen, sampler2D blur, vec2 uv, float radius, vec2 seed) {
    if (radius < 0.0005) {
        return texture(screen, uv).rgb;
    }
    float turn = ae3d_shaders_ssr_hash2(seed) * 6.2831853;
    float c = cos(turn);
    float s = sin(turn);
    vec2 size = vec2(textureSize(screen, 0));
    vec2 aspect = vec2(1.0, size.x / size.y);
    bool wide = radius * size.x > 8.0;
    vec3 sum = vec3(0.0, 0.0, 0.0);
    float i = 0.0;
    while (i < 8.0) {
        float a = i * 0.7853982;
        float r = radius * (0.35 + 0.65 * (i + 1.0) / 8.0);
        vec2 d = vec2(cos(a), sin(a)) * r;
        d = vec2(d.x * c - d.y * s, d.x * s + d.y * c) * aspect;
        vec2 at = clamp(uv + d, vec2(0.001, 0.001), vec2(0.999, 0.999));
        sum = sum + (wide ? texture(blur, at).rgb : texture(screen, at).rgb);
        i = i + 1.0;
    }
    return sum * 0.125;
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec3 scene = texture(screen, uv).rgb;
    if (strength <= 0.0) {
        FragColor = vec4(scene, 1.0);
        return;
    }
    vec3 p = ae3d_shaders_ssao_world_at(inv_view_projection, uv, texture(depth, uv).x);
    vec2 size = vec2(textureSize(depth, 0));
    vec2 texel = vec2(1.0 / size.x, 1.0 / size.y);
    vec4 here = (inv_view_projection * vec4(vec3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, 0.0), 1.0));
    vec4 next = (inv_view_projection * vec4(vec3((uv.x + texel.x) * 2.0 - 1.0, (uv.y + texel.y) * 2.0 - 1.0, 0.0), 1.0));
    float pixel_angle = length(normalize(next.xyz / next.w - view_pos) - normalize(here.xyz / here.w - view_pos));
    float tolerance = 0.06 + distance(view_pos, p) * pixel_angle;
    if (abs(p.y - road_height) > tolerance) {
        FragColor = vec4(scene, 1.0);
        return;
    }
    vec3 v = normalize(p - view_pos);
    vec3 r = reflect(v, vec3(0.0, 1.0, 0.0));
    float cos_look = clamp(-v.y, 0.0, 1.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - cos_look, 5.0);
    float pool = ae3d_shaders_ssr_puddle(vec2(p.x, p.z));
    float wet = mix(0.6, 1.0, pool);
    float rough = mix(0.35, 0.02, pool);
    float step_len = 0.25;
    vec3 pos = p + r * step_len;
    vec3 prev = p;
    vec3 hit = scene;
    float edge_fade = 0.0;
    int i = 0;
    while (i < 64) {
        vec4 clip = (view_projection * vec4(pos, 1.0));
        if (clip.w <= 0.0) {
            break;
        }
        vec2 suv = vec2(clip.x / clip.w * 0.5 + 0.5, clip.y / clip.w * 0.5 + 0.5);
        if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
            break;
        }
        float behind = distance(view_pos, pos) - distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, suv, texture(depth, suv).x));
        if (behind > 0.03 && behind < step_len * 2.0 + 0.2) {
            vec3 lo = prev;
            vec3 hi = pos;
            int k = 0;
            while (k < 4) {
                vec3 mid = (lo + hi) * 0.5;
                vec4 mclip = (view_projection * vec4(mid, 1.0));
                vec2 muv = vec2(mclip.x / mclip.w * 0.5 + 0.5, mclip.y / mclip.w * 0.5 + 0.5);
                if (distance(view_pos, mid) > distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, muv, texture(depth, muv).x))) {
                    hi = mid;
                } else {
                    lo = mid;
                }
                k = k + 1;
            }
            vec4 hclip = (view_projection * vec4(hi, 1.0));
            vec2 huv = vec2(hclip.x / hclip.w * 0.5 + 0.5, hclip.y / hclip.w * 0.5 + 0.5);
            float travelled = distance(p, hi);
            float radius = min(rough * travelled / max(distance(view_pos, hi), 0.5) * 0.35, 0.06);
            hit = ae3d_shaders_ssr_reflection_at(screen, blur, huv, radius, uv * 1024.0);
            float edge = min(min(huv.x, 1.0 - huv.x), min(huv.y, 1.0 - huv.y));
            edge_fade = clamp(edge * 8.0, 0.0, 1.0);
            break;
        }
        prev = pos;
        pos = pos + r * step_len;
        step_len = step_len * 1.05;
        i = i + 1;
    }
    FragColor = vec4(scene + hit * (strength * fresnel * wet * edge_fade), 1.0);
}
