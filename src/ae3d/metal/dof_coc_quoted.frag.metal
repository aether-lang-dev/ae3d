// dof_coc: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 texel;
    char ae_pad0[8];
    float4x4 inv_view_projection;
    float focus;
    float aperture;
    float max_radius;
    char ae_pad1[4];
};
static_assert(sizeof(ae_Params) == 96, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, texel) == 0, "ae_Params.texel: std140");
static_assert(__builtin_offsetof(ae_Params, inv_view_projection) == 16, "ae_Params.inv_view_projection: std140");
static_assert(__builtin_offsetof(ae_Params, focus) == 80, "ae_Params.focus: std140");
static_assert(__builtin_offsetof(ae_Params, aperture) == 84, "ae_Params.aperture: std140");
static_assert(__builtin_offsetof(ae_Params, max_radius) == 88, "ae_Params.max_radius: std140");

struct ae_dof_coc_in {
    float2 uv [[user(locn0)]];
};

struct ae_dof_coc_frag_out {
    float4 FragColor [[color(0)]];
};

static float ae3d_shaders_dof_disc_radius(float z, float d, float focus, float aperture, float max_radius) {
    float r = aperture;
    if (d < 0.99999) {
        r = aperture * (z - focus) / max(z, 0.0001);
    }
    return clamp(r, 0.0 - max_radius, max_radius);
}

static float ae3d_shaders_dof_view_depth(float4x4 inv_view_projection, float2 uv, float d) {
    float4 p = (inv_view_projection * float4(float3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, d), 1.0));
    return 1.0 / max(abs(p.w), 0.0000001);
}

static float ae3d_shaders_dof_texel_disc(texture2d<float> depth, sampler ae_smp_depth, float2 dsize, float2 p, float4x4 inv_view_projection, float focus, float aperture, float max_radius) {
    float2 q = clamp(p, float2(0.0, 0.0), dsize - float2(1.0, 1.0));
    float d = depth.read(uint2(int2(q)), 0).x;
    float2 uv = (q + float2(0.5, 0.5)) / dsize;
    return ae3d_shaders_dof_disc_radius(ae3d_shaders_dof_view_depth(inv_view_projection, uv, d), d, focus, aperture, max_radius);
}

fragment ae_dof_coc_frag_out ae_dof_coc_fragment(
    ae_dof_coc_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]],
    texture2d<float> depth [[texture(1)]], sampler ae_smp_depth [[sampler(1)]]) {
    ae_dof_coc_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float2& texel = ae_params.texel;
    constant float4x4& inv_view_projection = ae_params.inv_view_projection;
    constant float& focus = ae_params.focus;
    constant float& aperture = ae_params.aperture;
    constant float& max_radius = ae_params.max_radius;
    float2 q = texel * 0.25;
    float3 c = (screen.sample(ae_smp_screen, (uv + float2(-q.x, -q.y))).rgb + screen.sample(ae_smp_screen, (uv + float2(q.x, -q.y))).rgb + screen.sample(ae_smp_screen, (uv + float2(-q.x, q.y))).rgb + screen.sample(ae_smp_screen, (uv + float2(q.x, q.y))).rgb) * 0.25;
    float2 dsize = float2(float(depth.get_width()), float(depth.get_height()));
    float2 b = floor(uv * dsize - float2(0.5, 0.5));
    float r0 = ae3d_shaders_dof_texel_disc(depth, ae_smp_depth, dsize, b, inv_view_projection, focus, aperture, max_radius);
    float r1 = ae3d_shaders_dof_texel_disc(depth, ae_smp_depth, dsize, b + float2(1.0, 0.0), inv_view_projection, focus, aperture, max_radius);
    float r2 = ae3d_shaders_dof_texel_disc(depth, ae_smp_depth, dsize, b + float2(0.0, 1.0), inv_view_projection, focus, aperture, max_radius);
    float r3 = ae3d_shaders_dof_texel_disc(depth, ae_smp_depth, dsize, b + float2(1.0, 1.0), inv_view_projection, focus, aperture, max_radius);
    float r = r0;
    if (abs(r1) > abs(r)) {
        r = r1;
    }
    if (abs(r2) > abs(r)) {
        r = r2;
    }
    if (abs(r3) > abs(r)) {
        r = r3;
    }
    ae_out.FragColor = float4(c, r);
    return ae_out;
}
