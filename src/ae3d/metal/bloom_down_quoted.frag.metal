// bloom_down: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 texel;
    int first;
    float exposure;
    float threshold;
    char ae_pad0[12];
};
static_assert(sizeof(ae_Params) == 32, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, texel) == 0, "ae_Params.texel: std140");
static_assert(__builtin_offsetof(ae_Params, first) == 8, "ae_Params.first: std140");
static_assert(__builtin_offsetof(ae_Params, exposure) == 12, "ae_Params.exposure: std140");
static_assert(__builtin_offsetof(ae_Params, threshold) == 16, "ae_Params.threshold: std140");

struct ae_bloom_down_in {
    float2 uv [[user(locn0)]];
};

struct ae_bloom_down_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_bloom_tap(texture2d<float> screen, sampler ae_smp_screen, float2 uv, float2 texel, float2 offset) {
    return screen.sample(ae_smp_screen, (uv + offset * texel)).rgb;
}

static float ae3d_shaders_bloom_luma(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

static float3 ae3d_shaders_bloom_group(int first, float3 a, float3 b, float3 c, float3 d) {
    if (first == 0) {
        return (a + b + c + d) * 0.25;
    }
    float wa = 1.0 / (1.0 + ae3d_shaders_bloom_luma(a));
    float wb = 1.0 / (1.0 + ae3d_shaders_bloom_luma(b));
    float wc = 1.0 / (1.0 + ae3d_shaders_bloom_luma(c));
    float wd = 1.0 / (1.0 + ae3d_shaders_bloom_luma(d));
    return (a * wa + b * wb + c * wc + d * wd) / (wa + wb + wc + wd);
}

static float3 ae3d_shaders_bloom_past_threshold(float3 c, float exposure, float threshold) {
    float light = ae3d_shaders_bloom_luma(c) * exposure;
    float knee = max(threshold * 0.5, 0.0001);
    float soft = clamp(light - threshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float over = max(soft, light - threshold) / max(light, 0.0001);
    return c * over;
}

fragment ae_bloom_down_frag_out ae_bloom_down_fragment(
    ae_bloom_down_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]]) {
    ae_bloom_down_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float2& texel = ae_params.texel;
    constant int& first = ae_params.first;
    constant float& exposure = ae_params.exposure;
    constant float& threshold = ae_params.threshold;
    float3 a = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-2.0, -2.0));
    float3 b = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, -2.0));
    float3 c = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(2.0, -2.0));
    float3 d = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-1.0, -1.0));
    float3 e = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(1.0, -1.0));
    float3 f = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-2.0, 0.0));
    float3 g = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, 0.0));
    float3 h = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(2.0, 0.0));
    float3 i = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-1.0, 1.0));
    float3 j = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(1.0, 1.0));
    float3 k = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(-2.0, 2.0));
    float3 l = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(0.0, 2.0));
    float3 m = ae3d_shaders_bloom_tap(screen, ae_smp_screen, uv, texel, float2(2.0, 2.0));
    float3 sum = ae3d_shaders_bloom_group(first, d, e, i, j) * 0.5 + ae3d_shaders_bloom_group(first, a, b, f, g) * 0.125 + ae3d_shaders_bloom_group(first, b, c, g, h) * 0.125 + ae3d_shaders_bloom_group(first, f, g, k, l) * 0.125 + ae3d_shaders_bloom_group(first, g, h, l, m) * 0.125;
    if (first != 0) {
        sum = ae3d_shaders_bloom_past_threshold(sum, exposure, threshold);
    }
    ae_out.FragColor = float4(sum, 1.0);
    return ae_out;
}
