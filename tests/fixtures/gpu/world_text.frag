#version 450
// world_text: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    vec2 jitter;
};
layout(set = 0, binding = 1) uniform sampler2D atlas;

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

layout(location = 0) in vec2 uv;
layout(location = 1) in vec3 colour;
layout(location = 2) in float alpha;
layout(location = 3) in vec4 clip_now;
layout(location = 4) in vec4 clip_prev;
layout(location = 5) flat in int edge;
layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_velocity;

void main() {
    float d = texture(atlas, uv).x;
    float w = abs(dFdx(d)) + abs(dFdy(d));
    float a = ae3d_shaders_lettering_coverage(d, w, float(edge) / 65536.0) * alpha;
    if (a < 0.002) {
        discard;
    }
    out_colour = vec4(ae3d_shaders_skydome_display_radiance(colour), a);
    out_velocity = ae3d_shaders_skydome_velocity(clip_now, clip_prev, jitter);
}
