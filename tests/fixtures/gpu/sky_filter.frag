#version 450
// sky_filter: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    float level_size;
    float roughness;
};
layout(set = 0, binding = 1) uniform sampler2D capture;

vec3 skyprobe_oct_decode(vec2 p) {
    vec3 d = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        d = vec3((1.0 - abs(d.z)) * (d.x >= 0.0 ? 1.0 : -1.0), d.y, (1.0 - abs(d.x)) * (d.z >= 0.0 ? 1.0 : -1.0));
    }
    return normalize(d);
}

vec3 skyprobe_oct_texel_direction(vec2 uv, float size) {
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
    return skyprobe_oct_decode(vec2(px, py));
}

vec2 skyprobe_oct_encode(vec3 d) {
    vec3 e = d / (abs(d.x) + abs(d.y) + abs(d.z));
    vec2 p = vec2(e.x, e.z);
    if (e.y < 0.0) {
        p = (1.0 - abs(p.yx)) * vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    }
    return p;
}

vec2 skyprobe_oct_uv(vec3 d, float size) {
    return ((skyprobe_oct_encode(d) * 0.5 + 0.5) * (size - 2.0) + 1.0) / size;
}

float skyprobe_radical_inverse(float i) {
    float r = 0.0;
    float f = 0.5;
    float n = i;
    while (n >= 1.0) {
        float half_ = floor(n * 0.5);
        if (n - half_ * 2.0 >= 1.0) {
            r = r + f;
        }
        f = f * 0.5;
        n = half_;
    }
    return r;
}

layout(location = 0) in vec2 uv_in;
layout(location = 0) out vec4 FragColor;

void main() {
    vec3 n = skyprobe_oct_texel_direction(gl_FragCoord.xy / level_size, 256.0);
    if (roughness <= 0.0) {
        FragColor = vec4(textureLod(capture, skyprobe_oct_uv(n, 256.0), 0.0).rgb, 1.0);
        return;
    }
    float a = roughness * roughness;
    vec3 up = abs(n.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 t = normalize(cross(up, n));
    vec3 b = cross(n, t);
    float texel = 4.0 * 3.14159265 / ((256.0 - 2.0) * (256.0 - 2.0));
    vec3 sum = vec3(0.0, 0.0, 0.0);
    float weight = 0.0;
    for (int i = 0; i < 48; i += 1) {
        vec2 xi = vec2((float(i) + 0.5) / 48.0, skyprobe_radical_inverse(float(i)));
        float phi = 6.28318531 * xi.y;
        float cos_theta = sqrt((1.0 - xi.x) / (1.0 + (a * a - 1.0) * xi.x));
        float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
        vec3 h = t * (sin_theta * cos(phi)) + b * (sin_theta * sin(phi)) + n * cos_theta;
        vec3 l = 2.0 * dot(n, h) * h - n;
        float n_dot_l = dot(n, l);
        if (n_dot_l <= 0.0) {
            continue;
        }
        float d = cos_theta * cos_theta * (a * a - 1.0) + 1.0;
        float pdf = a * a / (3.14159265 * d * d) / 4.0;
        float sample_angle = 1.0 / (48.0 * pdf + 0.000001);
        float lod = max(0.5 * log2(sample_angle / texel) + 1.0, 0.0);
        sum += textureLod(capture, skyprobe_oct_uv(l, 256.0), lod).rgb * n_dot_l;
        weight += n_dot_l;
    }
    FragColor = vec4(sum / max(weight, 0.000001), 1.0);
}
