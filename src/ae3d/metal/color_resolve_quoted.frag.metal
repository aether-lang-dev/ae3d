// color_resolve: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    int samples;
    float exposure;
    char ae_pad0[8];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, samples) == 0, "ae_Params.samples: std140");
static_assert(__builtin_offsetof(ae_Params, exposure) == 4, "ae_Params.exposure: std140");

struct ae_color_resolve_in {
    float4 ae_frag_coord [[position]];
};

struct ae_color_resolve_frag_out {
    float4 FragColor [[color(0)]];
};

fragment ae_color_resolve_frag_out ae_color_resolve_fragment(
    ae_color_resolve_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d_ms<float> colour [[texture(0)]]) {
    ae_color_resolve_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant int& samples = ae_params.samples;
    constant float& exposure = ae_params.exposure;
    float4 sum = float4(float3(0.0, 0.0, 0.0), 0.0);
    float weights = 0.0;
    int s = 0;
    while (s < samples) {
        float4 c = colour.read(uint2(int2(ae_frag_coord.xy)), uint(s));
        float w = 1.0 / (1.0 + dot(c.rgb * exposure, float3(0.2126, 0.7152, 0.0722)));
        sum = sum + c * w;
        weights = weights + w;
        s = s + 1;
    }
    ae_out.FragColor = sum / max(weights, 0.000001);
    return ae_out;
}
