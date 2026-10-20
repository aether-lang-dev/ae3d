// sea_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct Water {
    float4x4 model;
    float time;
    float speed;
    float height;
    float randomness;
    float4 directions[4];
    float4 amplitudes[4];
    float4 frequencies[4];
    float4 speeds[4];
    float4 phases[4];
    float4 steepness[4];
};
static_assert(sizeof(Water) == 464, "Water: std140");
static_assert(__builtin_offsetof(Water, model) == 0, "Water.model: std140");
static_assert(__builtin_offsetof(Water, time) == 64, "Water.time: std140");
static_assert(__builtin_offsetof(Water, speed) == 68, "Water.speed: std140");
static_assert(__builtin_offsetof(Water, height) == 72, "Water.height: std140");
static_assert(__builtin_offsetof(Water, randomness) == 76, "Water.randomness: std140");
static_assert(__builtin_offsetof(Water, directions) == 80, "Water.directions: std140");
static_assert(__builtin_offsetof(Water, amplitudes) == 144, "Water.amplitudes: std140");
static_assert(__builtin_offsetof(Water, frequencies) == 208, "Water.frequencies: std140");
static_assert(__builtin_offsetof(Water, speeds) == 272, "Water.speeds: std140");
static_assert(__builtin_offsetof(Water, phases) == 336, "Water.phases: std140");
static_assert(__builtin_offsetof(Water, steepness) == 400, "Water.steepness: std140");

struct Eye {
    float4x4 view_projection;
    float4x4 prev_view_projection;
    packed_float3 position;
    char ae_pad0[4];
};
static_assert(sizeof(Eye) == 144, "Eye: std140");
static_assert(__builtin_offsetof(Eye, view_projection) == 0, "Eye.view_projection: std140");
static_assert(__builtin_offsetof(Eye, prev_view_projection) == 64, "Eye.prev_view_projection: std140");
static_assert(__builtin_offsetof(Eye, position) == 128, "Eye.position: std140");

struct ae_VertexParams {
    Water surface;
    Eye viewer;
};
static_assert(sizeof(ae_VertexParams) == 608, "ae_VertexParams: std140");
static_assert(__builtin_offsetof(ae_VertexParams, surface) == 0, "ae_VertexParams.surface: std140");
static_assert(__builtin_offsetof(ae_VertexParams, viewer) == 464, "ae_VertexParams.viewer: std140");

struct ae_sea_vertex_in {
    float3 inPosition [[attribute(0)]];
    float2 inTexCoord [[attribute(1)]];
};

struct ae_sea_vertex_out {
    float4 ae_position [[position]];
    float2 uv [[user(locn0)]];
    float3 normal [[user(locn1)]];
    float3 world [[user(locn2)]];
    float4 clip_now [[user(locn3)]];
    float4 clip_prev [[user(locn4)]];
    float eye_below [[user(locn5)]];
};

static float ae3d_shaders_sea_swell_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float ae3d_shaders_sea_swell_noise(float2 p_in, int octaves) {
    float2 p = p_in;
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i += 1) {
        float2 i_p = floor(p);
        float2 f_p0 = fract(p);
        float2 f_p = f_p0 * f_p0 * (float2(3.0) - f_p0 * 2.0);
        float a = ae3d_shaders_sea_swell_hash(i_p);
        float b = ae3d_shaders_sea_swell_hash(i_p + float2(1.0, 0.0));
        float c = ae3d_shaders_sea_swell_hash(i_p + float2(0.0, 1.0));
        float d = ae3d_shaders_sea_swell_hash(i_p + float2(1.0, 1.0));
        value = value + amplitude * mix(mix(a, b, f_p.x), mix(c, d, f_p.x), f_p.y);
        amplitude = amplitude * 0.5;
        p = p * 2.0;
    }
    return value;
}

static float3 ae3d_shaders_sea_gerstner(float3 position, float3 direction, float amplitude, float frequency, float speed, float phase, float steepness, float time, float speed_multiplier) {
    float2 d = normalize(direction.xz);
    float effective_speed = speed * speed_multiplier;
    if (speed_multiplier <= 0.001) {
        effective_speed = speed;
    }
    float wave = dot(d, position.xz) * frequency + time * effective_speed + phase;
    float c = cos(wave);
    float s = sin(wave);
    float k = 1.2;
    float sharpened_s = pow((s + 1.0) * 0.5, k) * 2.0 - 1.0;
    float q = steepness / (frequency * amplitude * 6.0 + 0.01);
    return float3(q * amplitude * d.x * c, amplitude * sharpened_s, q * amplitude * d.y * c);
}

