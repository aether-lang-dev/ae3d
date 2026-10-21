// depth_resolve: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    int samples;
    char ae_pad0[12];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, samples) == 0, "ae_Params.samples: std140");

struct ae_depth_resolve_in {
    float4 ae_frag_coord [[position]];
};

struct ae_depth_resolve_frag_out {
    float ae_depth [[depth(any)]];
};

fragment ae_depth_resolve_frag_out ae_depth_resolve_fragment(
    ae_depth_resolve_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d_ms<float> depth [[texture(0)]]) {
    ae_depth_resolve_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant int& samples = ae_params.samples;
    float nearest = 1.0;
    int s = 0;
    while (s < samples) {
        nearest = min(nearest, depth.read(uint2(int2(ae_frag_coord.xy)), uint(s)).x);
        s = s + 1;
    }
    ae_out.ae_depth = nearest;
    return ae_out;
}
