// sea: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct KeyLight {
    packed_float3 position;
    char ae_pad0[4];
    packed_float3 direction;
    char ae_pad1[4];
    packed_float3 colour;
    float intensity;
};
static_assert(sizeof(KeyLight) == 48, "KeyLight: std140");
static_assert(__builtin_offsetof(KeyLight, position) == 0, "KeyLight.position: std140");
static_assert(__builtin_offsetof(KeyLight, direction) == 16, "KeyLight.direction: std140");
static_assert(__builtin_offsetof(KeyLight, colour) == 32, "KeyLight.colour: std140");
static_assert(__builtin_offsetof(KeyLight, intensity) == 44, "KeyLight.intensity: std140");

struct Eye {
    float4x4 inv_view_projection;
    packed_float3 position;
    float far;
    float2 jitter;
    float2 screen_size;
    int depth_on;
    char ae_pad0[12];
};
static_assert(sizeof(Eye) == 112, "Eye: std140");
static_assert(__builtin_offsetof(Eye, inv_view_projection) == 0, "Eye.inv_view_projection: std140");
static_assert(__builtin_offsetof(Eye, position) == 64, "Eye.position: std140");
static_assert(__builtin_offsetof(Eye, far) == 76, "Eye.far: std140");
static_assert(__builtin_offsetof(Eye, jitter) == 80, "Eye.jitter: std140");
static_assert(__builtin_offsetof(Eye, screen_size) == 88, "Eye.screen_size: std140");
static_assert(__builtin_offsetof(Eye, depth_on) == 96, "Eye.depth_on: std140");

struct Water {
    float time;
    float speed;
    float height;
    char ae_pad0[4];
    float4 directions[4];
    float4 amplitudes[4];
    float4 frequencies[4];
    float4 speeds[4];
    float4 phases[4];
    packed_float3 colour;
    float opacity;
    int foam;
    float foam_intensity;
    int caustics;
    float caustics_intensity;
    float caustics_scale;
    int reflection;
    float reflection_intensity;
    int distortion;
    float distortion_intensity;
    int normal_mapping;
    float normal_intensity;
    float depth_fade;
    float shore_foam;
    char ae_pad1[12];
    packed_float3 sky_colour;
    char ae_pad2[4];
    packed_float3 horizon_colour;
    int sky_texture;
    int sky_capture;
    int ripples;
    char ae_pad3[8];
    packed_float3 ripple_area;
    char ae_pad4[4];
};
static_assert(sizeof(Water) == 480, "Water: std140");
static_assert(__builtin_offsetof(Water, time) == 0, "Water.time: std140");
static_assert(__builtin_offsetof(Water, speed) == 4, "Water.speed: std140");
static_assert(__builtin_offsetof(Water, height) == 8, "Water.height: std140");
static_assert(__builtin_offsetof(Water, directions) == 16, "Water.directions: std140");
static_assert(__builtin_offsetof(Water, amplitudes) == 80, "Water.amplitudes: std140");
static_assert(__builtin_offsetof(Water, frequencies) == 144, "Water.frequencies: std140");
static_assert(__builtin_offsetof(Water, speeds) == 208, "Water.speeds: std140");
static_assert(__builtin_offsetof(Water, phases) == 272, "Water.phases: std140");
static_assert(__builtin_offsetof(Water, colour) == 336, "Water.colour: std140");
static_assert(__builtin_offsetof(Water, opacity) == 348, "Water.opacity: std140");
static_assert(__builtin_offsetof(Water, foam) == 352, "Water.foam: std140");
static_assert(__builtin_offsetof(Water, foam_intensity) == 356, "Water.foam_intensity: std140");
static_assert(__builtin_offsetof(Water, caustics) == 360, "Water.caustics: std140");
static_assert(__builtin_offsetof(Water, caustics_intensity) == 364, "Water.caustics_intensity: std140");
static_assert(__builtin_offsetof(Water, caustics_scale) == 368, "Water.caustics_scale: std140");
static_assert(__builtin_offsetof(Water, reflection) == 372, "Water.reflection: std140");
static_assert(__builtin_offsetof(Water, reflection_intensity) == 376, "Water.reflection_intensity: std140");
static_assert(__builtin_offsetof(Water, distortion) == 380, "Water.distortion: std140");
static_assert(__builtin_offsetof(Water, distortion_intensity) == 384, "Water.distortion_intensity: std140");
static_assert(__builtin_offsetof(Water, normal_mapping) == 388, "Water.normal_mapping: std140");
static_assert(__builtin_offsetof(Water, normal_intensity) == 392, "Water.normal_intensity: std140");
static_assert(__builtin_offsetof(Water, depth_fade) == 396, "Water.depth_fade: std140");
static_assert(__builtin_offsetof(Water, shore_foam) == 400, "Water.shore_foam: std140");
static_assert(__builtin_offsetof(Water, sky_colour) == 416, "Water.sky_colour: std140");
static_assert(__builtin_offsetof(Water, horizon_colour) == 432, "Water.horizon_colour: std140");
static_assert(__builtin_offsetof(Water, sky_texture) == 444, "Water.sky_texture: std140");
static_assert(__builtin_offsetof(Water, sky_capture) == 448, "Water.sky_capture: std140");
static_assert(__builtin_offsetof(Water, ripples) == 452, "Water.ripples: std140");
static_assert(__builtin_offsetof(Water, ripple_area) == 464, "Water.ripple_area: std140");

