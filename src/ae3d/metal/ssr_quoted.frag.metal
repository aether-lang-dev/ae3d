// ssr: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float strength;
    char ae_pad0[12];
    float4x4 inv_view_projection;
    packed_float3 view_pos;
    float road_height;
    float4x4 view_projection;
};
static_assert(sizeof(ae_Params) == 160, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, strength) == 0, "ae_Params.strength: std140");
static_assert(__builtin_offsetof(ae_Params, inv_view_projection) == 16, "ae_Params.inv_view_projection: std140");
static_assert(__builtin_offsetof(ae_Params, view_pos) == 80, "ae_Params.view_pos: std140");
static_assert(__builtin_offsetof(ae_Params, road_height) == 92, "ae_Params.road_height: std140");
static_assert(__builtin_offsetof(ae_Params, view_projection) == 96, "ae_Params.view_projection: std140");

struct ae_ssr_in {
    float2 uv [[user(locn0)]];
};

struct ae_ssr_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_ssao_world_at(float4x4 inv_view_projection, float2 uv, float depth) {
    float4 world = (inv_view_projection * float4(float3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, depth), 1.0));
    return world.xyz / world.w;
}

static float ae3d_shaders_ssr_hash2(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float ae3d_shaders_ssr_value_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (float2(3.0, 3.0) - f * 2.0);
    return mix(mix(ae3d_shaders_ssr_hash2(i), ae3d_shaders_ssr_hash2(i + float2(1.0, 0.0)), f.x), mix(ae3d_shaders_ssr_hash2(i + float2(0.0, 1.0)), ae3d_shaders_ssr_hash2(i + float2(1.0, 1.0)), f.x), f.y);
}

static float ae3d_shaders_ssr_puddle(float2 xz) {
    float n = ae3d_shaders_ssr_value_noise(xz * 0.35) * 0.6 + ae3d_shaders_ssr_value_noise(xz * 0.9) * 0.3 + ae3d_shaders_ssr_value_noise(xz * 2.7) * 0.1;
    return smoothstep(0.55, 0.62, n);
}

static float3 ae3d_shaders_ssr_reflection_at(texture2d<float> screen, sampler ae_smp_screen, texture2d<float> blur, sampler ae_smp_blur, float2 uv, float radius, float2 seed) {
    if (radius < 0.0005) {
        return screen.sample(ae_smp_screen, uv).rgb;
    }
    float turn = ae3d_shaders_ssr_hash2(seed) * 6.2831853;
    float c = cos(turn);
    float s = sin(turn);
    float2 size = float2(float(screen.get_width()), float(screen.get_height()));
    float2 aspect = float2(1.0, size.x / size.y);
    bool wide = radius * size.x > 8.0;
    float3 sum = float3(0.0, 0.0, 0.0);
    float i = 0.0;
    while (i < 8.0) {
        float a = i * 0.7853982;
        float r = radius * (0.35 + 0.65 * (i + 1.0) / 8.0);
        float2 d = float2(cos(a), sin(a)) * r;
        d = float2(d.x * c - d.y * s, d.x * s + d.y * c) * aspect;
        float2 at = clamp(uv + d, float2(0.001, 0.001), float2(0.999, 0.999));
        sum = sum + (wide ? blur.sample(ae_smp_blur, at).rgb : screen.sample(ae_smp_screen, at).rgb);
        i = i + 1.0;
    }
    return sum * 0.125;
}

