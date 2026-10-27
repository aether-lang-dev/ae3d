// rcas: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 size;
    float sharpness;
    char ae_pad0[4];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, size) == 0, "ae_Params.size: std140");
static_assert(__builtin_offsetof(ae_Params, sharpness) == 8, "ae_Params.sharpness: std140");

struct ae_rcas_in {
    float4 ae_frag_coord [[position]];
};

struct ae_rcas_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_upscale_root3(float3 c) {
    return float3(sqrt(max(c.x, 0.0)), sqrt(max(c.y, 0.0)), sqrt(max(c.z, 0.0)));
}

static float3 ae3d_shaders_upscale_tap_root(texture2d<float> screen, sampler ae_smp_screen, float2 p, float2 size) {
    float2 q = clamp(p, float2(0.0, 0.0), size - float2(1.0, 1.0));
    return ae3d_shaders_upscale_root3(screen.read(uint2(int2(q)), 0).rgb);
}

static float ae3d_shaders_upscale_sharpen_channel(float c, float n, float e, float s, float w, float lobe) {
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

static float3 ae3d_shaders_upscale_square3(float3 c) {
    return float3(c.x * c.x, c.y * c.y, c.z * c.z);
}

fragment ae_rcas_frag_out ae_rcas_fragment(
    ae_rcas_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]]) {
    ae_rcas_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant float2& size = ae_params.size;
    constant float& sharpness = ae_params.sharpness;
    float2 p = ae_frag_coord.xy - float2(0.5, 0.5);
    float3 c = ae3d_shaders_upscale_tap_root(screen, ae_smp_screen, p, size);
    float3 n = ae3d_shaders_upscale_tap_root(screen, ae_smp_screen, p + float2(0.0, -1.0), size);
    float3 e = ae3d_shaders_upscale_tap_root(screen, ae_smp_screen, p + float2(1.0, 0.0), size);
    float3 s = ae3d_shaders_upscale_tap_root(screen, ae_smp_screen, p + float2(0.0, 1.0), size);
    float3 w = ae3d_shaders_upscale_tap_root(screen, ae_smp_screen, p + float2(-1.0, 0.0), size);
    float lobe = clamp(sharpness, 0.0, 1.0) * 0.2;
    float r = ae3d_shaders_upscale_sharpen_channel(c.x, n.x, e.x, s.x, w.x, lobe);
    float g = ae3d_shaders_upscale_sharpen_channel(c.y, n.y, e.y, s.y, w.y, lobe);
    float b = ae3d_shaders_upscale_sharpen_channel(c.z, n.z, e.z, s.z, w.z, lobe);
    ae_out.FragColor = float4(ae3d_shaders_upscale_square3(float3(r, g, b)), 1.0);
    return ae_out;
}
