// taa: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 screen_size;
    float blend;
    float exposure;
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, screen_size) == 0, "ae_Params.screen_size: std140");
static_assert(__builtin_offsetof(ae_Params, blend) == 8, "ae_Params.blend: std140");
static_assert(__builtin_offsetof(ae_Params, exposure) == 12, "ae_Params.exposure: std140");

struct ae_taa_in {
    float2 uv [[user(locn0)]];
};

struct ae_taa_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_taa_fold(float3 c, float exposure) {
    return c / (1.0 + dot(c * exposure, float3(0.2126, 0.7152, 0.0722)));
}

static float3 ae3d_shaders_taa_unfold(float3 c, float exposure) {
    return c / max(1.0 - dot(c * exposure, float3(0.2126, 0.7152, 0.0722)), 0.0001);
}

fragment ae_taa_frag_out ae_taa_fragment(
    ae_taa_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]],
    texture2d<float> velocity [[texture(1)]], sampler ae_smp_velocity [[sampler(1)]],
    texture2d<float> history [[texture(2)]], sampler ae_smp_history [[sampler(2)]]) {
    ae_taa_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float2& screen_size = ae_params.screen_size;
    constant float& blend = ae_params.blend;
    constant float& exposure = ae_params.exposure;
    float2 px = float2(1.0 / screen_size.x, 1.0 / screen_size.y);
    float3 current = screen.sample(ae_smp_screen, uv).rgb;
    if (blend >= 0.999) {
        ae_out.FragColor = float4(current, 1.0);
        return ae_out;
    }
    float2 prev_uv = uv - velocity.sample(ae_smp_velocity, uv).xy;
    if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) {
        ae_out.FragColor = float4(current, 1.0);
        return ae_out;
    }
    float3 past = ae3d_shaders_taa_fold(history.sample(ae_smp_history, prev_uv).rgb, exposure);
    float3 now = ae3d_shaders_taa_fold(current, exposure);
    float3 low = now;
    float3 high = now;
    float y = -1.0;
    while (y <= 1.0) {
        float x = -1.0;
        while (x <= 1.0) {
            if (x != 0.0 || y != 0.0) {
                float3 c = ae3d_shaders_taa_fold(screen.sample(ae_smp_screen, (uv + float2(x, y) * px)).rgb, exposure);
                low = min(low, c);
                high = max(high, c);
            }
            x = x + 1.0;
        }
        y = y + 1.0;
    }
    past = clamp(past, low, high);
    float travel = length((prev_uv - uv) * screen_size);
    float weight = clamp(blend + travel * 0.02, blend, 1.0);
    ae_out.FragColor = float4(ae3d_shaders_taa_unfold(mix(past, now, weight), exposure), 1.0);
    return ae_out;
}
