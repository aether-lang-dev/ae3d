#version 450
// sky_irradiance: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    vec3 ground_albedo;
    vec3 ground_sun;
};
layout(set = 0, binding = 1) uniform sampler2D capture;

vec3 ae3d_shaders_skyprobe_oct_decode(vec2 p) {
    vec3 d = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        d = vec3((1.0 - abs(d.z)) * (d.x >= 0.0 ? 1.0 : -1.0), d.y, (1.0 - abs(d.x)) * (d.z >= 0.0 ? 1.0 : -1.0));
    }
    return normalize(d);
}

vec3 ae3d_shaders_skyprobe_oct_texel_direction(vec2 uv, float size) {
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
    return ae3d_shaders_skyprobe_oct_decode(vec2(px, py));
}

vec3 ae3d_shaders_skyprobe_capture_q(float x, float y) {
    float u = (x + 0.5) / 16.0;
    float v = (y + 0.5) / 16.0;
    float px = clamp((u * 256.0 - 1.0) / (256.0 - 2.0) * 2.0 - 1.0, -1.0, 1.0);
    float py = clamp((v * 256.0 - 1.0) / (256.0 - 2.0) * 2.0 - 1.0, -1.0, 1.0);
    vec3 q = vec3(px, 1.0 - abs(px) - abs(py), py);
    if (q.y < 0.0) {
        q = vec3((1.0 - abs(q.z)) * (q.x >= 0.0 ? 1.0 : -1.0), q.y, (1.0 - abs(q.x)) * (q.z >= 0.0 ? 1.0 : -1.0));
    }
    return q;
}

layout(location = 0) in vec2 uv_in;
layout(location = 0) out vec4 FragColor;

void main() {
    vec2 fc = gl_FragCoord.xy;
    vec3 n = ae3d_shaders_skyprobe_oct_texel_direction(vec2(fc.x / 16.0, fc.y / 16.0), 16.0);
    bool grounded = ground_albedo.x + ground_albedo.y + ground_albedo.z > 0.0;
    vec3 ground = vec3(0.0, 0.0, 0.0);
    if (grounded) {
        vec3 up = vec3(0.0, 0.0, 0.0);
        float whole = 0.0;
        float y = 0.0;
        while (y < 16.0) {
            float x = 0.0;
            while (x < 16.0) {
                vec3 q = ae3d_shaders_skyprobe_capture_q(x, y);
                float len = length(q);
                float angle = 1.0 / (len * len * len);
                vec3 l = q / len;
                if (l.y > 0.0) {
                    up = up + texelFetch(capture, ivec2(x, y), int(4.0)).rgb * l.y * angle;
                }
                whole = whole + angle;
                x = x + 1.0;
            }
            y = y + 1.0;
        }
        up = up * (4.0 * 3.14159265 / whole);
        ground = ground_albedo * (up + ground_sun) / 3.14159265;
    }
    vec3 sum = vec3(0.0, 0.0, 0.0);
    float total = 0.0;
    float y = 0.0;
    while (y < 16.0) {
        float x = 0.0;
        while (x < 16.0) {
            vec3 q = ae3d_shaders_skyprobe_capture_q(x, y);
            float len = length(q);
            float angle = 1.0 / (len * len * len);
            vec3 l = q / len;
            vec3 seen = grounded && l.y < 0.0 ? ground : texelFetch(capture, ivec2(x, y), int(4.0)).rgb;
            sum = sum + seen * max(dot(n, l), 0.0) * angle;
            total = total + angle;
            x = x + 1.0;
        }
        y = y + 1.0;
    }
    FragColor = vec4(sum * (4.0 * 3.14159265 / total), 1.0);
}
