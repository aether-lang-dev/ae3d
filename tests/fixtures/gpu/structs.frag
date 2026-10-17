#version 450
// two_out: written by ae3d.gpu from its quote.

layout(std140, set = 0, binding = 0) uniform Params {
    float gain;
};

struct Sample {
    float density;
    float height;
};

Sample sample_at(vec3 p, bool thick) {
    float h = p.y * 0.5;
    if (p.x <= 0.0) {
        return Sample(0.0, h);
    }
    float d = p.x * 2.0;
    if (thick) {
        d = d + 1.0;
    }
    return Sample(d, h);
}

layout(location = 0) in vec3 tex_coords;
layout(location = 2) in vec4 clip_prev;
layout(location = 0) out vec4 out_colour;
layout(location = 1) out vec2 out_velocity;

void main() {
    Sample s = sample_at(tex_coords, true);
    vec4 c = vec4(tex_coords * s.density, s.height * gain);
    out_colour = c;
    out_velocity = clip_prev.xy;
}
