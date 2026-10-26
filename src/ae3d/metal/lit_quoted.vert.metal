// lit_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;
static inline float3x3 ae_mat3(float4x4 m) { return float3x3(m[0].xyz, m[1].xyz, m[2].xyz); }

struct Draw {
    float4x4 model;
    float4x4 prev_model;
    float4x4 light_space;
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
    char ae_pad0[8];
};
static_assert(sizeof(Draw) == 240, "Draw: std140");
static_assert(__builtin_offsetof(Draw, model) == 0, "Draw.model: std140");
static_assert(__builtin_offsetof(Draw, prev_model) == 64, "Draw.prev_model: std140");
static_assert(__builtin_offsetof(Draw, light_space) == 128, "Draw.light_space: std140");
static_assert(__builtin_offsetof(Draw, instanced) == 192, "Draw.instanced: std140");
static_assert(__builtin_offsetof(Draw, instance_colour) == 196, "Draw.instance_colour: std140");
static_assert(__builtin_offsetof(Draw, points) == 200, "Draw.points: std140");
static_assert(__builtin_offsetof(Draw, billboard) == 204, "Draw.billboard: std140");
static_assert(__builtin_offsetof(Draw, flip_columns) == 208, "Draw.flip_columns: std140");
static_assert(__builtin_offsetof(Draw, flip_rows) == 212, "Draw.flip_rows: std140");
static_assert(__builtin_offsetof(Draw, lift) == 216, "Draw.lift: std140");
static_assert(__builtin_offsetof(Draw, skinned) == 220, "Draw.skinned: std140");
static_assert(__builtin_offsetof(Draw, impostor) == 224, "Draw.impostor: std140");
static_assert(__builtin_offsetof(Draw, pick) == 228, "Draw.pick: std140");

struct Cut {
    int on;
    char ae_pad0[12];
    float4 plane;
    int detached;
    float noise;
    float noise_scale;
    int joints0;
    int joints1;
    int joints2;
    char ae_pad1[8];
};
static_assert(sizeof(Cut) == 64, "Cut: std140");
static_assert(__builtin_offsetof(Cut, on) == 0, "Cut.on: std140");
static_assert(__builtin_offsetof(Cut, plane) == 16, "Cut.plane: std140");
static_assert(__builtin_offsetof(Cut, detached) == 32, "Cut.detached: std140");
static_assert(__builtin_offsetof(Cut, noise) == 36, "Cut.noise: std140");
static_assert(__builtin_offsetof(Cut, noise_scale) == 40, "Cut.noise_scale: std140");
static_assert(__builtin_offsetof(Cut, joints0) == 44, "Cut.joints0: std140");
static_assert(__builtin_offsetof(Cut, joints1) == 48, "Cut.joints1: std140");
static_assert(__builtin_offsetof(Cut, joints2) == 52, "Cut.joints2: std140");

struct Eye {
    float4x4 view_projection;
    float4x4 prev_view_projection;
    float4x4 inv_view_projection;
    packed_float3 position;
    float far;
    float2 jitter;
    float2 screen_size;
    int depth_on;
    char ae_pad0[12];
    float4 depth_plane;
    int history;
    int capture;
    float ray_reach;
    int ray_frame;
};
static_assert(sizeof(Eye) == 272, "Eye: std140");
static_assert(__builtin_offsetof(Eye, view_projection) == 0, "Eye.view_projection: std140");
static_assert(__builtin_offsetof(Eye, prev_view_projection) == 64, "Eye.prev_view_projection: std140");
static_assert(__builtin_offsetof(Eye, inv_view_projection) == 128, "Eye.inv_view_projection: std140");
static_assert(__builtin_offsetof(Eye, position) == 192, "Eye.position: std140");
static_assert(__builtin_offsetof(Eye, far) == 204, "Eye.far: std140");
static_assert(__builtin_offsetof(Eye, jitter) == 208, "Eye.jitter: std140");
static_assert(__builtin_offsetof(Eye, screen_size) == 216, "Eye.screen_size: std140");
static_assert(__builtin_offsetof(Eye, depth_on) == 224, "Eye.depth_on: std140");
static_assert(__builtin_offsetof(Eye, depth_plane) == 240, "Eye.depth_plane: std140");
static_assert(__builtin_offsetof(Eye, history) == 256, "Eye.history: std140");
static_assert(__builtin_offsetof(Eye, capture) == 260, "Eye.capture: std140");
static_assert(__builtin_offsetof(Eye, ray_reach) == 264, "Eye.ray_reach: std140");
static_assert(__builtin_offsetof(Eye, ray_frame) == 268, "Eye.ray_frame: std140");

struct Skin {
    float4x4 bones[96];
    float4 prev_rows[288];
};
static_assert(sizeof(Skin) == 10752, "Skin: std140");
static_assert(__builtin_offsetof(Skin, bones) == 0, "Skin.bones: std140");
static_assert(__builtin_offsetof(Skin, prev_rows) == 6144, "Skin.prev_rows: std140");