struct Weather {
    int fog;
    float fog_start;
    float fog_end;
    char ae_pad0[4];
    packed_float3 fog_radiance;
    float fog_intensity;
    float overcast;
    char ae_pad1[12];
    packed_float3 overcast_colour;
    char ae_pad2[4];
};
static_assert(sizeof(Weather) == 64, "Weather: std140");
static_assert(__builtin_offsetof(Weather, fog) == 0, "Weather.fog: std140");
static_assert(__builtin_offsetof(Weather, fog_start) == 4, "Weather.fog_start: std140");
static_assert(__builtin_offsetof(Weather, fog_end) == 8, "Weather.fog_end: std140");
static_assert(__builtin_offsetof(Weather, fog_radiance) == 16, "Weather.fog_radiance: std140");
static_assert(__builtin_offsetof(Weather, fog_intensity) == 28, "Weather.fog_intensity: std140");
static_assert(__builtin_offsetof(Weather, overcast) == 32, "Weather.overcast: std140");
static_assert(__builtin_offsetof(Weather, overcast_colour) == 48, "Weather.overcast_colour: std140");

struct ae_Params {
    KeyLight key;
    Eye eye;
    Water water;
    Weather weather;
};
static_assert(sizeof(ae_Params) == 704, "ae_Params: std140");
static_assert(__builtin_offsetof(ae_Params, key) == 0, "ae_Params.key: std140");
static_assert(__builtin_offsetof(ae_Params, eye) == 48, "ae_Params.eye: std140");
static_assert(__builtin_offsetof(ae_Params, water) == 160, "ae_Params.water: std140");
static_assert(__builtin_offsetof(ae_Params, weather) == 640, "ae_Params.weather: std140");

struct ae_sea_in {
    float4 ae_frag_coord [[position]];
    float3 world [[user(locn2)]];
    float4 clip_now [[user(locn3)]];
    float4 clip_prev [[user(locn4)]];
    float eye_below [[user(locn5)]];
};

struct ae_sea_frag_out {
    float4 out_colour [[color(0)]];
    float4 out_velocity [[color(1)]];
};

static float ae3d_shaders_sea_sea_hash(float2 p) {
    float3 p3_0 = fract(float3(p.x, p.y, p.x) * 0.1031);
    float3 p3 = p3_0 + float3(dot(p3_0, float3(p3_0.y, p3_0.z, p3_0.x) + float3(33.33)));
    return fract((p3.x + p3.y) * p3.z);
}

static float ae3d_shaders_sea_sea_noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = ae3d_shaders_sea_sea_hash(i);
    float b = ae3d_shaders_sea_sea_hash(i + float2(1.0, 0.0));
    float c = ae3d_shaders_sea_sea_hash(i + float2(0.0, 1.0));
    float d = ae3d_shaders_sea_sea_hash(i + float2(1.0, 1.0));
    float2 u = f * f * f * (f * (f * 6.0 - float2(15.0)) + float2(10.0));
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

