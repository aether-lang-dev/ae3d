#version 410 core
// sky_vertex: written by ae3d.gpu from its quote.

uniform mat4 projection;
uniform mat4 view;
uniform mat4 prev_view_projection;
layout(location = 0) in vec3 inPosition;

out vec3 tex_coords;
out vec4 clip_now;
out vec4 clip_prev;

void main() {
    vec4 pos = ((projection * view) * vec4(inPosition, 1.0));
    gl_Position = vec4(vec3(pos.x, pos.y, pos.w), pos.w);
    tex_coords = inPosition;
    clip_now = pos;
    clip_prev = (prev_view_projection * vec4(inPosition, 0.0));
}
