#version 410 core
// world_text_vertex: written by ae3d.gpu from its quote.

uniform mat4 view_projection;
uniform mat4 prev_view_projection;
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in mat4 instanceModel;
layout(location = 10) in float inOcclusion;

out vec2 uv;
out vec3 colour;
out float alpha;
out vec4 clip_now;
out vec4 clip_prev;

vec3 ae3d_shaders_lettering_text_place(vec3 origin, vec3 right, vec3 up, float x, float y) {
    return origin + right * x - up * y;
}

void main() {
    vec4 right = instanceModel[0];
    vec3 world = ae3d_shaders_lettering_text_place(instanceModel[2].xyz, right.xyz, instanceModel[1].xyz, inPosition.x, inPosition.y);
    vec4 now = (view_projection * vec4(world, 1.0));
    vec4 prev = (prev_view_projection * vec4(world, 1.0));
    float z = mix(now.z, (0.0001 * 2.0 - 1.0) * now.w, right.w);
    gl_Position = vec4(vec3(now.x, now.y, z), now.w);
    uv = inTexCoord;
    colour = inNormal;
    alpha = inOcclusion;
    clip_now = now;
    clip_prev = prev;
}
