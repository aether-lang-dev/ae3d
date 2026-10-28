// world_text: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 jitter;
    char ae_pad0[8];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, jitter) == 0, "ae_Params.jitter: std140");

struct ae_world_text_in {
    float2 uv [[user(locn0)]];
    float3 colour [[user(locn1)]];
    float alpha [[user(locn2)]];
    float4 clip_now [[user(locn3)]];
    float4 clip_prev [[user(locn4)]];
};

struct ae_world_text_frag_out {
    float4 out_colour [[color(0)]];
    float4 out_velocity [[color(1)]];
};

static float ae3d_shaders_lettering_coverage(float d, float w) {
    float reach = max(w * 0.5, 0.00001);
    return smoothstep(0.5 - reach, 0.5 + reach, d);
}

static float ae3d_shaders_skydome_aces_inverse(float y_in) {
    float y = clamp(y_in, 0.0, 0.9999);
    float a = 2.51 - 2.43 * y;
    float b = 0.03 - 0.59 * y;
    return (-b + sqrt(b * b + 4.0 * a * 0.14 * y)) / (2.0 * a);
}

static float ae3d_shaders_skydome_srgb_decode(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

static float3 ae3d_shaders_skydome_display_radiance(float3 shown) {
    float3 c = clamp(shown, float3(0.0), float3(1.0));
    return float3(ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.x)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.y)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.z)));
}

static float2 ae3d_shaders_skydome_velocity(float4 now, float4 prev, float2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) {
        return float2(0.0);
    }
    float2 uv_now = now.xy / now.w * 0.5 + float2(0.5) - nudge;
    float2 uv_prev = prev.xy / prev.w * 0.5 + float2(0.5);
    return uv_now - uv_prev;
}

fragment ae_world_text_frag_out ae_world_text_fragment(
    ae_world_text_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> atlas [[texture(0)]], sampler ae_smp_atlas [[sampler(0)]]) {
    ae_world_text_frag_out ae_out;
    float2 uv = ae_in.uv;
    float3 colour = ae_in.colour;
    float alpha = ae_in.alpha;
    float4 clip_now = ae_in.clip_now;
    float4 clip_prev = ae_in.clip_prev;
    constant float2& jitter = ae_params.jitter;
    float d = atlas.sample(ae_smp_atlas, uv).x;
    float w = abs(dfdx(d)) + abs(dfdy(d));
    float a = ae3d_shaders_lettering_coverage(d, w) * alpha;
    if (a < 0.002) {
        discard_fragment();
    }
    ae_out.out_colour = float4(ae3d_shaders_skydome_display_radiance(colour), a);
    ae_out.out_velocity = float4(ae3d_shaders_skydome_velocity(clip_now, clip_prev, jitter), 0.0, 0.0);
    return ae_out;
}
