// sky_irradiance: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_Params {
    packed_float3 ground_albedo;
    char ae_pad0[4];
    packed_float3 ground_sun;
    char ae_pad1[4];
};
static_assert(sizeof(ae_Params) == 32, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, ground_albedo) == 0, "ae_Params.ground_albedo: std140");
static_assert(__builtin_offsetof(ae_Params, ground_sun) == 16, "ae_Params.ground_sun: std140");

struct ae_sky_irradiance_in {
    float4 ae_frag_coord [[position]];
};

struct ae_sky_irradiance_frag_out {
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

static float3 ae3d_shaders_skyprobe_capture_q(float x, float y) {
    float u = (x + 0.5) / 16.0;
    float v = (y + 0.5) / 16.0;
    float px = clamp((u * 256.0 - 1.0) / (256.0 - 2.0) * 2.0 - 1.0, -1.0, 1.0);
    float py = clamp((v * 256.0 - 1.0) / (256.0 - 2.0) * 2.0 - 1.0, -1.0, 1.0);
    float3 q = float3(px, 1.0 - abs(px) - abs(py), py);
    if (q.y < 0.0) {
        q = float3((1.0 - abs(q.z)) * (q.x >= 0.0 ? 1.0 : -1.0), q.y, (1.0 - abs(q.x)) * (q.z >= 0.0 ? 1.0 : -1.0));
    }
    return q;
}

fragment ae_sky_irradiance_frag_out ae_sky_irradiance_fragment(
    ae_sky_irradiance_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> capture [[texture(0)]], sampler ae_smp_capture [[sampler(0)]]) {
    ae_sky_irradiance_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    constant packed_float3& ground_albedo = ae_params.ground_albedo;
    constant packed_float3& ground_sun = ae_params.ground_sun;
    float2 fc = ae_frag_coord.xy;
    float3 n = ae3d_shaders_skyprobe_oct_texel_direction(float2(fc.x / 16.0, fc.y / 16.0), 16.0);
    bool grounded = ground_albedo.x + ground_albedo.y + ground_albedo.z > 0.0;
    float3 ground = float3(0.0, 0.0, 0.0);
    if (grounded) {
        float3 up = float3(0.0, 0.0, 0.0);
        float whole = 0.0;
        float y = 0.0;
        while (y < 16.0) {
            float x = 0.0;
            while (x < 16.0) {
                float3 q = ae3d_shaders_skyprobe_capture_q(x, y);
                float len = length(q);
                float angle = 1.0 / (len * len * len);
                float3 l = q / len;
                if (l.y > 0.0) {
                    up = up + capture.read(uint2(int2(float2(x, y))), uint(int(4.0))).rgb * l.y * angle;
                }
                whole = whole + angle;
                x = x + 1.0;
            }
            y = y + 1.0;
        }
        up = up * (4.0 * 3.14159265 / whole);
        ground = ground_albedo * (up + ground_sun) / 3.14159265;
    }
    float3 sum = float3(0.0, 0.0, 0.0);
    float total = 0.0;
    float y = 0.0;
    while (y < 16.0) {
        float x = 0.0;
        while (x < 16.0) {
            float3 q = ae3d_shaders_skyprobe_capture_q(x, y);
            float len = length(q);
            float angle = 1.0 / (len * len * len);
            float3 l = q / len;
            float3 seen = grounded && l.y < 0.0 ? ground : capture.read(uint2(int2(float2(x, y))), uint(int(4.0))).rgb;
            sum = sum + seen * max(dot(n, l), 0.0) * angle;
            total = total + angle;
            x = x + 1.0;
        }
        y = y + 1.0;
    }
    ae_out.FragColor = float4(sum * (4.0 * 3.14159265 / total), 1.0);
    return ae_out;
}
