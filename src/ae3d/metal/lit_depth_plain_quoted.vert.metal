// lit_depth_plain_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

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
    char ae_pad0[12];
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

struct ae_lit_depth_plain_vertex_in {
    float3 inPosition [[attribute(0)]];
    float4 instanceModel_0 [[attribute(3)]];
    float4 instanceModel_1 [[attribute(4)]];
    float4 instanceModel_2 [[attribute(5)]];
    float4 instanceModel_3 [[attribute(6)]];
};

struct ae_lit_depth_plain_vertex_out {
    float4 ae_position [[position]];
    float3 BindPos [[user(locn0)]];
    float ClipLimb [[user(locn1)]];
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

vertex ae_lit_depth_plain_vertex_out ae_lit_depth_plain_vertex_vertex(
    ae_lit_depth_plain_vertex_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]],
    constant CameraBlock& ae_set1 [[buffer(1)]]) {
    ae_lit_depth_plain_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float4x4 instanceModel = float4x4(ae_in.instanceModel_0, ae_in.instanceModel_1, ae_in.instanceModel_2, ae_in.instanceModel_3);
    constant Draw& draw = ae_set0.draw;
    constant Cut& cut = ae_set0.cut;
    constant Skin& skin = ae_set0.skin;
    constant Eye& eye = ae_set1.eye;
    float clip_limb = ae3d_shaders_lit_clip_limb_of(float4(0.0), float4(0.0), draw, cut);
    float4x4 model_matrix0 = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    float4x4 model_matrix = model_matrix0;
    if (draw.instanced != 0 && draw.points != 0) {
        float4 point = instanceModel[0];
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
            float3 right = normalize(cross(up0, forward));
            float3 up = cross(forward, right);
            float sx = length(draw.model[0].xyz) * point.w;
            float sy = length(draw.model[1].xyz) * point.w;
            float sz = length(draw.model[2].xyz) * point.w;
            model_matrix = float4x4(float4(right * sx, 0.0), float4(up * sy, 0.0), float4(forward * sz, 0.0), float4(point.xyz + up * (sy * draw.lift), 1.0));
        }
    }
    float4 posed0 = float4(inPosition, 1.0);
    float4 posed = posed0;
    if (draw.skinned != 0) {
        float4 weights = float4(0.0);
        float4 joints = float4(0.0);
        float4x4 skin_now = ((((weights.x * skin.bones[int(joints.x)]) + (weights.y * skin.bones[int(joints.y)])) + (weights.z * skin.bones[int(joints.z)])) + (weights.w * skin.bones[int(joints.w)]));
        posed = (skin_now * posed0);
    }
    ae_out.ae_position = ((draw.light_space * model_matrix) * posed);
    ae_out.BindPos = inPosition;
    ae_out.ClipLimb = clip_limb;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