static float3 ae3d_shaders_sea_gerstner_normal(float3 position, float3 direction, float amplitude, float frequency, float speed, float phase, float steepness, float time, float speed_multiplier) {
    float2 d = normalize(direction.xz);
    float effective_speed = speed * speed_multiplier;
    if (speed_multiplier <= 0.001) {
        effective_speed = speed;
    }
    float wave = dot(d, position.xz) * frequency + time * effective_speed + phase;
    float c = cos(wave);
    float s = sin(wave);
    float k = 1.2;
    float sharpened_derivative = k * pow((s + 1.0) * 0.5, k - 1.0);
    float q = steepness / (frequency * amplitude * 6.0 + 0.01);
    float wa = frequency * amplitude;
    return float3(-d.x * wa * c * sharpened_derivative, 1.0 - q * wa * s, -d.y * wa * c * sharpened_derivative);
}

vertex ae_sea_vertex_out ae_sea_vertex_vertex(
    ae_sea_vertex_in ae_in [[stage_in]],
    constant ae_VertexParams& ae_params [[buffer(1)]]) {
    ae_sea_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float2 inTexCoord = ae_in.inTexCoord;
    constant Water& surface = ae_params.surface;
    constant Eye& viewer = ae_params.viewer;
    float3 world0 = (surface.model * float4(inPosition, 1.0)).xyz;
    float3 total = float3(0.0);
    float3 total_normal = float3(0.0, 1.0, 0.0);
    for (int i = 0; i < 4; i += 1) {
        float random_factor = 1.0;
        if (surface.randomness > 0.001) {
            float random_noise = ae3d_shaders_sea_swell_noise(world0.xz * 0.01 + float2(surface.time * 0.1) + float2(float(i)), 2);
            random_factor = mix(1.0, 0.5 + random_noise, surface.randomness);
        }
        float adjusted = surface.amplitudes[i].x * surface.height * random_factor;
        float3 wave_disp = ae3d_shaders_sea_gerstner(world0, surface.directions[i].xyz, adjusted, surface.frequencies[i].x, surface.speeds[i].x, surface.phases[i].x, surface.steepness[i].x, surface.time, surface.speed);
        float3 wave_normal = ae3d_shaders_sea_gerstner_normal(world0, surface.directions[i].xyz, adjusted, surface.frequencies[i].x, surface.speeds[i].x, surface.phases[i].x, surface.steepness[i].x, surface.time, surface.speed);
        total = total + wave_disp;
        total_normal = total_normal + wave_normal;
    }
    float3 lifted = float3(total.x, total.y * 1.5, total.z);
    float3 displaced = world0 + lifted;
    float3 normal_out = normalize(total_normal);
    float4 now = (viewer.view_projection * float4(displaced, 1.0));
    float4 prev = (viewer.prev_view_projection * float4(displaced, 1.0));
    float3 eye_at = float3(viewer.position.x, 0.0, viewer.position.z);
    float over = 0.0;
    for (int j = 0; j < 4; j += 1) {
        float eye_factor = 1.0;
        if (surface.randomness > 0.001) {
            float eye_noise = ae3d_shaders_sea_swell_noise(eye_at.xz * 0.01 + float2(surface.time * 0.1) + float2(float(j)), 2);
            eye_factor = mix(1.0, 0.5 + eye_noise, surface.randomness);
        }
        over = over + ae3d_shaders_sea_gerstner(eye_at, surface.directions[j].xyz, surface.amplitudes[j].x * surface.height * eye_factor, surface.frequencies[j].x, surface.speeds[j].x, surface.phases[j].x, surface.steepness[j].x, surface.time, surface.speed).y;
    }
    ae_out.ae_position = now;
    ae_out.uv = inTexCoord;
    ae_out.normal = normal_out;
    ae_out.world = displaced;
    ae_out.clip_now = now;
    ae_out.clip_prev = prev;
    ae_out.eye_below = surface.model[3][1] + over * 1.5 - viewer.position.y;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
