#version 410 core
// sea_vertex: written by ae3d.gpu from its quote.

struct Water {
    mat4 model;
    float time;
    float speed;
    float height;
    float randomness;
    vec3 directions[4];
    float amplitudes[4];
    float frequencies[4];
    float speeds[4];
    float phases[4];
    float steepness[4];
};
struct Eye {
    mat4 view_projection;
    mat4 prev_view_projection;
    vec3 position;
};
uniform Water surface;
uniform Eye viewer;
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;

out vec2 uv;
out vec3 normal;
out vec3 world;
out vec4 clip_now;
out vec4 clip_prev;
out float eye_below;

float ae3d_shaders_sea_swell_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ae3d_shaders_sea_swell_noise(vec2 p_in, int octaves) {
    vec2 p = p_in;
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i += 1) {
        vec2 i_p = floor(p);
        vec2 f_p0 = fract(p);
        vec2 f_p = f_p0 * f_p0 * (vec2(3.0) - f_p0 * 2.0);
        float a = ae3d_shaders_sea_swell_hash(i_p);
        float b = ae3d_shaders_sea_swell_hash(i_p + vec2(1.0, 0.0));
        float c = ae3d_shaders_sea_swell_hash(i_p + vec2(0.0, 1.0));
        float d = ae3d_shaders_sea_swell_hash(i_p + vec2(1.0, 1.0));
        value = value + amplitude * mix(mix(a, b, f_p.x), mix(c, d, f_p.x), f_p.y);
        amplitude = amplitude * 0.5;
        p = p * 2.0;
    }
    return value;
}

vec3 ae3d_shaders_sea_gerstner(vec3 position, vec3 direction, float amplitude, float frequency, float speed, float phase, float steepness, float time, float speed_multiplier) {
    vec2 d = normalize(direction.xz);
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
    return vec3(q * amplitude * d.x * c, amplitude * sharpened_s, q * amplitude * d.y * c);
}

vec3 ae3d_shaders_sea_gerstner_normal(vec3 position, vec3 direction, float amplitude, float frequency, float speed, float phase, float steepness, float time, float speed_multiplier) {
    vec2 d = normalize(direction.xz);
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
    return vec3(-d.x * wa * c * sharpened_derivative, 1.0 - q * wa * s, -d.y * wa * c * sharpened_derivative);
}

void main() {
    vec3 world0 = (surface.model * vec4(inPosition, 1.0)).xyz;
    vec3 total = vec3(0.0);
    vec3 total_normal = vec3(0.0, 1.0, 0.0);
    for (int i = 0; i < 4; i += 1) {
        float random_factor = 1.0;
        if (surface.randomness > 0.001) {
            float random_noise = ae3d_shaders_sea_swell_noise(world0.xz * 0.01 + vec2(surface.time * 0.1) + vec2(float(i)), 2);
            random_factor = mix(1.0, 0.5 + random_noise, surface.randomness);
        }
        float adjusted = surface.amplitudes[i] * surface.height * random_factor;
        vec3 wave_disp = ae3d_shaders_sea_gerstner(world0, surface.directions[i], adjusted, surface.frequencies[i], surface.speeds[i], surface.phases[i], surface.steepness[i], surface.time, surface.speed);
        vec3 wave_normal = ae3d_shaders_sea_gerstner_normal(world0, surface.directions[i], adjusted, surface.frequencies[i], surface.speeds[i], surface.phases[i], surface.steepness[i], surface.time, surface.speed);
        total = total + wave_disp;
        total_normal = total_normal + wave_normal;
    }
    vec3 lifted = vec3(total.x, total.y * 1.5, total.z);
    vec3 displaced = world0 + lifted;
    vec3 normal_out = normalize(total_normal);
    vec4 now = (viewer.view_projection * vec4(displaced, 1.0));
    vec4 prev = (viewer.prev_view_projection * vec4(displaced, 1.0));
    vec3 eye_at = vec3(viewer.position.x, 0.0, viewer.position.z);
    float over = 0.0;
    for (int j = 0; j < 4; j += 1) {
        float eye_factor = 1.0;
        if (surface.randomness > 0.001) {
            float eye_noise = ae3d_shaders_sea_swell_noise(eye_at.xz * 0.01 + vec2(surface.time * 0.1) + vec2(float(j)), 2);
            eye_factor = mix(1.0, 0.5 + eye_noise, surface.randomness);
        }
        over = over + ae3d_shaders_sea_gerstner(eye_at, surface.directions[j], surface.amplitudes[j] * surface.height * eye_factor, surface.frequencies[j], surface.speeds[j], surface.phases[j], surface.steepness[j], surface.time, surface.speed).y;
    }
    gl_Position = now;
    uv = inTexCoord;
    normal = normal_out;
    world = displaced;
    clip_now = now;
    clip_prev = prev;
    eye_below = surface.model[3][1] + over * 1.5 - viewer.position.y;
}
