// env_capture: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float half_v;
    float yaw;
    float lod;
    float intensity;
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, half_v) == 0, "ae_Params.half_v: std140");
static_assert(__builtin_offsetof(ae_Params, yaw) == 4, "ae_Params.yaw: std140");
static_assert(__builtin_offsetof(ae_Params, lod) == 8, "ae_Params.lod: std140");
static_assert(__builtin_offsetof(ae_Params, intensity) == 12, "ae_Params.intensity: std140");

struct ae_env_capture_in {
    float4 ae_frag_coord [[position]];
};

struct ae_env_capture_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_skyprobe_oct_decode(float2 p) {
    float3 d = float3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        d = float3((1.0 - abs(d.z)) * (d.x >= 0.0 ? 1.0 : -1.0), d.y, (1.0 - abs(d.x)) * (d.z >= 0.0 ? 1.0 : -1.0));
    }
    return normalize(d);
}

static float3 ae3d_shaders_skyprobe_oct_texel_direction(float2 uv, float size) {
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
    return ae3d_shaders_skyprobe_oct_decode(float2(px, py));
}

static float2 ae3d_shaders_envmap_equirect_uv(float3 d, float half_v, float yaw) {
    float u = (atan2(d.z, d.x) + 3.14159265 - yaw) / 6.28318531;
    float v = (asin(clamp(d.y, -1.0, 1.0)) + 1.57079633) / 3.14159265;
    return float2(u, clamp(v, half_v, 1.0 - half_v));
}

fragment ae_env_capture_frag_out ae_env_capture_fragment(
    ae_env_capture_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> env [[texture(0)]], sampler ae_smp_env [[sampler(0)]]) {
    ae_env_capture_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant float& half_v = ae_params.half_v;
    constant float& yaw = ae_params.yaw;
    constant float& lod = ae_params.lod;
    constant float& intensity = ae_params.intensity;
    float2 fc = ae_frag_coord.xy;
    float3 dir = ae3d_shaders_skyprobe_oct_texel_direction(float2(fc.x / 256.0, fc.y / 256.0), 256.0);
    float3 light = env.sample(ae_smp_env, ae3d_shaders_envmap_equirect_uv(dir, half_v, yaw), level(lod)).rgb;
    ae_out.FragColor = float4(max(light * intensity, float3(0.0)), 1.0);
    return ae_out;
}