struct DrawBlock {
    Draw draw;
    char ae_pad0[256];
    Cut cut;
    char ae_pad1[1744];
    Skin skin;
};
static_assert(sizeof(DrawBlock) == 13056, "DrawBlock: std140");
static_assert(__builtin_offsetof(DrawBlock, draw) == 0, "DrawBlock.draw: std140");
static_assert(__builtin_offsetof(DrawBlock, cut) == 496, "DrawBlock.cut: std140");
static_assert(__builtin_offsetof(DrawBlock, skin) == 2304, "DrawBlock.skin: std140");

struct CameraBlock {
    Eye eye;
};
static_assert(sizeof(CameraBlock) == 272, "CameraBlock: std140");
static_assert(__builtin_offsetof(CameraBlock, eye) == 0, "CameraBlock.eye: std140");

struct ae_lit_vertex_in {
    float3 inPosition [[attribute(0)]];
    float2 inTexCoord [[attribute(1)]];
    float3 inNormal [[attribute(2)]];
    float4 instanceModel_0 [[attribute(3)]];
    float4 instanceModel_1 [[attribute(4)]];
    float4 instanceModel_2 [[attribute(5)]];
    float4 instanceModel_3 [[attribute(6)]];
    float3 instanceColor [[attribute(7)]];
    float4 inJoints [[attribute(8)]];
    float4 inWeights [[attribute(9)]];
    float inOcclusion [[attribute(10)]];
    float2 inMaskUV [[attribute(12)]];
    float4 instanceExtras [[attribute(13)]];
};

struct ae_lit_vertex_out {
    float4 ae_position [[position]];
    float2 fragTexCoord [[user(locn0)]];
    float3 Normal [[user(locn1)]];
    float3 FragPos [[user(locn2)]];
    float3 InstanceColor [[user(locn3)]];
    float4 FragPosLightSpace [[user(locn4)]];
    float Occlusion [[user(locn5)]];
    float4 ClipNow [[user(locn6)]];
    float4 ClipPrev [[user(locn7)]];
    float3 BindPos [[user(locn8)]];
    float ClipLimb [[user(locn9)]];
    float2 MaskUV [[user(locn10)]];
    float ParticleAlpha [[user(locn11)]];
    float3 FlipNext [[user(locn12)]];
};

static float ae3d_shaders_lit_clip_joint_on(float joint, constant Cut& cut) {
    int j = int((joint + 0.5));
    int word = j < 32 ? cut.joints0 : (j < 64 ? cut.joints1 : cut.joints2);
    return float((word >> (j & 31) & 1));
}

static float ae3d_shaders_lit_clip_limb_of(float4 joints, float4 weights, constant Draw& draw, constant Cut& cut) {
    if (draw.skinned == 0 || (cut.joints0 | cut.joints1 | cut.joints2) == 0) {
        return 1.0;
    }
    return weights.x * ae3d_shaders_lit_clip_joint_on(joints.x, cut) + weights.y * ae3d_shaders_lit_clip_joint_on(joints.y, cut) + weights.z * ae3d_shaders_lit_clip_joint_on(joints.z, cut) + weights.w * ae3d_shaders_lit_clip_joint_on(joints.w, cut);
}

static float4x4 ae3d_shaders_lit_prev_bone(float joint, constant Skin& skin) {
    int j = int((joint + 0.5)) * 3;
    return transpose(float4x4(skin.prev_rows[j], skin.prev_rows[j + 1], skin.prev_rows[j + 2], float4(float3(0.0, 0.0, 0.0), 1.0)));
}

