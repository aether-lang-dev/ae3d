#version 410 core
// crowd_pick_vertex: written by ae3d.gpu from its quote.

struct Throng {
    mat4 model;
    int frames;
    int impostor;
    int columns;
    int rows;
    float width;
    float height;
};
struct Eye {
    mat4 view_projection;
    vec3 position;
};
uniform Throng throng;
uniform Eye viewer;
uniform sampler2D pose_bank;
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 3) in mat4 instanceModel;
layout(location = 8) in vec4 inJoints;
layout(location = 9) in vec4 inWeights;
layout(location = 11) in float instancePhase;

out vec2 fragTexCoord;
out vec3 Normal;
out vec3 FragPos;
out vec3 BindPos;
out float ClipLimb;
out float Instance;

mat4 ae3d_shaders_throng_bone_at(sampler2D bank, int bone, int frame) {
    int x = bone * 4;
    return mat4(texelFetch(bank, ivec2((x + 0), frame), 0), texelFetch(bank, ivec2((x + 1), frame), 0), texelFetch(bank, ivec2((x + 2), frame), 0), texelFetch(bank, ivec2((x + 3), frame), 0));
}

mat4 ae3d_shaders_throng_skin_at(sampler2D bank, vec4 joints, vec4 weights, int frame) {
    return ((((weights.x * ae3d_shaders_throng_bone_at(bank, int(joints.x), frame)) + (weights.y * ae3d_shaders_throng_bone_at(bank, int(joints.y), frame))) + (weights.z * ae3d_shaders_throng_bone_at(bank, int(joints.z), frame))) + (weights.w * ae3d_shaders_throng_bone_at(bank, int(joints.w), frame)));
}

mat4 ae3d_shaders_throng_skin_at_phase(sampler2D bank, vec4 joints, vec4 weights, float phase, int frames) {
    float fpos = fract(phase) * float(frames);
    int frame0 = int(floor(fpos));
    float blend = fpos - float(frame0);
    if (frame0 < 0) {
        frame0 = 0;
        blend = 0.0;
    }
    if (frame0 >= frames) {
        frame0 = frames - 1;
        blend = 0.0;
    }
    int frame1 = frame0 + 1;
    if (frame1 >= frames) {
        frame1 = 0;
    }
    return ((ae3d_shaders_throng_skin_at(bank, joints, weights, frame0) * (1.0 - blend)) + (ae3d_shaders_throng_skin_at(bank, joints, weights, frame1) * blend));
}

void main() {
    mat4 model_matrix = (throng.model * instanceModel);
    if (throng.impostor != 0) {
        vec3 origin = model_matrix[3].xyz;
        vec3 facing = normalize(vec3(model_matrix[0][0], 0.0, model_matrix[0][2]));
        vec3 to_eye = viewer.position - origin;
        vec3 level = normalize(vec3(to_eye.x, 0.0, to_eye.z));
        float angle = atan(dot(level, vec3(-facing.z, 0.0, facing.x)), dot(level, facing));
        float turn = fract(angle / 6.28318530718 + 1.0);
        int column = int(floor(turn * float(throng.columns) + 0.5)) % throng.columns;
        int row = int(floor(fract(instancePhase) * float(throng.rows))) % throng.rows;
        vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), level));
        vec3 world = origin + right * (inPosition.x * throng.width) + vec3(0.0, inPosition.y * throng.height, 0.0);
        vec2 cell = vec2((float(column) + inTexCoord.x) / float(throng.columns), 1.0 - (float(row) + (1.0 - inTexCoord.y)) / float(throng.rows));
        gl_Position = (viewer.view_projection * vec4(world, 1.0));
        fragTexCoord = cell;
        Normal = facing;
        FragPos = world;
        BindPos = inPosition;
        ClipLimb = 1.0;
        Instance = float(int(gl_InstanceID));
        return;
    }
    mat4 skin = ae3d_shaders_throng_skin_at_phase(pose_bank, inJoints, inWeights, instancePhase, throng.frames);
    vec4 posed = (skin * vec4(inPosition, 1.0));
    vec3 frag_pos = (model_matrix * posed).xyz;
    gl_Position = ((viewer.view_projection * model_matrix) * posed);
    fragTexCoord = inTexCoord;
    Normal = vec3(0.0, 1.0, 0.0);
    FragPos = frag_pos;
    BindPos = inPosition;
    ClipLimb = 1.0;
    Instance = float(int(gl_InstanceID));
}
