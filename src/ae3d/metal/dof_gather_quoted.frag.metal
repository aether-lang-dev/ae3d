// dof_gather: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float max_radius;
    char ae_pad0[4];
    float2 texel;
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, max_radius) == 0, "ae_Params.max_radius: std140");
static_assert(__builtin_offsetof(ae_Params, texel) == 8, "ae_Params.texel: std140");

struct ae_dof_gather_in {
    float2 uv [[user(locn0)]];
};

struct ae_dof_gather_frag_out {
    float4 FragColor [[color(0)]];
};

static float ae3d_shaders_dof_tap_weight(float tap, float dist, float own) {
    float reach = clamp(abs(tap) - dist + 0.5, 0.0, 1.0);
    if (tap > 0.0) {
        return reach * clamp(own, 0.0, 1.0);
    }
    return reach;
}

fragment ae_dof_gather_frag_out ae_dof_gather_fragment(
    ae_dof_gather_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> coc [[texture(0)]], sampler ae_smp_coc [[sampler(0)]]) {
    ae_dof_gather_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float& max_radius = ae_params.max_radius;
    constant float2& texel = ae_params.texel;
    float4 centre = coc.sample(ae_smp_coc, uv);
    float own = abs(centre.w);
    float3 sum = centre.rgb;
    float total = 1.0;
    float near = 0.0;
    float widest = 0.0;
    int i = 0;
    while (i < 32) {
        float k = float(i);
        float a = k * 2.3999632;
        float reach = sqrt((k + 0.5) / 32.0) * max_radius;
        float4 tap = coc.sample(ae_smp_coc, (uv + float2(cos(a), sin(a) * (-1.0)) * reach * texel));
        float w = ae3d_shaders_dof_tap_weight(tap.w, reach, own);
        sum = sum + tap.rgb * w;
        total = total + w;
        if (tap.w < 0.0 && w > 0.0) {
            near = near + w;
            widest = max(widest, abs(tap.w));
        }
        i = i + 1;
    }
    float ring = max(16.0 * widest * widest / (max_radius * max_radius), 1.0);
    float blend = max(clamp(own, 0.0, 1.0), clamp(near / ring, 0.0, 1.0));
    ae_out.FragColor = float4(sum / total, blend);
    return ae_out;
}
