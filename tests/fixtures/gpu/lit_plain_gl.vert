#version 410 core
// lit_plain_vertex: written by ae3d.gpu from its quote.

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
layout(location = 1) in vec2 inTexCoord;
layout(location = 2) in vec3 inNormal;
layout(location = 3) in mat4 instanceModel;
layout(location = 7) in vec3 instanceColor;
layout(location = 10) in float inOcclusion;
layout(location = 13) in vec4 instanceExtras;

out vec2 fragTexCoord;
out vec3 Normal;
out vec3 FragPos;
out vec3 InstanceColor;
out vec4 FragPosLightSpace;
out float Occlusion;
out vec4 ClipNow;
out vec4 ClipPrev;
out vec3 BindPos;
out float ClipLimb;
out vec2 MaskUV;
out float ParticleAlpha;
out vec3 FlipNext;

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

mat4 ae3d_shaders_lit_prev_bone(float joint) {
    int j = int((joint + 0.5)) * 3;
    return transpose(mat4(skin.prev_rows[j], skin.prev_rows[j + 1], skin.prev_rows[j + 2], vec4(vec3(0.0, 0.0, 0.0), 1.0)));
}

void main() {
    float clip_limb = ae3d_shaders_lit_clip_limb_of(vec4(0.0), vec4(0.0));
    vec2 mask_uv = vec2(-1.0).x < -0.5 ? inTexCoord : vec2(-1.0);
    mat4 model_matrix0 = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    mat4 model_matrix = model_matrix0;
    float particle_alpha = 1.0;
    vec3 flip_next = vec3(0.0, 0.0, -1.0);
    vec2 tex_coord = inTexCoord;
    if (draw.instanced != 0 && draw.points != 0) {
        vec4 point = instanceModel[0];
        particle_alpha = instanceExtras.x;
        if (draw.flip_columns > 0 && draw.flip_rows > 0) {
            int frames = draw.flip_columns * draw.flip_rows;
            float at = clamp(instanceExtras.y, 0.0, 1.0) * float((frames - 1));
            int frame = min(int(at), frames - 1);
            int next = min(frame + 1, frames - 1);
            float column = float((frame - frame / draw.flip_columns * draw.flip_columns));
            float row = float((frame / draw.flip_columns));
            tex_coord = vec2((column + inTexCoord.x) / float(draw.flip_columns), 1.0 - (row + 1.0 - inTexCoord.y) / float(draw.flip_rows));
            float next_column = float((next - next / draw.flip_columns * draw.flip_columns));
            float next_row = float((next / draw.flip_columns));
            flip_next = vec3((next_column + inTexCoord.x) / float(draw.flip_columns), 1.0 - (next_row + 1.0 - inTexCoord.y) / float(draw.flip_rows), at - float(frame));
        }
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
            vec3 right0 = normalize(cross(up0, forward));
            vec3 up1 = cross(forward, right0);
            float cn = cos(instanceExtras.z);
            float sn = sin(instanceExtras.z);
            vec3 turned = right0 * cn + up1 * sn;
            vec3 up = up1 * cn - right0 * sn;
            vec3 right = turned * max(instanceExtras.w, 1.0);
            float sx = length(draw.model[0].xyz) * point.w;
            float sy = length(draw.model[1].xyz) * point.w;
            float sz = length(draw.model[2].xyz) * point.w;
            model_matrix = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(forward * sz, 0.0), vec4(point.xyz + up * (sy * draw.lift), 1.0));
        }
    }
    vec4 posed0 = vec4(inPosition, 1.0);
    vec4 posed = posed0;
    vec4 posed_prev = posed0;
    vec3 posed_normal = inNormal;
    if (draw.skinned != 0) {
        vec4 weights = vec4(0.0);
        vec4 joints = vec4(0.0);
        mat4 skin_now = ((((weights.x * skin.bones[int(joints.x)]) + (weights.y * skin.bones[int(joints.y)])) + (weights.z * skin.bones[int(joints.z)])) + (weights.w * skin.bones[int(joints.w)]));
        mat4 skin_prev = ((((weights.x * ae3d_shaders_lit_prev_bone(joints.x)) + (weights.y * ae3d_shaders_lit_prev_bone(joints.y))) + (weights.z * ae3d_shaders_lit_prev_bone(joints.z))) + (weights.w * ae3d_shaders_lit_prev_bone(joints.w)));
        posed_prev = (skin_prev * posed0);
        posed = (skin_now * posed0);
        posed_normal = (mat3(skin_now) * inNormal);
    }
    mat4 prev_model_matrix0 = draw.instanced != 0 ? (draw.prev_model * instanceModel) : draw.prev_model;
    mat4 prev_model_matrix = prev_model_matrix0;
    if (draw.instanced != 0 && draw.points != 0) {
        prev_model_matrix = model_matrix;
    }
    vec3 frag_pos = (model_matrix * posed).xyz;
    vec3 normal_out = normalize((mat3(model_matrix) * posed_normal));
    vec3 instance_colour = draw.instanced != 0 && draw.instance_colour != 0 ? instanceColor : vec3(1.0, 1.0, 1.0);
    vec4 light_space = (draw.light_space * vec4(frag_pos, 1.0));
    vec4 clip_now = ((eye.view_projection * model_matrix) * posed);
    vec4 clip_prev = ((eye.prev_view_projection * prev_model_matrix) * posed_prev);
    gl_Position = clip_now;
    fragTexCoord = tex_coord;
    Normal = normal_out;
    FragPos = frag_pos;
    InstanceColor = instance_colour;
    FragPosLightSpace = light_space;
    Occlusion = inOcclusion;
    ClipNow = clip_now;
    ClipPrev = clip_prev;
    BindPos = inPosition;
    ClipLimb = clip_limb;
    MaskUV = mask_uv;
    ParticleAlpha = particle_alpha;
    FlipNext = flip_next;
}
