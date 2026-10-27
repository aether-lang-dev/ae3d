#version 450
// pick_vertex: written by ae3d.gpu from its quote.

struct Draw {
    mat4 model;
    mat4 prev_model;
    mat4 light_space;
    int instanced;
    int instance_colour;
    int points;
    int billboard;
    int flip_columns;
    int flip_rows;
    float lift;
    int skinned;
    int impostor;
    int pick;
};
struct Cut {
    int on;
    vec4 plane;
    int detached;
    float noise;
    float noise_scale;
    int joints0;
    int joints1;
    int joints2;
};
struct Skin {
    mat4 bones[96];
    vec4 prev_rows[288];
};
struct Eye {
    mat4 view_projection;
    mat4 prev_view_projection;
    mat4 inv_view_projection;
    vec3 position;
    float far;
    vec2 jitter;
    vec2 screen_size;
    int depth_on;
    vec4 depth_plane;
    int history;
    int capture;
    float ray_reach;
    int ray_frame;
};
layout(std140, set = 0, binding = 0) uniform DrawBlock {
    Draw draw;
    vec4 material_unread[8];
    vec4 shading_unread[8];
    Cut cut;
    vec4 wounds_unread[102];
    vec4 damage_unread[7];
    Skin skin;
};
layout(std140, set = 1, binding = 0) uniform CameraBlock {
    Eye eye;
};
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in mat4 instanceModel;
layout(location = 8) in vec4 inJoints;
layout(location = 9) in vec4 inWeights;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 Normal;
layout(location = 2) out vec3 FragPos;
layout(location = 3) out vec3 BindPos;
layout(location = 4) out float ClipLimb;
layout(location = 5) out float Instance;

float ae3d_shaders_lit_clip_joint_on(float joint) {
    int j = int((joint + 0.5));
    int word = j < 32 ? cut.joints0 : (j < 64 ? cut.joints1 : cut.joints2);
    return float((word >> (j & 31) & 1));
}

float ae3d_shaders_lit_clip_limb_of(vec4 joints, vec4 weights) {
    if (draw.skinned == 0 || (cut.joints0 | cut.joints1 | cut.joints2) == 0) {
        return 1.0;
    }
    return weights.x * ae3d_shaders_lit_clip_joint_on(joints.x) + weights.y * ae3d_shaders_lit_clip_joint_on(joints.y) + weights.z * ae3d_shaders_lit_clip_joint_on(joints.z) + weights.w * ae3d_shaders_lit_clip_joint_on(joints.w);
}

void main() {
    float clip_limb = ae3d_shaders_lit_clip_limb_of(inJoints, inWeights);
    mat4 model_matrix = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    vec4 posed0 = vec4(inPosition, 1.0);
    vec4 posed = posed0;
    vec3 posed_normal = inNormal;
    if (draw.skinned != 0) {
        mat4 skin_now = ((((inWeights.x * skin.bones[int(inJoints.x)]) + (inWeights.y * skin.bones[int(inJoints.y)])) + (inWeights.z * skin.bones[int(inJoints.z)])) + (inWeights.w * skin.bones[int(inJoints.w)]));
        posed = (skin_now * posed0);
        posed_normal = (mat3(skin_now) * inNormal);
    }
    vec3 frag_pos = (model_matrix * posed).xyz;
    vec3 normal_out = normalize((mat3(model_matrix) * posed_normal));
    vec4 clip_now = ((eye.view_projection * model_matrix) * posed);
    gl_Position = clip_now;
    fragTexCoord = inTexCoord;
    Normal = normal_out;
    FragPos = frag_pos;
    BindPos = inPosition;
    ClipLimb = clip_limb;
    Instance = float(int(gl_InstanceIndex));
}