static float3 ae3d_shaders_sea_sea_noised(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = ae3d_shaders_sea_sea_hash(i);
    float b = ae3d_shaders_sea_sea_hash(i + float2(1.0, 0.0));
    float c = ae3d_shaders_sea_sea_hash(i + float2(0.0, 1.0));
    float d = ae3d_shaders_sea_sea_hash(i + float2(1.0, 1.0));
    float2 u = f * f * f * (f * (f * 6.0 - float2(15.0)) + float2(10.0));
    float2 du = f * 30.0 * f * (f * (f - float2(2.0)) + float2(1.0));
    float k1 = b - a;
    float k2 = c - a;
    float k3 = a - b - c + d;
    return float3(a + k1 * u.x + k2 * u.y + k3 * u.x * u.y, du * float2(k1 + k3 * u.y, k2 + k3 * u.x));
}

static float ae3d_shaders_skydome_aces_inverse(float y_in) {
    float y = clamp(y_in, 0.0, 0.9999);
    float a = 2.51 - 2.43 * y;
    float b = 0.03 - 0.59 * y;
    return (-b + sqrt(b * b + 4.0 * a * 0.14 * y)) / (2.0 * a);
}

static float ae3d_shaders_skydome_srgb_decode(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

static float3 ae3d_shaders_skydome_display_radiance(float3 shown) {
    float3 c = clamp(shown, float3(0.0), float3(1.0));
    return float3(ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.x)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.y)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.z)));
}

static float3 ae3d_shaders_sea_overcast_sky(float3 shown, float overcast, float3 overcast_colour) {
    if (overcast <= 0.0) {
        return shown;
    }
    float luma = dot(shown, float3(0.299, 0.587, 0.114));
    return mix(shown, overcast_colour * (0.35 + 0.65 * luma), clamp(overcast, 0.0, 1.0));
}

static float2 ae3d_shaders_sea_sea_oct_uv(float3 d_in, float size) {
    float3 d = d_in / (abs(d_in.x) + abs(d_in.y) + abs(d_in.z));
    float2 p = d.xz;
    if (d.y < 0.0) {
        p = (float2(1.0) - abs(p.yx)) * float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    }
    return ((p * 0.5 + float2(0.5)) * (size - 2.0) + float2(1.0)) / size;
}

static float ae3d_shaders_sea_sea_fbm(float2 st_in) {
    float2 st = st_in;
    float value = 0.0;
    float amplitude = 0.5;
    float2x2 rotation = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 6; i += 1) {
        value = value + amplitude * ae3d_shaders_sea_sea_noise(st);
        st = (rotation * st) * 2.31;
        amplitude = amplitude * 0.53;
    }
    return value;
}

static float ae3d_shaders_sea_sea_ridged(float2 st) {
    float n = ae3d_shaders_sea_sea_fbm(st);
    return 1.0 - abs(n * 2.0 - 1.0);
}

static float3 ae3d_shaders_sea_reflected_sky(float3 ray_in, int sky_capture, texture2d<float> sky_light, sampler ae_smp_sky_light, int sky_texture, texture2d<float> sky_image, sampler ae_smp_sky_image, float3 sky_colour, float3 horizon_colour, float overcast, float3 overcast_colour) {
    float3 ray = float3(ray_in.x, abs(ray_in.y), ray_in.z);
    if (sky_capture == 1) {
        return sky_light.sample(ae_smp_sky_light, ae3d_shaders_sea_sea_oct_uv(normalize(ray), 256.0), level(0.5)).rgb;
    }
    if (sky_texture == 1) {
        float theta = atan2(ray.z, ray.x);
        float phi = asin(clamp(ray.y, -1.0, 1.0));
        float3 shown = sky_image.sample(ae_smp_sky_image, float2((theta + 3.14159265) / 6.28318531, (phi + 1.57079633) / 3.14159265), level(0.0)).rgb;
        return ae3d_shaders_skydome_display_radiance(ae3d_shaders_sea_overcast_sky(shown, overcast, overcast_colour));
    }
    float3 zenith = ae3d_shaders_skydome_display_radiance(ae3d_shaders_sea_overcast_sky(sky_colour, overcast, overcast_colour));
    float3 rim = ae3d_shaders_skydome_display_radiance(ae3d_shaders_sea_overcast_sky(horizon_colour, overcast, overcast_colour));
    return mix(rim, zenith, smoothstep(0.0, 0.35, ray.y));
}

static float ae3d_shaders_sea_sea_perlin(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < octaves; i += 1) {
        value = value + amplitude * ae3d_shaders_sea_sea_noise(p * frequency);
        amplitude = amplitude * 0.5;
        frequency = frequency * 2.0;
    }
    return value;
}

