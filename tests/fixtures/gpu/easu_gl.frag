#version 410 core
// easu: written by ae3d.gpu from its quote.

uniform vec2 size;
uniform sampler2D screen;

struct EdgeAxis {
    float x;
    float y;
    float z;
};

vec3 ae3d_shaders_upscale_root3(vec3 c) {
    return vec3(sqrt(max(c.x, 0.0)), sqrt(max(c.y, 0.0)), sqrt(max(c.z, 0.0)));
}

vec3 ae3d_shaders_upscale_tap_root(sampler2D screen, vec2 p, vec2 size) {
    vec2 q = clamp(p, vec2(0.0, 0.0), size - vec2(1.0, 1.0));
    return ae3d_shaders_upscale_root3(texelFetch(screen, ivec2(q), 0).rgb);
}

float ae3d_shaders_upscale_luma_of(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

EdgeAxis ae3d_shaders_upscale_edge_axis(float gxx, float gyy, float gxy) {
    float a = gxx - gyy;
    float tr = gxx + gyy;
    float disc = sqrt(a * a + 4.0 * gxy * gxy);
    float vx = (a + disc) * 0.5;
    float vy = gxy;
    if (a < 0.0) {
        vx = gxy;
        vy = (disc - a) * 0.5;
    }
    float len2 = vx * vx + vy * vy;
    if (len2 < 0.00000001) {
        return EdgeAxis(1.0, 0.0, 0.0);
    }
    float inv = inversesqrt(len2);
    float coherence = disc / max(tr, 0.00000001);
    float size = clamp(tr * 32.0, 0.0, 1.0);
    return EdgeAxis(vx * inv, vy * inv, coherence * size);
}

float ae3d_shaders_upscale_lobe_weight(float d) {
    if (d < 1.0) {
        return (1.5 * d - 2.5) * d * d + 1.0;
    }
    if (d < 2.0) {
        return ((-0.5 * d + 2.5) * d - 4.0) * d + 2.0;
    }
    return 0.0;
}

float ae3d_shaders_upscale_tap_weight(float ox, float oy, EdgeAxis ax) {
    float across = ox * ax.x + oy * ax.y;
    float along = oy * ax.x - ox * ax.y;
    float sa = across * (1.0 + 0.6 * ax.z);
    float sl = along * (1.0 - 0.4 * ax.z);
    return ae3d_shaders_upscale_lobe_weight(sqrt(sa * sa + sl * sl));
}

vec3 ae3d_shaders_upscale_square3(vec3 c) {
    return vec3(c.x * c.x, c.y * c.y, c.z * c.z);
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec2 p = uv * size - vec2(0.5, 0.5);
    vec2 b = floor(p);
    float fx = p.x - b.x;
    float fy = p.y - b.y;
    vec3 t0m1 = ae3d_shaders_upscale_tap_root(screen, b + vec2(0.0, -1.0), size);
    vec3 t1m1 = ae3d_shaders_upscale_tap_root(screen, b + vec2(1.0, -1.0), size);
    vec3 tm10 = ae3d_shaders_upscale_tap_root(screen, b + vec2(-1.0, 0.0), size);
    vec3 t00 = ae3d_shaders_upscale_tap_root(screen, b, size);
    vec3 t10 = ae3d_shaders_upscale_tap_root(screen, b + vec2(1.0, 0.0), size);
    vec3 t20 = ae3d_shaders_upscale_tap_root(screen, b + vec2(2.0, 0.0), size);
    vec3 tm11 = ae3d_shaders_upscale_tap_root(screen, b + vec2(-1.0, 1.0), size);
    vec3 t01 = ae3d_shaders_upscale_tap_root(screen, b + vec2(0.0, 1.0), size);
    vec3 t11 = ae3d_shaders_upscale_tap_root(screen, b + vec2(1.0, 1.0), size);
    vec3 t21 = ae3d_shaders_upscale_tap_root(screen, b + vec2(2.0, 1.0), size);
    vec3 t02 = ae3d_shaders_upscale_tap_root(screen, b + vec2(0.0, 2.0), size);
    vec3 t12 = ae3d_shaders_upscale_tap_root(screen, b + vec2(1.0, 2.0), size);
    float l0m1 = ae3d_shaders_upscale_luma_of(t0m1);
    float l1m1 = ae3d_shaders_upscale_luma_of(t1m1);
    float lm10 = ae3d_shaders_upscale_luma_of(tm10);
    float l00 = ae3d_shaders_upscale_luma_of(t00);
    float l10 = ae3d_shaders_upscale_luma_of(t10);
    float l20 = ae3d_shaders_upscale_luma_of(t20);
    float lm11 = ae3d_shaders_upscale_luma_of(tm11);
    float l01 = ae3d_shaders_upscale_luma_of(t01);
    float l11 = ae3d_shaders_upscale_luma_of(t11);
    float l21 = ae3d_shaders_upscale_luma_of(t21);
    float l02 = ae3d_shaders_upscale_luma_of(t02);
    float l12 = ae3d_shaders_upscale_luma_of(t12);
    float gx00 = (l10 - lm10) * 0.5;
    float gy00 = (l01 - l0m1) * 0.5;
    float gx10 = (l20 - l00) * 0.5;
    float gy10 = (l11 - l1m1) * 0.5;
    float gx01 = (l11 - lm11) * 0.5;
    float gy01 = (l02 - l00) * 0.5;
    float gx11 = (l21 - l01) * 0.5;
    float gy11 = (l12 - l10) * 0.5;
    float w00 = (1.0 - fx) * (1.0 - fy);
    float w10 = fx * (1.0 - fy);
    float w01 = (1.0 - fx) * fy;
    float w11 = fx * fy;
    float gxx = w00 * gx00 * gx00 + w10 * gx10 * gx10 + w01 * gx01 * gx01 + w11 * gx11 * gx11;
    float gyy = w00 * gy00 * gy00 + w10 * gy10 * gy10 + w01 * gy01 * gy01 + w11 * gy11 * gy11;
    float gxy = w00 * gx00 * gy00 + w10 * gx10 * gy10 + w01 * gx01 * gy01 + w11 * gx11 * gy11;
    EdgeAxis ax = ae3d_shaders_upscale_edge_axis(gxx, gyy, gxy);
    float k0m1 = ae3d_shaders_upscale_tap_weight(0.0 - fx, -1.0 - fy, ax);
    float k1m1 = ae3d_shaders_upscale_tap_weight(1.0 - fx, -1.0 - fy, ax);
    float km10 = ae3d_shaders_upscale_tap_weight(-1.0 - fx, 0.0 - fy, ax);
    float k00 = ae3d_shaders_upscale_tap_weight(0.0 - fx, 0.0 - fy, ax);
    float k10 = ae3d_shaders_upscale_tap_weight(1.0 - fx, 0.0 - fy, ax);
    float k20 = ae3d_shaders_upscale_tap_weight(2.0 - fx, 0.0 - fy, ax);
    float km11 = ae3d_shaders_upscale_tap_weight(-1.0 - fx, 1.0 - fy, ax);
    float k01 = ae3d_shaders_upscale_tap_weight(0.0 - fx, 1.0 - fy, ax);
    float k11 = ae3d_shaders_upscale_tap_weight(1.0 - fx, 1.0 - fy, ax);
    float k21 = ae3d_shaders_upscale_tap_weight(2.0 - fx, 1.0 - fy, ax);
    float k02 = ae3d_shaders_upscale_tap_weight(0.0 - fx, 2.0 - fy, ax);
    float k12 = ae3d_shaders_upscale_tap_weight(1.0 - fx, 2.0 - fy, ax);
    float total = k0m1 + k1m1 + km10 + k00 + k10 + k20 + km11 + k01 + k11 + k21 + k02 + k12;
    vec3 sum = t0m1 * k0m1 + t1m1 * k1m1 + tm10 * km10 + t00 * k00 + t10 * k10 + t20 * k20 + tm11 * km11 + t01 * k01 + t11 * k11 + t21 * k21 + t02 * k02 + t12 * k12;
    vec3 made = sum / max(total, 0.00000001);
    vec3 lo = min(min(t00, t10), min(t01, t11));
    vec3 hi = max(max(t00, t10), max(t01, t11));
    FragColor = vec4(ae3d_shaders_upscale_square3(max(min(made, hi), lo)), 1.0);
}
