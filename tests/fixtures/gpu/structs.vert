#version 450
// sky_like: written by ae3d.gpu from its quote.

layout(std140, set = 1, binding = 0) uniform VertexParams {
    mat4 projection;
    mat4 view;
    mat4 prev;
};
layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec3 tex_coords;
layout(location = 1) out vec4 clip_now;
layout(location = 2) out vec4 clip_prev;
layout(location = 3) flat out int layer;

void main() {
    vec4 pos = ((projection * view) * vec4(inPosition, 1.0));
    gl_Position = vec4(vec3(pos.x, pos.y, pos.w), pos.w);
    tex_coords = inPosition;
    clip_now = pos;
    clip_prev = (prev * vec4(inPosition, 0.0));
    layer = 3;
}