static float ae3d_shaders_sea_sea_caustics(float3 world, float time, int on, float scale, float intensity, float3 eye) {
    if (on == 0) {
        return 0.0;
    }
    float2 coord = world.xz * scale;
    float2 warp1 = float2(ae3d_shaders_sea_sea_perlin(coord * 0.5 + float2(time * 0.02), 2), ae3d_shaders_sea_sea_perlin(coord * 0.5 + float2(time * 0.025) + float2(5.2, 1.3), 2));
    float caustic1 = ae3d_shaders_sea_sea_perlin(coord + warp1 * 0.3 + float2(time * 0.015), 3);
    float2 warp2 = float2(ae3d_shaders_sea_sea_perlin(coord * 0.8 - float2(time * 0.018), 2), ae3d_shaders_sea_sea_perlin(coord * 0.8 - float2(time * 0.022) + float2(3.7, 2.1), 2));
    float caustic2 = ae3d_shaders_sea_sea_perlin(coord * 1.3 + warp2 * 0.25 - float2(time * 0.012), 3);
    float caustic3 = ae3d_shaders_sea_sea_perlin(coord * 2.0 + float2(time * 0.03), 2);
    float combined = caustic1 * 0.5 + caustic2 * 0.3 + caustic3 * 0.2;
    combined = pow(abs(combined), 2.5) * 1.3;
    combined = smoothstep(0.2, 0.8, combined);
    float attenuation = 1.0 / (1.0 + length(world.xz - eye.xz) * 0.00005);
    return combined * intensity * attenuation;
}

static float2 ae3d_shaders_skydome_velocity(float4 now, float4 prev, float2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) {
        return float2(0.0);
    }
    float2 uv_now = now.xy / now.w * 0.5 + float2(0.5) - nudge;
    float2 uv_prev = prev.xy / prev.w * 0.5 + float2(0.5);
    return uv_now - uv_prev;
}

