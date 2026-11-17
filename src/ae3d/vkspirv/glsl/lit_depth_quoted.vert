#version 450
// lit_depth_vertex: written by ae3d.gpu from its quote.

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
struct Skin {
    int base;
    int prev_base;
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
layout(std430, set = 0, binding = 10) readonly buffer skin_rows_buffer { vec4 skin_rows[]; };
layout(location = 0) in vec3 inPosition;
layout(location = 3) in mat4 instanceModel;
layout(location = 8) in vec4 inJoints;
layout(location = 9) in vec4 inWeights;

layout(location = 0) out vec3 BindPos;
layout(location = 1) out float ClipLimb;

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
    return mat4(skin_rows[j], skin_rows[(j + 1)], skin_rows[(j + 2)], skin_rows[(j + 3)]);
}

mat4 ae3d_shaders_lit_skin_now_of() {
    return ((((inWeights.x * ae3d_shaders_lit_skin_bone(inJoints.x)) + (inWeights.y * ae3d_shaders_lit_skin_bone(inJoints.y))) + (inWeights.z * ae3d_shaders_lit_skin_bone(inJoints.z))) + (inWeights.w * ae3d_shaders_lit_skin_bone(inJoints.w)));
}

void main() {
    float clip_limb = ae3d_shaders_lit_clip_limb_of(inJoints, inWeights);
    mat4 model_matrix0 = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    mat4 model_matrix = model_matrix0;
    if (draw.instanced != 0 && draw.points != 0) {
        vec4 point = instanceModel[0];
        model_matrix = mat4(draw.model[0] * point.w, draw.model[1] * point.w, draw.model[2] * point.w, vec4(point.xyz, 1.0));
        if (draw.billboard > 0) {
            vec3 to_eye = eye.position - point.xyz;
            vec3 up0 = vec3(0.0, 1.0, 0.0);
            vec3 forward = vec3(0.0);
            if (draw.billboard == 1) {
                forward = normalize(vec3(to_eye.x, 0.0, to_eye.z));
            } else {
                forward = normalize(to_eye);
            }
            vec3 right = normalize(cross(up0, forward));
            vec3 up = cross(forward, right);
            float sx = length(draw.model[0].xyz) * point.w;
            float sy = length(draw.model[1].xyz) * point.w;
            float sz = length(draw.model[2].xyz) * point.w;
            model_matrix = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(forward * sz, 0.0), vec4(point.xyz + up * (sy * draw.lift), 1.0));
        }
    }
    vec4 posed0 = vec4(inPosition, 1.0);
    vec4 posed = posed0;
    if (draw.skinned != 0) {
        mat4 skin_now = ae3d_shaders_lit_skin_now_of();
        posed = (skin_now * posed0);
    }
    gl_Position = ((draw.light_space * model_matrix) * posed);
    BindPos = inPosition;
    ClipLimb = clip_limb;
}
