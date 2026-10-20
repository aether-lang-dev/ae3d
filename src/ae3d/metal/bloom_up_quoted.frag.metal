// bloom_up: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 texel;
    float top;
    char ae_pad0[4];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, texel) == 0, "ae_Params.texel: std140");
static_assert(__builtin_offsetof(ae_Params, top) == 8, "ae_Params.top: std140");

struct ae_bloom_up_in {
    float2 uv [[user(locn0)]];
};

struct ae_bloom_up_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_bloom_tap(texture2d<float> screen, sampler ae_smp_screen, float2 uv, float2 texel, float2 offset) {
    return screen.sample(ae_smp_screen, (uv + offset * texel)).rgb;
}

fragment ae_bloom_up_frag_out ae_bloom_up_fragment(
    ae_bloom_up_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]],
    texture2d<float> level_ [[texture(1)]], sampler ae_smp_level_ [[sampler(1)]]) {
    ae_bloom_up_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float2& texel = ae_params.texel;
    constant float& top = ae_params.top;
    float3 tent = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, 0.0)) * 4.0 + (ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(1.0, 0.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, -1.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, 1.0))) * 2.0 + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(1.0, -1.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-1.0, 1.0)) + ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(1.0, 1.0));
    float3 sum = level_.sample(ae_smp_level_, uv).rgb + tent / 16.0;
    if (top > 0.0) {
        sum = sum / top;
    }
    ae_out.FragColor = float4(sum, 1.0);
    return ae_out;
}