fragment ae_ssr_frag_out ae_ssr_fragment(
    ae_ssr_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]],
    texture2d<float> depth [[texture(1)]], sampler ae_smp_depth [[sampler(1)]],
    texture2d<float> blur [[texture(2)]], sampler ae_smp_blur [[sampler(2)]]) {
    ae_ssr_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float& strength = ae_params.strength;
    constant float4x4& inv_view_projection = ae_params.inv_view_projection;
    constant packed_float3& view_pos = ae_params.view_pos;
    constant float& road_height = ae_params.road_height;
    constant float4x4& view_projection = ae_params.view_projection;
    float3 scene = screen.sample(ae_smp_screen, uv).rgb;
    if (strength <= 0.0) {
        ae_out.FragColor = float4(scene, 1.0);
        return ae_out;
    }
    float3 p = ae3d_shaders_ssao_world_at(inv_view_projection, uv, depth.sample(ae_smp_depth, uv).x);
    float2 size = float2(float(depth.get_width()), float(depth.get_height()));
    float2 texel = float2(1.0 / size.x, 1.0 / size.y);
    float4 here = (inv_view_projection * float4(float3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, 0.0), 1.0));
    float4 next = (inv_view_projection * float4(float3((uv.x + texel.x) * 2.0 - 1.0, (uv.y + texel.y) * 2.0 - 1.0, 0.0), 1.0));
    float pixel_angle = length(normalize(next.xyz / next.w - view_pos) - normalize(here.xyz / here.w - view_pos));
    float tolerance = 0.06 + distance(view_pos, p) * pixel_angle;
    if (abs(p.y - road_height) > tolerance) {
        ae_out.FragColor = float4(scene, 1.0);
        return ae_out;
    }
    float3 v = normalize(p - view_pos);
    float3 r = reflect(v, float3(0.0, 1.0, 0.0));
    float cos_look = clamp(-v.y, 0.0, 1.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - cos_look, 5.0);
    float pool = ae3d_shaders_ssr_puddle(float2(p.x, p.z));
    float wet = mix(0.6, 1.0, pool);
    float rough = mix(0.35, 0.02, pool);
    float step_len = 0.25;
    float3 pos = p + r * step_len;
    float3 prev = p;
    float3 hit = scene;
    float edge_fade = 0.0;
    int i = 0;
    while (i < 64) {
        float4 clip = (view_projection * float4(pos, 1.0));
        if (clip.w <= 0.0) {
            break;
        }
        float2 suv = float2(clip.x / clip.w * 0.5 + 0.5, clip.y / clip.w * 0.5 + 0.5);
        if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
            break;
        }
        float behind = distance(view_pos, pos) - distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, suv, depth.sample(ae_smp_depth, suv).x));
        if (behind > 0.03 && behind < step_len * 2.0 + 0.2) {
            float3 lo = prev;
            float3 hi = pos;
            int k = 0;
            while (k < 4) {
                float3 mid = (lo + hi) * 0.5;
                float4 mclip = (view_projection * float4(mid, 1.0));
                float2 muv = float2(mclip.x / mclip.w * 0.5 + 0.5, mclip.y / mclip.w * 0.5 + 0.5);
                if (distance(view_pos, mid) > distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, muv, depth.sample(ae_smp_depth, muv).x))) {
                    hi = mid;
                } else {
                    lo = mid;
                }
                k = k + 1;
            }
            float4 hclip = (view_projection * float4(hi, 1.0));
            float2 huv = float2(hclip.x / hclip.w * 0.5 + 0.5, hclip.y / hclip.w * 0.5 + 0.5);
            float travelled = distance(p, hi);
            float radius = min(rough * travelled / max(distance(view_pos, hi), 0.5) * 0.35, 0.06);
            hit = ae3d_shaders_ssr_reflection_at(screen, ae_smp_screen, blur, ae_smp_blur, huv, radius, uv * 1024.0);
            float edge = min(min(huv.x, 1.0 - huv.x), min(huv.y, 1.0 - huv.y));
            edge_fade = clamp(edge * 8.0, 0.0, 1.0);
            break;
        }
        prev = pos;
        pos = pos + r * step_len;
        step_len = step_len * 1.05;
        i = i + 1;
    }
    ae_out.FragColor = float4(scene + hit * (strength * fresnel * wet * edge_fade), 1.0);
    return ae_out;
}
