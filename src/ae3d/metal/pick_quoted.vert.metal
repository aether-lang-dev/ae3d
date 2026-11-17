// pick_vertex: written by ae3d.gpu from its quote.
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
    int joints3;
    int joints4;
    int joints5;
    int joints6;
    int joints7;
    char ae_pad1[4];
};
static_assert(sizeof(Cut) == 80, "Cut: std140");
static_assert(__builtin_offsetof(Cut, on) == 0, "Cut.on: std140");
static_assert(__builtin_offsetof(Cut, plane) == 16, "Cut.plane: std140");
static_assert(__builtin_offsetof(Cut, detached) == 32, "Cut.detached: std140");
static_assert(__builtin_offsetof(Cut, noise) == 36, "Cut.noise: std140");
static_assert(__builtin_offsetof(Cut, noise_scale) == 40, "Cut.noise_scale: std140");
static_assert(__builtin_offsetof(Cut, joints0) == 44, "Cut.joints0: std140");
static_assert(__builtin_offsetof(Cut, joints1) == 48, "Cut.joints1: std140");
static_assert(__builtin_offsetof(Cut, joints2) == 52, "Cut.joints2: std140");
static_assert(__builtin_offsetof(Cut, joints3) == 56, "Cut.joints3: std140");
static_assert(__builtin_offsetof(Cut, joints4) == 60, "Cut.joints4: std140");
static_assert(__builtin_offsetof(Cut, joints5) == 64, "Cut.joints5: std140");
static_assert(__builtin_offsetof(Cut, joints6) == 68, "Cut.joints6: std140");
static_assert(__builtin_offsetof(Cut, joints7) == 72, "Cut.joints7: std140");

struct Skin {
    int base;
    int prev_base;
    char ae_pad0[8];
};
static_assert(sizeof(Skin) == 16, "Skin: std140");
static_assert(__builtin_offsetof(Skin, base) == 0, "Skin.base: std140");
static_assert(__builtin_offsetof(Skin, prev_base) == 4, "Skin.prev_base: std140");

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

struct DrawBlock {
    Draw draw;
    char ae_pad0[256];
    Cut cut;
    char ae_pad1[1744];
    Skin skin;
};
static_assert(sizeof(DrawBlock) == 2336, "DrawBlock: std140");
static_assert(__builtin_offsetof(DrawBlock, draw) == 0, "DrawBlock.draw: std140");
static_assert(__builtin_offsetof(DrawBlock, cut) == 496, "DrawBlock.cut: std140");
static_assert(__builtin_offsetof(DrawBlock, skin) == 2320, "DrawBlock.skin: std140");

struct CameraBlock {
    Eye eye;
};
static_assert(sizeof(CameraBlock) == 272, "CameraBlock: std140");
static_assert(__builtin_offsetof(CameraBlock, eye) == 0, "CameraBlock.eye: std140");

struct ae_pick_vertex_in {
    float3 inPosition [[attribute(0)]];
    float2 inTexCoord [[attribute(1)]];
    float3 inNormal [[attribute(2)]];
    float4 instanceModel_0 [[attribute(3)]];
    float4 instanceModel_1 [[attribute(4)]];
    float4 instanceModel_2 [[attribute(5)]];
    float4 instanceModel_3 [[attribute(6)]];
    float4 inJoints [[attribute(8)]];
    float4 inWeights [[attribute(9)]];
};

struct ae_pick_vertex_out {
    float4 ae_position [[position]];
    float2 fragTexCoord [[user(locn0)]];
    float3 Normal [[user(locn1)]];
    float3 FragPos [[user(locn2)]];
    float3 BindPos [[user(locn3)]];
    float ClipLimb [[user(locn4)]];
    float Instance [[user(locn5)]];
};

static float ae3d_shaders_lit_clip_joint_on(float joint, constant Cut& cut) {
    int j = int((joint + 0.5));
    int w = j >> 5;
    int word = w < 4 ? (w < 2 ? (w == 0 ? cut.joints0 : cut.joints1) : (w == 2 ? cut.joints2 : cut.joints3)) : (w < 6 ? (w == 4 ? cut.joints4 : cut.joints5) : (w == 6 ? cut.joints6 : cut.joints7));
    return float((word >> (j & 31) & 1));
}

