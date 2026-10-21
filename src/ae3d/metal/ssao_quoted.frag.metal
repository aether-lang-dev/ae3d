// ssao: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float2 screen_size;
    char ae_pad0[8];
    float4x4 inv_view_projection;
    float intensity;
    char ae_pad1[12];
    packed_float3 view_pos;
    float radius;
    float4x4 view_projection;
};
static_assert(sizeof(ae_Params) == 176, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, screen_size) == 0, "ae_Params.screen_size: std140");
static_assert(__builtin_offsetof(ae_Params, inv_view_projection) == 16, "ae_Params.inv_view_projection: std140");
static_assert(__builtin_offsetof(ae_Params, intensity) == 80, "ae_Params.intensity: std140");
static_assert(__builtin_offsetof(ae_Params, view_pos) == 96, "ae_Params.view_pos: std140");
static_assert(__builtin_offsetof(ae_Params, radius) == 108, "ae_Params.radius: std140");
static_assert(__builtin_offsetof(ae_Params, view_projection) == 112, "ae_Params.view_projection: std140");

struct ae_ssao_in {
    float4 ae_frag_coord [[position]];
};

struct ae_ssao_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_ssao_world_at(float4x4 inv_view_projection, float2 uv, float depth) {
    float4 world = (inv_view_projection * float4(float3(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, depth), 1.0));
    return world.xyz / world.w;
}

static float ae3d_shaders_ssao_dither(float2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, float2(0.06711056, 0.00583715))));
}

fragment ae_ssao_frag_out ae_ssao_fragment(
    ae_ssao_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> depth [[texture(0)]], sampler ae_smp_depth [[sampler(0)]]) {
    ae_ssao_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant float2& screen_size = ae_params.screen_size;
    constant float4x4& inv_view_projection = ae_params.inv_view_projection;
    constant float& intensity = ae_params.intensity;
    constant packed_float3& view_pos = ae_params.view_pos;
    constant float& radius = ae_params.radius;
    constant float4x4& view_projection = ae_params.view_projection;
    float2 fc = ae_frag_coord.xy;
    float2 uv = float2(fc.x / screen_size.x, fc.y / screen_size.y);
    float d = depth.sample(ae_smp_depth, uv).x;
    float3 p = ae3d_shaders_ssao_world_at(inv_view_projection, uv, d);
    if (d >= 0.99999 || intensity <= 0.0) {
        ae_out.FragColor = float4(float3(1.0, 0.0, 0.0), 1.0);
        return ae_out;
    }
    float2 px = float2(1.0 / screen_size.x, 1.0 / screen_size.y);
    float2 ul = uv - float2(px.x, 0.0);
    float dl = depth.sample(ae_smp_depth, ul).x;
    float3 pl = ae3d_shaders_ssao_world_at(inv_view_projection, ul, dl);
    float2 ur = uv + float2(px.x, 0.0);
    float dr = depth.sample(ae_smp_depth, ur).x;
    float3 pr = ae3d_shaders_ssao_world_at(inv_view_projection, ur, dr);
    float2 above = float2(0.0, px.y * (-1.0));
    float2 ud = uv - above;
    float dd = depth.sample(ae_smp_depth, ud).x;
    float3 pd = ae3d_shaders_ssao_world_at(inv_view_projection, ud, dd);
    float2 uu = uv + above;
    float du = depth.sample(ae_smp_depth, uu).x;
    float3 pu = ae3d_shaders_ssao_world_at(inv_view_projection, uu, du);
    float3 dx = abs(dl - d) < abs(dr - d) ? p - pl : pr - p;
    float3 dy = abs(dd - d) < abs(du - d) ? p - pd : pu - p;
    float3 n = normalize(cross(dx, dy));
    float eye = distance(view_pos, p);
    float3 up = abs(n.y) < 0.99 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 t = normalize(cross(up, n));
    float3 b = cross(n, t);
    float2 pixel = (-1.0) < 0.0 ? float2(fc.x, screen_size.y - fc.y) : fc;
    float turn = ae3d_shaders_ssao_dither(pixel) * 6.2831853;
    float occlusion = 0.0;
    float i = 0.0;
    while (i < 12.0) {
        float f = (i + 0.5) / 12.0;
        i = i + 1.0;
        float a = turn + f * 15.0796;
        float r = sqrt(f);
        float h = sqrt(1.0 - r * r);
        float3 dir = t * (cos(a) * r) + b * (sin(a) * r) + n * h;
        float reach = radius * mix(0.1, 1.0, f * f);
        float3 s = p + dir * reach;
        float4 clip = (view_projection * float4(s, 1.0));
        if (clip.w <= 0.0) {
            continue;
        }
        float2 suv = float2(clip.x / clip.w * 0.5 + 0.5, clip.y / clip.w * 0.5 + 0.5);
        if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
            continue;
        }
        float sd = depth.sample(ae_smp_depth, suv).x;
        float scene_dist = distance(view_pos, ae3d_shaders_ssao_world_at(inv_view_projection, suv, sd));
        float sample_dist = distance(view_pos, s);
        if (sample_dist - scene_dist > 0.03 * reach + eye * 0.01) {
            occlusion = occlusion + smoothstep(0.0, 1.0, radius / max(abs(eye - scene_dist), 0.0001));
        }
    }
    occlusion = occlusion / 12.0;
    float ao = clamp(1.0 - occlusion * intensity, 0.0, 1.0);
    ao = mix(ao, 1.0, smoothstep(radius * 40.0, radius * 120.0, eye));
    ae_out.FragColor = float4(float3(ao, (view_projection * float4(p, 1.0)).w, 0.0), 1.0);
    return ae_out;
}
