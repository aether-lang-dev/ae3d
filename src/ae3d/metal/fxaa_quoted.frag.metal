// fxaa: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 texel;
    float edge_min;
    float edge;
    float subpixel;
    char ae_pad0[12];
};
static_assert(sizeof(ae_Params) == 32, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, texel) == 0, "ae_Params.texel: std140");
static_assert(__builtin_offsetof(ae_Params, edge_min) == 8, "ae_Params.edge_min: std140");
static_assert(__builtin_offsetof(ae_Params, edge) == 12, "ae_Params.edge: std140");
static_assert(__builtin_offsetof(ae_Params, subpixel) == 16, "ae_Params.subpixel: std140");

struct ae_fxaa_in {
    float2 uv [[user(locn0)]];
};

struct ae_fxaa_frag_out {
    float4 FragColor [[color(0)]];
};

static float ae3d_shaders_fxaa_luma(float3 c) {
    return dot(c, float3(0.299, 0.587, 0.114));
}

fragment ae_fxaa_frag_out ae_fxaa_fragment(
    ae_fxaa_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]]) {
    ae_fxaa_frag_out ae_out;
    float2 uv = ae_in.uv;
    constant float2& texel = ae_params.texel;
    constant float& edge_min = ae_params.edge_min;
    constant float& edge = ae_params.edge;
    constant float& subpixel = ae_params.subpixel;
    float3 c = screen.sample(ae_smp_screen, uv).rgb;
    float3 n = screen.sample(ae_smp_screen, (uv + float2(0.0, -1.0) * texel)).rgb;
    float3 s = screen.sample(ae_smp_screen, (uv + float2(0.0, 1.0) * texel)).rgb;
    float3 e = screen.sample(ae_smp_screen, (uv + float2(1.0, 0.0) * texel)).rgb;
    float3 w = screen.sample(ae_smp_screen, (uv + float2(-1.0, 0.0) * texel)).rgb;
    float lc = ae3d_shaders_fxaa_luma(c);
    float ln = ae3d_shaders_fxaa_luma(n);
    float ls = ae3d_shaders_fxaa_luma(s);
    float le = ae3d_shaders_fxaa_luma(e);
    float lw = ae3d_shaders_fxaa_luma(w);
    float lo = min(lc, min(min(ln, ls), min(le, lw)));
    float hi = max(lc, max(max(ln, ls), max(le, lw)));
    float range = hi - lo;
    if (range < max(edge_min, hi * edge)) {
        ae_out.FragColor = float4(c, 1.0);
        return ae_out;
    }
    float avg = (ln + ls + le + lw) * 0.25;
    float blend = smoothstep(0.0, 1.0, clamp(abs(avg - lc) / range, 0.0, 1.0));
    blend = blend * blend * subpixel;
    float horiz = abs(-2.0 * lw + lc) + abs(-2.0 * lc + le) * 2.0 + abs(-2.0 * le + lc);
    float vert = abs(-2.0 * ln + lc) + abs(-2.0 * lc + ls) * 2.0 + abs(-2.0 * ls + lc);
    bool along = horiz >= vert;
    float g1 = (along ? ls : le) - lc;
    float g2 = (along ? ln : lw) - lc;
    float dir = abs(g1) >= abs(g2) ? sign(g1) : sign(g2);
    float step = blend * dir;
    float2 off = along ? float2(0.0, step * texel.y) : float2(step * texel.x, 0.0);
    ae_out.FragColor = float4(screen.sample(ae_smp_screen, (uv + off)).rgb, 1.0);
    return ae_out;
}