vertex ae_lit_vertex_out ae_lit_vertex_vertex(
    ae_lit_vertex_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]],
    constant CameraBlock& ae_set1 [[buffer(1)]]) {
    ae_lit_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float2 inTexCoord = ae_in.inTexCoord;
    float3 inNormal = ae_in.inNormal;
    float4x4 instanceModel = float4x4(ae_in.instanceModel_0, ae_in.instanceModel_1, ae_in.instanceModel_2, ae_in.instanceModel_3);
    float3 instanceColor = ae_in.instanceColor;
    float4 inJoints = ae_in.inJoints;
    float4 inWeights = ae_in.inWeights;
    float inOcclusion = ae_in.inOcclusion;
    float2 inMaskUV = ae_in.inMaskUV;
    float4 instanceExtras = ae_in.instanceExtras;
    constant Draw& draw = ae_set0.draw;
    constant Cut& cut = ae_set0.cut;
    constant Skin& skin = ae_set0.skin;
    constant Eye& eye = ae_set1.eye;
    float clip_limb = ae3d_shaders_lit_clip_limb_of(inJoints, inWeights, draw, cut);
    float2 mask_uv = inMaskUV.x < -0.5 ? inTexCoord : inMaskUV;
    float4x4 model_matrix0 = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    float4x4 model_matrix = model_matrix0;
    float particle_alpha = 1.0;
    float3 flip_next = float3(0.0, 0.0, -1.0);
    float2 tex_coord = inTexCoord;
    if (draw.instanced != 0 && draw.points != 0) {
        float4 point = instanceModel[0];
        particle_alpha = instanceExtras.x;
        if (draw.flip_columns > 0 && draw.flip_rows > 0) {
            int frames = draw.flip_columns * draw.flip_rows;
            float at = clamp(instanceExtras.y, 0.0, 1.0) * float((frames - 1));
            int frame = min(int(at), frames - 1);
            int next = min(frame + 1, frames - 1);
            float column = float((frame - frame / draw.flip_columns * draw.flip_columns));
            float row = float((frame / draw.flip_columns));
            tex_coord = float2((column + inTexCoord.x) / float(draw.flip_columns), 1.0 - (row + 1.0 - inTexCoord.y) / float(draw.flip_rows));
            float next_column = float((next - next / draw.flip_columns * draw.flip_columns));
            float next_row = float((next / draw.flip_columns));
            flip_next = float3((next_column + inTexCoord.x) / float(draw.flip_columns), 1.0 - (next_row + 1.0 - inTexCoord.y) / float(draw.flip_rows), at - float(frame));
        }
        model_matrix = float4x4(draw.model[0] * point.w, draw.model[1] * point.w, draw.model[2] * point.w, float4(point.xyz, 1.0));
        if (draw.billboard > 0) {
            float3 to_eye = eye.position - point.xyz;
            float3 up0 = float3(0.0, 1.0, 0.0);
            float3 forward = float3(0.0);
            if (draw.billboard == 1) {
                forward = normalize(float3(to_eye.x, 0.0, to_eye.z));
            } else {
                forward = normalize(to_eye);
            }
            float3 right0 = normalize(cross(up0, forward));
            float3 up1 = cross(forward, right0);
            float cn = cos(instanceExtras.z);
            float sn = sin(instanceExtras.z);
            float3 turned = right0 * cn + up1 * sn;
            float3 up = up1 * cn - right0 * sn;
            float3 right = turned * max(instanceExtras.w, 1.0);
            float sx = length(draw.model[0].xyz) * point.w;
            float sy = length(draw.model[1].xyz) * point.w;
            float sz = length(draw.model[2].xyz) * point.w;
            model_matrix = float4x4(float4(right * sx, 0.0), float4(up * sy, 0.0), float4(forward * sz, 0.0), float4(point.xyz + up * (sy * draw.lift), 1.0));
        }
    }
    float4 posed0 = float4(inPosition, 1.0);
    float4 posed = posed0;
    float4 posed_prev = posed0;
    float3 posed_normal = inNormal;
    if (draw.skinned != 0) {
        float4x4 skin_now = ((((inWeights.x * skin.bones[int(inJoints.x)]) + (inWeights.y * skin.bones[int(inJoints.y)])) + (inWeights.z * skin.bones[int(inJoints.z)])) + (inWeights.w * skin.bones[int(inJoints.w)]));
        float4x4 skin_prev = ((((inWeights.x * ae3d_shaders_lit_prev_bone(inJoints.x, skin)) + (inWeights.y * ae3d_shaders_lit_prev_bone(inJoints.y, skin))) + (inWeights.z * ae3d_shaders_lit_prev_bone(inJoints.z, skin))) + (inWeights.w * ae3d_shaders_lit_prev_bone(inJoints.w, skin)));
        posed_prev = (skin_prev * posed0);
        posed = (skin_now * posed0);
        posed_normal = (ae_mat3(skin_now) * inNormal);
    }
    float4x4 prev_model_matrix0 = draw.instanced != 0 ? (draw.prev_model * instanceModel) : draw.prev_model;
    float4x4 prev_model_matrix = prev_model_matrix0;
    if (draw.instanced != 0 && draw.points != 0) {
        prev_model_matrix = model_matrix;
    }
    float3 frag_pos = (model_matrix * posed).xyz;
    float3 normal_out = normalize((ae_mat3(model_matrix) * posed_normal));
    float3 instance_colour = draw.instanced != 0 && draw.instance_colour != 0 ? instanceColor : float3(1.0, 1.0, 1.0);
    float4 light_space = (draw.light_space * float4(frag_pos, 1.0));
    float4 clip_now = ((eye.view_projection * model_matrix) * posed);
    float4 clip_prev = ((eye.prev_view_projection * prev_model_matrix) * posed_prev);
    ae_out.ae_position = clip_now;
    ae_out.fragTexCoord = tex_coord;
    ae_out.Normal = normal_out;
    ae_out.FragPos = frag_pos;
    ae_out.InstanceColor = instance_colour;
    ae_out.FragPosLightSpace = light_space;
    ae_out.Occlusion = inOcclusion;
    ae_out.ClipNow = clip_now;
    ae_out.ClipPrev = clip_prev;
    ae_out.BindPos = inPosition;
    ae_out.ClipLimb = clip_limb;
    ae_out.MaskUV = mask_uv;
    ae_out.ParticleAlpha = particle_alpha;
    ae_out.FlipNext = flip_next;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
