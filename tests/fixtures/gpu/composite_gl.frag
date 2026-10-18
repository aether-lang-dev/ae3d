#version 410 core
// composite: written by ae3d.gpu from its quote.

struct Haze {
    int count;
    vec4 column[4];
    vec4 shape[4];
};
uniform Haze haze;
uniform int capture_channel;
uniform mat4 view_projection;
uniform int bloom_on;
uniform float bloom_intensity;
uniform float frame_exposure;
uniform sampler2D screen;
uniform sampler2D bloom;

struct HazePoint {
    vec2 at;
    float w;
};

HazePoint ae3d_shaders_composite_haze_screen(mat4 view_projection, vec3 p) {
    vec4 c = (view_projection * vec4(p, 1.0));
    return HazePoint(c.xy / max(c.w, 0.0001) * 0.5 + vec2(0.5), c.w);
}

float ae3d_shaders_composite_haze_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ae3d_shaders_composite_haze_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f0 = fract(p);
    vec2 f = f0 * f0 * (vec2(3.0) - f0 * 2.0);
    return mix(mix(ae3d_shaders_composite_haze_hash(i), ae3d_shaders_composite_haze_hash(i + vec2(1.0, 0.0)), f.x), mix(ae3d_shaders_composite_haze_hash(i + vec2(0.0, 1.0)), ae3d_shaders_composite_haze_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 ae3d_shaders_composite_aces(vec3 x) {
    return clamp(x * (x * 2.51 + vec3(0.03)) / (x * (x * 2.43 + vec3(0.59)) + vec3(0.14)), vec3(0.0), vec3(1.0));
}

float ae3d_shaders_composite_srgb_encode(float c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec2 at = uv;
    if (haze.count > 0 && capture_channel == 0) {
        vec2 offset = vec2(0.0, 0.0);
        int k = 0;
        while (k < 4) {
            int kk = k;
            k = k + 1;
            if (kk >= haze.count) {
                break;
            }
            vec4 column = haze.column[kk];
            vec4 shape = haze.shape[kk];
            HazePoint hb = ae3d_shaders_composite_haze_screen(view_projection, column.xyz);
            HazePoint ht = ae3d_shaders_composite_haze_screen(view_projection, column.xyz + vec3(0.0, shape.x, 0.0));
            if (hb.w <= 0.0 || ht.w <= 0.0) {
                continue;
            }
            vec2 b = hb.at;
            vec2 axis = ht.at - b;
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
            vec2 q = vec2(across * 3.0 + float(kk) * 7.1, along * 7.0 - shape.z);
            vec2 n = vec2(ae3d_shaders_composite_haze_noise(q * 2.3), ae3d_shaders_composite_haze_noise(q * 2.3 + vec2(17.3, 5.9))) - vec2(0.5);
            offset = offset + n * amount * width * 0.18;
        }
        at = at + offset;
    }
    vec3 radiance = texture(screen, at).rgb;
    if (capture_channel != 0) {
        FragColor = vec4(radiance, 1.0);
        return;
    }
    if (bloom_on != 0) {
        radiance = radiance + texture(bloom, at).rgb * bloom_intensity;
    }
    vec3 shown = ae3d_shaders_composite_aces(radiance * frame_exposure);
    shown = vec3(ae3d_shaders_composite_srgb_encode(shown.x), ae3d_shaders_composite_srgb_encode(shown.y), ae3d_shaders_composite_srgb_encode(shown.z));
    float noise = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    FragColor = vec4(shown + vec3(noise / 255.0), 1.0);
}
