// crowd_depth_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct Throng {
    float4x4 model;
    int frames;
    char ae_pad0[12];
};
static_assert(sizeof(Throng) == 80, "Throng: std140");
static_assert(__builtin_offsetof(Throng, model) == 0, "Throng.model: std140");
static_assert(__builtin_offsetof(Throng, frames) == 64, "Throng.frames: std140");

struct Shadow {
    float4x4 light_space;
    float4 reach;
};
static_assert(sizeof(Shadow) == 80, "Shadow: std140");
static_assert(__builtin_offsetof(Shadow, light_space) == 0, "Shadow.light_space: std140");
static_assert(__builtin_offsetof(Shadow, reach) == 64, "Shadow.reach: std140");

struct ae_VertexParams {
    Throng throng;
    Shadow shadow;
};
static_assert(sizeof(ae_VertexParams) == 160, "ae_VertexParams: std140");
static_assert(__builtin_offsetof(ae_VertexParams, throng) == 0, "ae_VertexParams.throng: std140");
static_assert(__builtin_offsetof(ae_VertexParams, shadow) == 80, "ae_VertexParams.shadow: std140");

struct ae_crowd_depth_vertex_in {
    float3 inPosition [[attribute(0)]];
    float4 instanceModel_0 [[attribute(3)]];
    float4 instanceModel_1 [[attribute(4)]];
    float4 instanceModel_2 [[attribute(5)]];
    float4 instanceModel_3 [[attribute(6)]];
    float4 inJoints [[attribute(8)]];
    float4 inWeights [[attribute(9)]];
    float instancePhase [[attribute(11)]];
};

struct ae_crowd_depth_vertex_out {
    float4 ae_position [[position]];
    float3 BindPos [[user(locn0)]];
    float ClipLimb [[user(locn1)]];
};

static float4x4 ae3d_shaders_throng_bone_at(texture2d<float> bank, sampler ae_smp_bank, int bone, int frame) {
    int x = bone * 4;
    return float4x4(bank.read(uint2(int2((x + 0), frame)), 0), bank.read(uint2(int2((x + 1), frame)), 0), bank.read(uint2(int2((x + 2), frame)), 0), bank.read(uint2(int2((x + 3), frame)), 0));
}

static float4x4 ae3d_shaders_throng_skin_at(texture2d<float> bank, sampler ae_smp_bank, float4 joints, float4 weights, int frame) {
    return ((((weights.x * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.x), frame)) + (weights.y * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.y), frame))) + (weights.z * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.z), frame))) + (weights.w * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.w), frame)));
}

vertex ae_crowd_depth_vertex_out ae_crowd_depth_vertex_vertex(
    ae_crowd_depth_vertex_in ae_in [[stage_in]],
    constant ae_VertexParams& ae_params [[buffer(3)]],
    texture2d<float> pose_bank [[texture(0)]], sampler ae_smp_pose_bank [[sampler(0)]]) {
    ae_crowd_depth_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float4x4 instanceModel = float4x4(ae_in.instanceModel_0, ae_in.instanceModel_1, ae_in.instanceModel_2, ae_in.instanceModel_3);
    float4 inJoints = ae_in.inJoints;
    float4 inWeights = ae_in.inWeights;
    float instancePhase = ae_in.instancePhase;
    constant Throng& throng = ae_params.throng;
    constant Shadow& shadow = ae_params.shadow;
    float4x4 model_matrix = (throng.model * instanceModel);
    if (shadow.reach.w > 0.0 && distance(model_matrix[3].xyz, shadow.reach.xyz) > shadow.reach.w) {
        ae_out.ae_position = float4(float3(2.0, 2.0, 2.0), 1.0);
        ae_out.BindPos = inPosition;
        ae_out.ClipLimb = 1.0;
        ae_out.ae_position.y = -ae_out.ae_position.y;
        return ae_out;
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
    float4x4 skin = ((ae3d_shaders_throng_skin_at(pose_bank, ae_smp_pose_bank, inJoints, inWeights, frame0) * (1.0 - blend)) + (ae3d_shaders_throng_skin_at(pose_bank, ae_smp_pose_bank, inJoints, inWeights, frame1) * blend));
    float4 posed = (skin * float4(inPosition, 1.0));
    ae_out.ae_position = ((shadow.light_space * model_matrix) * posed);
    ae_out.BindPos = inPosition;
    ae_out.ClipLimb = 1.0;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
