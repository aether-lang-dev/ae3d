// depth_copy: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_depth_copy_in {
    float4 ae_frag_coord [[position]];
};

struct ae_depth_copy_frag_out {
    float ae_depth [[depth(any)]];
};

fragment ae_depth_copy_frag_out ae_depth_copy_fragment(
    ae_depth_copy_in ae_in [[stage_in]],
    texture2d<float> depth [[texture(0)]], sampler ae_smp_depth [[sampler(0)]]) {
    ae_depth_copy_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    ae_out.ae_depth = depth.read(uint2(int2(ae_frag_coord.xy)), 0).x;
    return ae_out;
}
