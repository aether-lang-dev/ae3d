#version 450
// crowd_depth_vertex: written by ae3d.gpu from its quote.

struct Throng {
    mat4 model;
    int frames;
};
struct Shadow {
    mat4 light_space;
    vec4 reach;
};
layout(std140, set = 1, binding = 0) uniform VertexParams {
    Throng throng;
    Shadow shadow;
};
layout(set = 1, binding = 1) uniform sampler2D pose_bank;
layout(location = 0) in vec3 inPosition;
layout(location = 3) in mat4 instanceModel;
layout(location = 8) in vec4 inJoints;
layout(location = 9) in vec4 inWeights;
layout(location = 11) in float instancePhase;

layout(location = 0) out vec3 BindPos;
layout(location = 1) out float ClipLimb;

mat4 ae3d_shaders_throng_bone_at(sampler2D bank, int bone, int frame) {
    int x = bone * 4;
    return mat4(texelFetch(bank, ivec2((x + 0), frame), 0), texelFetch(bank, ivec2((x + 1), frame), 0), texelFetch(bank, ivec2((x + 2), frame), 0), texelFetch(bank, ivec2((x + 3), frame), 0));
}

mat4 ae3d_shaders_throng_skin_at(sampler2D bank, vec4 joints, vec4 weights, int frame) {
    return ((((weights.x * ae3d_shaders_throng_bone_at(bank, int(joints.x), frame)) + (weights.y * ae3d_shaders_throng_bone_at(bank, int(joints.y), frame))) + (weights.z * ae3d_shaders_throng_bone_at(bank, int(joints.z), frame))) + (weights.w * ae3d_shaders_throng_bone_at(bank, int(joints.w), frame)));
}

void main() {
    mat4 model_matrix = (throng.model * instanceModel);
    if (shadow.reach.w > 0.0 && distance(model_matrix[3].xyz, shadow.reach.xyz) > shadow.reach.w) {
        gl_Position = vec4(vec3(2.0, 2.0, 2.0), 1.0);
        BindPos = inPosition;
        ClipLimb = 1.0;
        return;
    }
    float fpos = instancePhase * float(throng.frames);
    int frame0 = int(floor(fpos));
    float blend = fpos - float(frame0);
    if (frame0 < 0) {
        frame0 = 0;
        blend = 0.0;
    }
    if (frame0 >= throng.frames) {
        frame0 = throng.frames - 1;
        blend = 0.0;
    }
    int frame1 = frame0 + 1;
    if (frame1 >= throng.frames) {
        frame1 = 0;
    }
    mat4 skin = ((ae3d_shaders_throng_skin_at(pose_bank, inJoints, inWeights, frame0) * (1.0 - blend)) + (ae3d_shaders_throng_skin_at(pose_bank, inJoints, inWeights, frame1) * blend));
    vec4 posed = (skin * vec4(inPosition, 1.0));
    gl_Position = ((shadow.light_space * model_matrix) * posed);
    BindPos = inPosition;
    ClipLimb = 1.0;
}
