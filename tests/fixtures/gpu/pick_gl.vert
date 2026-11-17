#version 410 core
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
    int joints3;
    int joints4;
    int joints5;
    int joints6;
    int joints7;
};
struct Skin {
    int base;
    int prev_base;
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
uniform Draw draw;
uniform Cut cut;
uniform Skin skin;
uniform Eye eye;
uniform sampler2D skin_rows;
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in mat4 instanceModel;
layout(location = 8) in vec4 inJoints;
layout(location = 9) in vec4 inWeights;

out vec2 fragTexCoord;
out vec3 Normal;
out vec3 FragPos;
out vec3 BindPos;
out float ClipLimb;
out float Instance;

float ae3d_shaders_lit_clip_joint_on(float joint) {
    int j = int((joint + 0.5));
    int w = j >> 5;
    int word = w < 4 ? (w < 2 ? (w == 0 ? cut.joints0 : cut.joints1) : (w == 2 ? cut.joints2 : cut.joints3)) : (w < 6 ? (w == 4 ? cut.joints4 : cut.joints5) : (w == 6 ? cut.joints6 : cut.joints7));
    return float((word >> (j & 31) & 1));
}

float ae3d_shaders_lit_clip_limb_of(vec4 joints, vec4 weights) {
    if (draw.skinned == 0 || (cut.joints0 | cut.joints1 | cut.joints2 | cut.joints3 | cut.joints4 | cut.joints5 | cut.joints6 | cut.joints7) == 0) {
        return 1.0;
    }
    return weights.x * ae3d_shaders_lit_clip_joint_on(joints.x) + weights.y * ae3d_shaders_lit_clip_joint_on(joints.y) + weights.z * ae3d_shaders_lit_clip_joint_on(joints.z) + weights.w * ae3d_shaders_lit_clip_joint_on(joints.w);
}

mat4 ae3d_shaders_lit_skin_bone(float joint) {
    int j = skin.base + int((joint + 0.5)) * 4;
    return mat4(texelFetch(skin_rows, ivec2(j % 1024, j / 1024), 0), texelFetch(skin_rows, ivec2((j + 1) % 1024, (j + 1) / 1024), 0), texelFetch(skin_rows, ivec2((j + 2) % 1024, (j + 2) / 1024), 0), texelFetch(skin_rows, ivec2((j + 3) % 1024, (j + 3) / 1024), 0));
}

mat4 ae3d_shaders_lit_skin_now_of() {
    return ((((inWeights.x * ae3d_shaders_lit_skin_bone(inJoints.x)) + (inWeights.y * ae3d_shaders_lit_skin_bone(inJoints.y))) + (inWeights.z * ae3d_shaders_lit_skin_bone(inJoints.z))) + (inWeights.w * ae3d_shaders_lit_skin_bone(inJoints.w)));
}

void main() {
    float clip_limb = ae3d_shaders_lit_clip_limb_of(inJoints, inWeights);
    mat4 model_matrix = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    vec4 posed0 = vec4(inPosition, 1.0);
    vec4 posed = posed0;
    vec3 posed_normal = inNormal;
    if (draw.skinned != 0) {
        mat4 skin_now = ae3d_shaders_lit_skin_now_of();
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
    Instance = float(int(gl_InstanceID));
}
