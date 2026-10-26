// view_blit: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_view_blit_in {
    float2 uv [[user(locn0)]];
};

struct ae_view_blit_frag_out {
    float4 FragColor [[color(0)]];
};

static float ae3d_shaders_viewrect_srgb_encode(float x) {
    if (x <= 0.0031308) {
        return x * 12.92;
    }
    return 1.055 * pow(x, 1.0 / 2.4) - 0.055;
}

fragment ae_view_blit_frag_out ae_view_blit_fragment(
    ae_view_blit_in ae_in [[stage_in]],
    texture2d<float> picture [[texture(0)]], sampler ae_smp_picture [[sampler(0)]]) {
    ae_view_blit_frag_out ae_out;
    float2 uv = ae_in.uv;
    float4 c = picture.sample(ae_smp_picture, uv);
    ae_out.FragColor = float4(float3(ae3d_shaders_viewrect_srgb_encode(c.x), ae3d_shaders_viewrect_srgb_encode(c.y), ae3d_shaders_viewrect_srgb_encode(c.z)), c.w);
    return ae_out;
}
