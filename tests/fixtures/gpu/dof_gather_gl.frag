#version 410 core
// dof_gather: written by ae3d.gpu from its quote.

uniform float max_radius;
uniform vec2 texel;
uniform sampler2D coc;

float ae3d_shaders_dof_tap_weight(float tap, float dist, float own) {
    float reach = clamp(abs(tap) - dist + 0.5, 0.0, 1.0);
    if (tap > 0.0) {
        return reach * clamp(own, 0.0, 1.0);
    }
    return reach;
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec4 centre = texture(coc, uv);
    float own = abs(centre.w);
    vec3 sum = centre.rgb;
    float total = 1.0;
    float near = 0.0;
    float widest = 0.0;
    int i = 0;
    while (i < 32) {
        float k = float(i);
        float a = k * 2.3999632;
        float reach = sqrt((k + 0.5) / 32.0) * max_radius;
        vec4 tap = texture(coc, uv + vec2(cos(a), sin(a) * 1.0) * reach * texel);
        float w = ae3d_shaders_dof_tap_weight(tap.w, reach, own);
        sum = sum + tap.rgb * w;
        total = total + w;
        if (tap.w < 0.0 && w > 0.0) {
            near = near + w;
            widest = max(widest, abs(tap.w));
        }
        i = i + 1;
    }
    float ring = max(16.0 * widest * widest / (max_radius * max_radius), 1.0);
    float blend = max(clamp(own, 0.0, 1.0), clamp(near / ring, 0.0, 1.0));
    FragColor = vec4(sum / total, blend);
}