fragment ae_sea_frag_out ae_sea_fragment(
    ae_sea_in ae_in [[stage_in]],
    constant ae_Params& ae_params [[buffer(0)]],
    texture2d<float> ripple_mask [[texture(0)]], sampler ae_smp_ripple_mask [[sampler(0)]],
    texture2d<float> sky_irradiance [[texture(1)]], sampler ae_smp_sky_irradiance [[sampler(1)]],
    texture2d<float> sky_light_map [[texture(2)]], sampler ae_smp_sky_light_map [[sampler(2)]],
    texture2d<float> sky_image [[texture(3)]], sampler ae_smp_sky_image [[sampler(3)]],
    texture2d<float> scene_depth [[texture(4)]], sampler ae_smp_scene_depth [[sampler(4)]]) {
    ae_sea_frag_out ae_out;
    float4 ae_frag_coord = ae_in.ae_frag_coord;
    float3 world = ae_in.world;
    float4 clip_now = ae_in.clip_now;
    float4 clip_prev = ae_in.clip_prev;
    float eye_below = ae_in.eye_below;
    constant KeyLight& key = ae_params.key;
    constant Eye& eye = ae_params.eye;
    constant Water& water = ae_params.water;
    constant Weather& weather = ae_params.weather;
    float3 light_dir = float3(0.0);
    if (key.direction.x != 0.0 || key.direction.y != 0.0 || key.direction.z != 0.0) {
        light_dir = normalize(key.direction);
    } else {
        light_dir = normalize(key.position - world);
    }
    float3 view_dir = normalize(eye.position - world);
    float distance_from_camera = length(eye.position - world);
    float far = smoothstep(0.0, eye.far * 0.35, distance_from_camera);
    float2 p = world.xz;
    float t = water.time;
    float dhx = 0.0;
    float dhz = 0.0;
    float sx = 0.0;
    float sz = 0.0;
    float slope_max = 0.0;
    float speed_mul = max(water.speed, 0.001);
    float field_height = 0.0;
    for (int i = 0; i < 4; i += 1) {
        float2 td = normalize(water.directions[i].xyz.xz);
        float tk = water.frequencies[i].x;
        float ta = water.amplitudes[i].x * water.height * 1.5;
        float t_lambda = 6.28318531 / max(tk, 0.000001);
        float t_fade = 1.0 - smoothstep(t_lambda * 40.0, t_lambda * 160.0, distance_from_camera);
        float t_phase = dot(td, p) * tk + t * water.speeds[i].x * speed_mul + water.phases[i].x + ae3d_shaders_sea_sea_noise(p * tk * 0.2 + float2(float(i) * 4.1, 0.0)) * 1.2;
        float tc = cos(t_phase) * ta * tk * t_fade;
        field_height = field_height + ta * sin(t_phase) * t_fade;
        sx = sx + td.x * tc;
        sz = sz + td.y * tc;
        slope_max = slope_max + ta * tk * t_fade;
    }
    dhx = sx;
    dhz = sz;
    float2 wind = normalize(water.directions[0].xyz.xz);
    float k0 = water.frequencies[3].x;
    float sets = 0.55 + 0.9 * ae3d_shaders_sea_sea_noise(p * k0 * 0.03 + float2(t * 0.004, 0.0));
    float2 warp = float2(ae3d_shaders_sea_sea_noise(p * k0 * 0.12 + float2(3.1, 7.7)), ae3d_shaders_sea_sea_noise(p * k0 * 0.12 + float2(9.2, 1.3))) * 2.0 - float2(1.0);
    for (int j = 1; j <= 4; j += 1) {
        float wk = k0 * pow(1.65, float(j));
        float turn = sin(float(j) * 2.3 + float((j * j)) * 0.61) * 0.5;
        float2 wd = float2(wind.x * cos(turn) - wind.y * sin(turn), wind.x * sin(turn) + wind.y * cos(turn));
        float wa = 0.028 / wk;
        float w_lambda = 6.28318531 / wk;
        float w_fade = (1.0 - smoothstep(w_lambda * 40.0, w_lambda * 160.0, distance_from_camera)) * sets;
        float w_bend = (warp.x * wd.y - warp.y * wd.x) * 2.4;
        float w_phase = dot(wd, p) * wk + t * sqrt(9.81 * wk) * speed_mul + float(j) * 1.7 + w_bend;
        float wc = cos(w_phase) * wa * wk * w_fade;
        field_height = field_height + wa * sin(w_phase) * w_fade;
        dhx = dhx + wd.x * wc;
        dhz = dhz + wd.y * wc;
        slope_max = slope_max + wa * wk * w_fade;
    }
    float kc = k0 * pow(1.65, 5.0);
    for (int m = 0; m < 3; m += 1) {
        float ck = kc * pow(2.1, float(m));
        float c_lambda = 6.28318531 / ck;
        float c_fade = (1.0 - smoothstep(c_lambda * 40.0, c_lambda * 160.0, distance_from_camera)) * sets;
        if (c_fade <= 0.0) {
            continue;
        }
        float ca = 0.16 / ck;
        float2 st = p * (ck / 6.28318531) - wind * (t * sqrt(9.81 * ck) * speed_mul / 6.28318531) + float2(float(m) * 17.3, float(m) * 5.9);
        float3 cn = ae3d_shaders_sea_sea_noised(st);
        field_height = field_height + ca * (cn.x - 0.5) * c_fade;
        float c_slope = ca * ck / 6.28318531 * c_fade;
        dhx = dhx + cn.y * c_slope;
        dhz = dhz + cn.z * c_slope;
        slope_max = slope_max + c_slope * 1.5;
    }
    float3 norm = normalize(float3(-dhx, 1.0, -dhz));
    float3 swell = normalize(float3(-sx, 1.0, -sz));
    float steep = clamp(length(float2(dhx, dhz)) / max(slope_max * 0.5, 0.0001), 0.0, 1.0);
    if (water.normal_mapping != 0) {
        norm = normalize(mix(float3(0.0, 1.0, 0.0), norm, water.normal_intensity));
        swell = normalize(mix(float3(0.0, 1.0, 0.0), swell, water.normal_intensity));
    }
    if (water.ripples == 1) {
        float2 ruv = (p - float2(water.ripple_area.x, water.ripple_area.y)) * water.ripple_area.z;
        if (ruv.x > 0.0 && ruv.y > 0.0 && ruv.x < 1.0 && ruv.y < 1.0) {
            float2 slope = (ripple_mask.sample(ae_smp_ripple_mask, ruv).xy * 2.0 - float2(1.0)) * 0.6;
            float3 tilt = float3(-slope.x, 0.0, -slope.y);
            norm = normalize(norm + tilt);
            swell = normalize(swell + tilt);
        }
    }
    float ripple_freq = water.frequencies[3].x * 9.0 / 6.28318531;
    float ripple_time = water.time * water.speeds[3].x * max(water.speed, 0.001) * 0.35;
    float bend = water.distortion != 0 ? clamp(water.distortion_intensity, 0.0, 1.0) * 0.6 : 0.12;
    bend = bend * (1.0 - 0.7 * far);
    float3 mirror_norm = normalize(mix(swell, norm, bend));
    float3 half_dir = normalize(light_dir + view_dir);
    float n_dot_v = max(dot(norm, view_dir), 0.001);
    float n_dot_l = max(dot(norm, light_dir), 0.0);
    float n_dot_h = max(dot(norm, half_dir), 0.0);
    float v_dot_h = max(dot(view_dir, half_dir), 0.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(mirror_norm, view_dir), 0.001), 5.0);
    float mirror = water.reflection != 0 ? clamp(water.reflection_intensity, 0.0, 1.0) : 0.0;
    float3 sun = key.colour * key.intensity;
    float3 sky_lit = ae3d_shaders_skydome_display_radiance(ae3d_shaders_sea_overcast_sky(water.sky_colour, weather.overcast, weather.overcast_colour));
    if (water.sky_capture == 1) {
        sky_lit = sky_irradiance.sample(ae_smp_sky_irradiance, ae3d_shaders_sea_sea_oct_uv(float3(0.0, 1.0, 0.0), 16.0)).rgb / 3.14159265;
    }
    float roughness = mix(0.07, 0.22, far);
    float alpha_r = roughness * roughness;
    float alpha2 = alpha_r * alpha_r;
    float denom = n_dot_h * n_dot_h * (alpha2 - 1.0) + 1.0;
    float ggx_d = alpha2 / (3.14159265 * denom * denom);
    float ggx_k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    float ggx_g = n_dot_v / (n_dot_v * (1.0 - ggx_k) + ggx_k) * (n_dot_l / (n_dot_l * (1.0 - ggx_k) + ggx_k));
    float ggx_fs = 0.02 + 0.98 * pow(1.0 - v_dot_h, 5.0);
    float3 glitter = sun * (ggx_d * ggx_g * ggx_fs) / (4.0 * n_dot_l * n_dot_v + 0.0001) * n_dot_l;
    float3 base = water.colour;
    if (base.x == 0.0 && base.y == 0.0 && base.z == 0.0) {
        base = float3(0.02, 0.08, 0.14);
    }
    float3 body = base * (sky_lit * 0.7 + sun * (0.12 + 0.30 * n_dot_l));
    float tallest = (water.amplitudes[0].x + water.amplitudes[1].x + water.amplitudes[2].x + water.amplitudes[3].x) * water.height;
    float crest = clamp(field_height / max(tallest, 0.001), 0.0, 1.0);
    float through = pow(clamp(dot(view_dir, -light_dir), 0.0, 1.0), 3.0) * (0.3 + 0.7 * crest) + crest * 0.25 * n_dot_l;
    float3 scatter = (base * 2.5 + float3(0.0, 0.06, 0.04)) * sun * 0.30 * through;
    float foam = 0.0;
    if (water.foam != 0 && tallest > 0.0) {
        float torn = ae3d_shaders_sea_sea_ridged(p * ripple_freq * 0.08 + float2(water.time * 0.02));
        float breaking = smoothstep(0.45, 0.9, steep) * (0.4 + 0.6 * crest);
        foam = breaking * (0.35 + 0.65 * smoothstep(0.35, 0.8, torn));
        foam = foam * (0.55 + 0.45 * ae3d_shaders_sea_sea_noise(p * ripple_freq * 1.5 + float2(ripple_time * 0.5)));
        foam = foam * (clamp(water.foam_intensity, 0.0, 2.0) * (1.0 - 0.7 * far));
        foam = clamp(foam, 0.0, 1.0);
    }
    float3 sky_hit = ae3d_shaders_sea_reflected_sky(reflect(-view_dir, mirror_norm), water.sky_capture, sky_light_map, ae_smp_sky_light_map, water.sky_texture, sky_image, ae_smp_sky_image, water.sky_colour, water.horizon_colour, weather.overcast, weather.overcast_colour);
    float3 final_colour = mix(body + scatter, sky_hit, fresnel * mirror) + glitter * (1.0 - 0.6 * foam);
    float3 foam_lit = float3(0.85) * (sun * 0.5 * max(light_dir.y, 0.0) + sky_lit * 0.6);
    final_colour = mix(final_colour, foam_lit, foam);
    float caustic = ae3d_shaders_sea_sea_caustics(world, water.time, water.caustics, water.caustics_scale, water.caustics_intensity, eye.position);
    final_colour = final_colour + sun * caustic * 0.1;
    if (weather.fog != 0) {
        float haze = smoothstep(weather.fog_start, weather.fog_end, distance_from_camera) * weather.fog_intensity;
        final_colour = mix(final_colour, weather.fog_radiance, clamp(haze, 0.0, 1.0));
    }
    float below = 1000.0;
    if (eye.depth_on == 1) {
        float2 suv = ae_frag_coord.xy / eye.screen_size;
        float dd = scene_depth.sample(ae_smp_scene_depth, suv).x;
        if (dd < 0.99999) {
            float2 ndc = suv * 2.0 - float2(1.0);
            float4 clip = float4(float3(ndc.x, ndc.y, dd), 1.0);
            float4 at = (eye.inv_view_projection * clip);
            float3 ground = at.xyz / at.w;
            below = max(distance(eye.position, ground) - distance(eye.position, world), 0.0);
        }
    }
    float clear = 1.0 - exp(-below / max(water.depth_fade, 0.01));
    if (eye.depth_on == 1 && below < 999.0) {
        float wash = 1.0 - smoothstep(0.0, max(water.shore_foam, 0.01), below);
        float lace = 0.5 + 0.5 * ae3d_shaders_sea_sea_noise(p * ripple_freq * 0.8 + float2(ripple_time * 0.3));
        float shore_foam = wash * wash * lace * 0.9;
        float3 shore_lit = float3(0.9) * (sun * 0.5 * max(light_dir.y, 0.0) + sky_lit * 0.6);
        final_colour = mix(final_colour, shore_lit, clamp(shore_foam, 0.0, 1.0));
        foam = max(foam, shore_foam);
    }
    float alpha = water.opacity;
    if (alpha <= 0.01) {
        alpha = 0.85;
    }
    alpha = mix(alpha, 1.0, fresnel * mirror);
    alpha = alpha * clear;
    alpha = mix(alpha, 1.0, foam);
    float underwater_depth = max(0.0, eye_below);
    if (underwater_depth > 0.0) {
        float3 sky_through = ae3d_shaders_skydome_display_radiance(ae3d_shaders_sea_overcast_sky(water.sky_colour, weather.overcast, weather.overcast_colour));
        float3 through_sky = mix(sky_through, water.colour * sky_through, 0.35);
        float3 under = normalize(mix(float3(0.0, 1.0, 0.0), norm, 0.35));
        float overhead = clamp(dot(under, -view_dir), 0.0, 1.0);
        float window = smoothstep(0.15, 0.75, overhead);
        float3 underside = mix(water.colour * sky_through * 0.55, through_sky, window);
        float deep = clamp(underwater_depth * 0.0025, 0.0, 0.5);
        final_colour = mix(underside, water.colour * sky_through * 0.5, deep);
        float3 refracted = normalize(reflect(-view_dir, under));
        float glint = pow(max(0.0, dot(refracted, light_dir)), 48.0);
        final_colour = final_colour + key.colour * glint * 0.8 * window;
        final_colour = final_colour + float3(caustic * 0.35) * window;
        float underwater_fog = clamp(distance_from_camera * 0.0002, 0.0, 0.85);
        float3 murk = water.colour * sky_through * 0.4;
        if (weather.fog != 0) {
            underwater_fog = smoothstep(weather.fog_start, weather.fog_end, distance_from_camera) * weather.fog_intensity;
            murk = weather.fog_radiance;
        }
        final_colour = mix(final_colour, murk, underwater_fog);
    }
    alpha = clamp(alpha, 0.001, 0.98);
    ae_out.out_colour = float4(final_colour, alpha);
    ae_out.out_velocity = float4(ae3d_shaders_skydome_velocity(clip_now, clip_prev, eye.jitter), 0.0, 0.0);
    return ae_out;
}