static float ae3d_shaders_lit_clip_limb_of(float4 joints, float4 weights, constant Draw& draw, constant Cut& cut) {
    if (draw.skinned == 0 || (cut.joints0 | cut.joints1 | cut.joints2 | cut.joints3 | cut.joints4 | cut.joints5 | cut.joints6 | cut.joints7) == 0) {
        return 1.0;
    }
    return weights.x * ae3d_shaders_lit_clip_joint_on(joints.x, cut) + weights.y * ae3d_shaders_lit_clip_joint_on(joints.y, cut) + weights.z * ae3d_shaders_lit_clip_joint_on(joints.z, cut) + weights.w * ae3d_shaders_lit_clip_joint_on(joints.w, cut);
}

static float4x4 ae3d_shaders_lit_skin_bone(float joint, const device float4* skin_rows, constant Skin& skin) {
    int j = skin.base + int((joint + 0.5)) * 4;
    return float4x4(skin_rows[j], skin_rows[(j + 1)], skin_rows[(j + 2)], skin_rows[(j + 3)]);
}

static float4x4 ae3d_shaders_lit_skin_now_of(float4 inJoints, float4 inWeights, const device float4* skin_rows, constant Skin& skin) {
    return ((((inWeights.x * ae3d_shaders_lit_skin_bone(inJoints.x, skin_rows, skin)) + (inWeights.y * ae3d_shaders_lit_skin_bone(inJoints.y, skin_rows, skin))) + (inWeights.z * ae3d_shaders_lit_skin_bone(inJoints.z, skin_rows, skin))) + (inWeights.w * ae3d_shaders_lit_skin_bone(inJoints.w, skin_rows, skin)));
}

vertex ae_pick_vertex_out ae_pick_vertex_vertex(
    ae_pick_vertex_in ae_in [[stage_in]],
    constant DrawBlock& ae_set0 [[buffer(0)]],
    constant CameraBlock& ae_set1 [[buffer(1)]],
    const device float4* skin_rows [[buffer(8)]],
    uint ae_instance_id [[instance_id]]) {
    ae_pick_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float2 inTexCoord = ae_in.inTexCoord;
    float3 inNormal = ae_in.inNormal;
    float4x4 instanceModel = float4x4(ae_in.instanceModel_0, ae_in.instanceModel_1, ae_in.instanceModel_2, ae_in.instanceModel_3);
    float4 inJoints = ae_in.inJoints;
    float4 inWeights = ae_in.inWeights;
    constant Draw& draw = ae_set0.draw;
    constant Cut& cut = ae_set0.cut;
    constant Skin& skin = ae_set0.skin;
    constant Eye& eye = ae_set1.eye;
    float clip_limb = ae3d_shaders_lit_clip_limb_of(inJoints, inWeights, draw, cut);
    float4x4 model_matrix = draw.instanced != 0 ? (draw.model * instanceModel) : draw.model;
    float4 posed0 = float4(inPosition, 1.0);
    float4 posed = posed0;
    float3 posed_normal = inNormal;
    if (draw.skinned != 0) {
        float4x4 skin_now = ae3d_shaders_lit_skin_now_of(inJoints, inWeights, skin_rows, skin);
        posed = (skin_now * posed0);
        posed_normal = (ae_mat3(skin_now) * inNormal);
    }
    float3 frag_pos = (model_matrix * posed).xyz;
    float3 normal_out = normalize((ae_mat3(model_matrix) * posed_normal));
    float4 clip_now = ((eye.view_projection * model_matrix) * posed);
    ae_out.ae_position = clip_now;
    ae_out.fragTexCoord = inTexCoord;
    ae_out.Normal = normal_out;
    ae_out.FragPos = frag_pos;
    ae_out.BindPos = inPosition;
    ae_out.ClipLimb = clip_limb;
    ae_out.Instance = float(int(ae_instance_id));
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
