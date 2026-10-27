// composite: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct Haze {
    int count;
    char ae_pad0[12];
    float4 column[4];
    float4 shape[4];
};
static_assert(sizeof(Haze) == 144, "Haze: std140");
static_assert(__builtin_offsetof(Haze, count) == 0, "Haze.count: std140");
static_assert(__builtin_offsetof(Haze, column) == 16, "Haze.column: std140");
static_assert(__builtin_offsetof(Haze, shape) == 80, "Haze.shape: std140");

struct ae_Params {
    Haze haze;
    int capture_channel;
    char ae_pad0[12];
    float4x4 view_projection;
    int bloom_on;
    float bloom_intensity;
    int dof_on;
    float frame_exposure;
};
static_assert(sizeof(ae_Params) == 240, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, haze) == 0, "ae_Params.haze: std140");
static_assert(__builtin_offsetof(ae_Params, capture_channel) == 144, "ae_Params.capture_channel: std140");
static_assert(__builtin_offsetof(ae_Params, view_projection) == 160, "ae_Params.view_projection: std140");
static_assert(__builtin_offsetof(ae_Params, bloom_on) == 224, "ae_Params.bloom_on: std140");
static_assert(__builtin_offsetof(ae_Params, bloom_intensity) == 228, "ae_Params.bloom_intensity: std140");
static_assert(__builtin_offsetof(ae_Params, dof_on) == 232, "ae_Params.dof_on: std140");
static_assert(__builtin_offsetof(ae_Params, frame_exposure) == 236, "ae_Params.frame_exposure: std140");

struct HazePoint {
    float2 at;
    float w;
};

struct ae_composite_in {
    float4 ae_frag_coord [[position]];
    float2 uv [[user(locn0)]];
};

struct ae_composite_frag_out {
    float4 FragColor [[color(0)]];
};

static HazePoint ae3d_shaders_composite_haze_screen(float4x4 view_projection, float3 p) {
    float4 c = (view_projection * float4(p, 1.0));
    return HazePoint{c.xy / max(c.w, 0.0001) * 0.5 + float2(0.5), c.w};
}

static float ae3d_shaders_composite_haze_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float ae3d_shaders_composite_haze_noise(float2 p) {
    float2 i = floor(p);
    float2 f0 = fract(p);
    float2 f = f0 * f0 * (float2(3.0) - f0 * 2.0);
    return mix(mix(ae3d_shaders_composite_haze_hash(i), ae3d_shaders_composite_haze_hash(i + float2(1.0, 0.0)), f.x), mix(ae3d_shaders_composite_haze_hash(i + float2(0.0, 1.0)), ae3d_shaders_composite_haze_hash(i + float2(1.0, 1.0)), f.x), f.y);
}

static float3 ae3d_shaders_composite_aces(float3 x) {
    return clamp(x * (x * 2.51 + float3(0.03)) / (x * (x * 2.43 + float3(0.59)) + float3(0.14)), float3(0.0), float3(1.0));
}

static float ae3d_shaders_composite_srgb_encode(float c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

fragment ae_composite_frag_out ae_composite_fragment(
    ae_composite_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> screen [[texture(0)]], sampler ae_smp_screen [[sampler(0)]],
    texture2d<float> bloom [[texture(1)]], sampler ae_smp_bloom [[sampler(1)]],
    texture2d<float> dof [[texture(2)]], sampler ae_smp_dof [[sampler(2)]]) {
    ae_composite_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    float2 uv = ae_in.uv;
    constant Haze& haze = ae_params.haze;
    constant int& capture_channel = ae_params.capture_channel;
    constant float4x4& view_projection = ae_params.view_projection;
    constant int& bloom_on = ae_params.bloom_on;
    constant float& bloom_intensity = ae_params.bloom_intensity;
    constant int& dof_on = ae_params.dof_on;
    constant float& frame_exposure = ae_params.frame_exposure;
    float2 at = uv;
    if (haze.count > 0 && capture_channel == 0) {
        float2 offset = float2(0.0, 0.0);
        int k = 0;
        while (k < 4) {
            int kk = k;
            k = k + 1;
            if (kk >= haze.count) {
                break;
            }
            float4 column = haze.column[kk];
            float4 shape = haze.shape[kk];
            HazePoint hb = ae3d_shaders_composite_haze_screen(view_projection, column.xyz);
            HazePoint ht = ae3d_shaders_composite_haze_screen(view_projection, column.xyz + float3(0.0, shape.x, 0.0));
            if (hb.w <= 0.0 || ht.w <= 0.0) {
                continue;
            }
            float2 b = hb.at;
            float2 axis = ht.at - b;
            float len2 = dot(axis, axis);
            if (len2 < 1e-10) {
                continue;
            }
            float along = dot(uv - b, axis) / len2;
            float width = column.w * abs(view_projection[0][0]) / hb.w * 0.5 * (1.0 + 0.6 * along);
            float across = abs(uv.x - (b.x + axis.x * along)) / max(width, 1e-6);
            if (along < 0.0 || along > 1.0 || across > 1.0) {
                continue;
            }
            float amount = shape.y * smoothstep(0.0, 0.08, along) * (1.0 - along) * (1.0 - across * across);
            float2 q = float2(across * 3.0 + float(kk) * 7.1, along * 7.0 - shape.z);
            float2 n = float2(ae3d_shaders_composite_haze_noise(q * 2.3), ae3d_shaders_composite_haze_noise(q * 2.3 + float2(17.3, 5.9))) - float2(0.5);
            offset = offset + n * amount * width * 0.18;
        }
        at = at + offset;
    }
    float3 radiance = screen.sample(ae_smp_screen, at).rgb;
    if (capture_channel != 0) {
        ae_out.FragColor = float4(radiance, 1.0);
        return ae_out;
    }
    if (bloom_on != 0) {
        radiance = radiance + bloom.sample(ae_smp_bloom, at).rgb * bloom_intensity;
    }
    if (dof_on != 0) {
        float4 focused = dof.sample(ae_smp_dof, at);
        radiance = radiance + (focused.rgb - screen.sample(ae_smp_screen, at).rgb) * focused.w;
    }
    float3 shown = ae3d_shaders_composite_aces(radiance * frame_exposure);
    shown = float3(ae3d_shaders_composite_srgb_encode(shown.x), ae3d_shaders_composite_srgb_encode(shown.y), ae3d_shaders_composite_srgb_encode(shown.z));
    float noise = fract(sin(dot(ae_frag_coord.xy, float2(12.9898, 78.233))) * 43758.5453) - 0.5;
    ae_out.FragColor = float4(shown + float3(noise / 255.0), 1.0);
    return ae_out;
}
