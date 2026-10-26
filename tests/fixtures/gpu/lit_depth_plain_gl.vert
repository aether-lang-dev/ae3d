#version 410 core
// lit_depth_plain_vertex: written by ae3d.gpu from its quote.

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
    mat4 bones[96];
    vec4 prev_rows[288];
};
uniform Draw draw;
uniform Cut cut;
uniform Skin skin;
uniform Eye eye;
layout(location = 0) in vec3 inPosition;
layout(location = 3) in mat4 instanceModel;

out vec3 BindPos;
out float ClipLimb;

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
    float clip_limb = ae3d_shaders_lit_clip_limb_of(vec4(0.0), vec4(0.0));
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
        vec4 weights = vec4(0.0);
        vec4 joints = vec4(0.0);
        mat4 skin_now = ((((weights.x * skin.bones[int(joints.x)]) + (weights.y * skin.bones[int(joints.y)])) + (weights.z * skin.bones[int(joints.z)])) + (weights.w * skin.bones[int(joints.w)]));
        posed = (skin_now * posed0);
    }
    gl_Position = ((draw.light_space * model_matrix) * posed);
    BindPos = inPosition;
    ClipLimb = clip_limb;
}
