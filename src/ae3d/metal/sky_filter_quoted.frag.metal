// sky_filter: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    float level_size;
    float roughness;
    char ae_pad0[8];
};
static_assert(sizeof(ae_Params) == 16, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, level_size) == 0, "ae_Params.level_size: std140");
static_assert(__builtin_offsetof(ae_Params, roughness) == 4, "ae_Params.roughness: std140");

struct ae_sky_filter_in {
    float4 ae_frag_coord [[position]];
};

struct ae_sky_filter_frag_out {
    float4 FragColor [[color(0)]];
};

static float3 ae3d_shaders_skyprobe_oct_decode(float2 p) {
    float3 d = float3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        d = float3((1.0 - abs(d.z)) * (d.x >= 0.0 ? 1.0 : -1.0), d.y, (1.0 - abs(d.x)) * (d.z >= 0.0 ? 1.0 : -1.0));
    }
    return normalize(d);
}

static float3 ae3d_shaders_skyprobe_oct_texel_direction(float2 uv, float size) {
    float px = (uv.x * size - 1.0) / (size - 2.0) * 2.0 - 1.0;
    float py = (uv.y * size - 1.0) / (size - 2.0) * 2.0 - 1.0;
    if (px > 1.0) {
        px = 2.0 - px;
        py = -py;
    }
    if (px < -1.0) {
        px = -2.0 - px;
        py = -py;
    }
    if (py > 1.0) {
        py = 2.0 - py;
        px = -px;
    }
    if (py < -1.0) {
        py = -2.0 - py;
        px = -px;
    }
    return ae3d_shaders_skyprobe_oct_decode(float2(px, py));
}

static float2 ae3d_shaders_skyprobe_oct_encode(float3 d) {
    float3 e = d / (abs(d.x) + abs(d.y) + abs(d.z));
    float2 p = float2(e.x, e.z);
    if (e.y < 0.0) {
        p = float2((1.0 - abs(p.y)) * (p.x >= 0.0 ? 1.0 : -1.0), (1.0 - abs(p.x)) * (p.y >= 0.0 ? 1.0 : -1.0));
    }
    return p;
}

static float2 ae3d_shaders_skyprobe_oct_uv(float3 d, float size) {
    float2 e = ae3d_shaders_skyprobe_oct_encode(d);
    return float2(((e.x * 0.5 + 0.5) * (size - 2.0) + 1.0) / size, ((e.y * 0.5 + 0.5) * (size - 2.0) + 1.0) / size);
}

static float ae3d_shaders_skyprobe_radical_inverse(float i) {
    uint bits = uint(i);
    bits = bits << 16u | bits >> 16u;
    bits = (bits & 0x55555555u) << 1u | (bits & 0xAAAAAAAAu) >> 1u;
    bits = (bits & 0x33333333u) << 2u | (bits & 0xCCCCCCCCu) >> 2u;
    bits = (bits & 0x0F0F0F0Fu) << 4u | (bits & 0xF0F0F0F0u) >> 4u;
    bits = (bits & 0x00FF00FFu) << 8u | (bits & 0xFF00FF00u) >> 8u;
    return float(bits) * 2.3283064365386963e-10;
}

fragment ae_sky_filter_frag_out ae_sky_filter_fragment(
    ae_sky_filter_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> capture [[texture(0)]], sampler ae_smp_capture [[sampler(0)]]) {
    ae_sky_filter_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant float& level_size = ae_params.level_size;
    constant float& roughness = ae_params.roughness;
    float2 fc = ae_frag_coord.xy;
    float3 n = ae3d_shaders_skyprobe_oct_texel_direction(float2(fc.x / level_size, fc.y / level_size), 256.0);
    if (roughness <= 0.0) {
        ae_out.FragColor = float4(capture.sample(ae_smp_capture, ae3d_shaders_skyprobe_oct_uv(n, 256.0), level(0.0)).rgb, 1.0);
        return ae_out;
    }
    float a = roughness * roughness;
    float3 up = abs(n.y) < 0.999 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 t = normalize(cross(up, n));
    float3 b = cross(n, t);
    float texel = 4.0 * 3.14159265 / ((256.0 - 2.0) * (256.0 - 2.0));
    float3 sum = float3(0.0, 0.0, 0.0);
    float weight = 0.0;
    float i = 0.0;
    while (i < 48.0) {
        float xi_x = (i + 0.5) / 48.0;
        float xi_y = ae3d_shaders_skyprobe_radical_inverse(i);
        i = i + 1.0;
        float phi = 6.28318531 * xi_y;
        float cos_theta = sqrt((1.0 - xi_x) / (1.0 + (a * a - 1.0) * xi_x));
        float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
        float3 h = t * (sin_theta * cos(phi)) + b * (sin_theta * sin(phi)) + n * cos_theta;
        float3 l = h * (2.0 * dot(n, h)) - n;
        float n_dot_l = dot(n, l);
        if (n_dot_l <= 0.0) {
            continue;
        }
        float d = cos_theta * cos_theta * (a * a - 1.0) + 1.0;
        float pdf = a * a / (3.14159265 * d * d) / 4.0;
        float sample_angle = 1.0 / (48.0 * pdf + 0.000001);
        float lod = max(0.5 * log2(sample_angle / texel) + 1.0, 0.0);
        sum = sum + capture.sample(ae_smp_capture, ae3d_shaders_skyprobe_oct_uv(l, 256.0), level(lod)).rgb * n_dot_l;
        weight = weight + n_dot_l;
    }
    ae_out.FragColor = float4(sum / max(weight, 0.000001), 1.0);
    return ae_out;
}
