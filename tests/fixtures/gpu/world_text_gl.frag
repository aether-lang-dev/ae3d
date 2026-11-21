#version 410 core
// world_text: written by ae3d.gpu from its quote.

uniform vec2 jitter;
uniform sampler2D atlas;

float ae3d_shaders_lettering_coverage(float d, float w, float edge) {
    float reach = max(w * 0.5, 0.00001);
    return smoothstep(edge - reach, edge + reach, d);
}

float ae3d_shaders_skydome_aces_inverse(float y_in) {
    float y = clamp(y_in, 0.0, 0.9999);
    float a = 2.51 - 2.43 * y;
    float b = 0.03 - 0.59 * y;
    return (-b + sqrt(b * b + 4.0 * a * 0.14 * y)) / (2.0 * a);
}

float ae3d_shaders_skydome_srgb_decode(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

vec3 ae3d_shaders_skydome_display_radiance(vec3 shown) {
    vec3 c = clamp(shown, vec3(0.0), vec3(1.0));
    return vec3(ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.x)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.y)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.z)));
}

vec2 ae3d_shaders_skydome_velocity(vec4 now, vec4 prev, vec2 nudge) {
    if (now.w <= 0.0 || prev.w <= 0.0) {
        return vec2(0.0);
    }
    vec2 uv_now = now.xy / now.w * 0.5 + vec2(0.5) - nudge;
    vec2 uv_prev = prev.xy / prev.w * 0.5 + vec2(0.5);
    return uv_now - uv_prev;
}

in vec2 uv;
in vec3 colour;
in float alpha;
in vec4 clip_now;
in vec4 clip_prev;
flat in int edge;
layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_velocity;

void main() {
    float d = texture(atlas, uv).x;
    float w = abs(dFdx(d)) + abs(dFdy(d));
    float at_edge = float(edge) / 65536.0;
    float a = ae3d_shaders_lettering_coverage(d, w, at_edge);
    vec2 du = dFdx(uv);
    vec2 dv = dFdy(uv);
    vec2 size = vec2(textureSize(atlas, 0));
    float across = max(length(du * size), length(dv * size));
    if (across > 1.0) {
        float n = min(ceil(across), 4.0);
        float share = w / n;
        float sum = 0.0;
        float j = 0.0;
        while (j < n) {
            float i = 0.0;
            while (i < n) {
                vec2 at = uv + du * ((i + 0.5) / n - 0.5) + dv * ((j + 0.5) / n - 0.5);
                sum = sum + ae3d_shaders_lettering_coverage(textureLod(atlas, at, 0.0).x, share, at_edge);
                i = i + 1.0;
            }
            j = j + 1.0;
        }
        a = mix(a, sum / (n * n), clamp(across - 1.0, 0.0, 1.0));
    }
    a = a * alpha;
    if (a < 0.002) {
        discard;
    }
    out_colour = vec4(ae3d_shaders_skydome_display_radiance(colour), a);
    out_velocity = ae3d_shaders_skydome_velocity(clip_now, clip_prev, jitter);
}
