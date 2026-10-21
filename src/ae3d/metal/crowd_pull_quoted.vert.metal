// crowd_pull_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;
static inline float3x3 ae_mat3(float4x4 m) { return float3x3(m[0].xyz, m[1].xyz, m[2].xyz); }

struct Throng {
    float4x4 model;
    int frames;
    int impostor;
    int columns;
    int rows;
    float width;
    float height;
    float travel;
    float phase_step;
    int pull_bits;
    char ae_pad0[12];
};
static_assert(sizeof(Throng) == 112, "Throng: std140");
static_assert(__builtin_offsetof(Throng, model) == 0, "Throng.model: std140");
static_assert(__builtin_offsetof(Throng, frames) == 64, "Throng.frames: std140");
static_assert(__builtin_offsetof(Throng, impostor) == 68, "Throng.impostor: std140");
static_assert(__builtin_offsetof(Throng, columns) == 72, "Throng.columns: std140");
static_assert(__builtin_offsetof(Throng, rows) == 76, "Throng.rows: std140");
static_assert(__builtin_offsetof(Throng, width) == 80, "Throng.width: std140");
static_assert(__builtin_offsetof(Throng, height) == 84, "Throng.height: std140");
static_assert(__builtin_offsetof(Throng, travel) == 88, "Throng.travel: std140");
static_assert(__builtin_offsetof(Throng, phase_step) == 92, "Throng.phase_step: std140");
static_assert(__builtin_offsetof(Throng, pull_bits) == 96, "Throng.pull_bits: std140");

struct Eye {
    float4x4 view_projection;
    float4x4 prev_view_projection;
    packed_float3 position;
    char ae_pad0[4];
};
static_assert(sizeof(Eye) == 144, "Eye: std140");
static_assert(__builtin_offsetof(Eye, view_projection) == 0, "Eye.view_projection: std140");
static_assert(__builtin_offsetof(Eye, prev_view_projection) == 64, "Eye.prev_view_projection: std140");
static_assert(__builtin_offsetof(Eye, position) == 128, "Eye.position: std140");

struct Shadow {
    float4x4 light_space;
};
static_assert(sizeof(Shadow) == 64, "Shadow: std140");
static_assert(__builtin_offsetof(Shadow, light_space) == 0, "Shadow.light_space: std140");

struct ae_VertexParams {
    Throng throng;
    Eye viewer;
    Shadow shadow;
};
static_assert(sizeof(ae_VertexParams) == 320, "ae_VertexParams: std140");
static_assert(__builtin_offsetof(ae_VertexParams, throng) == 0, "ae_VertexParams.throng: std140");
static_assert(__builtin_offsetof(ae_VertexParams, viewer) == 112, "ae_VertexParams.viewer: std140");
static_assert(__builtin_offsetof(ae_VertexParams, shadow) == 256, "ae_VertexParams.shadow: std140");

struct ae_crowd_pull_vertex_out {
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

static float4x4 ae3d_shaders_throng_bone_at(texture2d<float> bank, sampler ae_smp_bank, int bone, int frame) {
    int x = bone * 4;
    return float4x4(bank.read(uint2(int2((x + 0), frame)), 0), bank.read(uint2(int2((x + 1), frame)), 0), bank.read(uint2(int2((x + 2), frame)), 0), bank.read(uint2(int2((x + 3), frame)), 0));
}

static float4x4 ae3d_shaders_throng_skin_at(texture2d<float> bank, sampler ae_smp_bank, float4 joints, float4 weights, int frame) {
    return ((((weights.x * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.x), frame)) + (weights.y * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.y), frame))) + (weights.z * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.z), frame))) + (weights.w * ae3d_shaders_throng_bone_at(bank, ae_smp_bank, int(joints.w), frame)));
}

static float4x4 ae3d_shaders_throng_skin_at_phase(texture2d<float> bank, sampler ae_smp_bank, float4 joints, float4 weights, float phase, int frames) {
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
    return ((ae3d_shaders_throng_skin_at(bank, ae_smp_bank, joints, weights, frame0) * (1.0 - blend)) + (ae3d_shaders_throng_skin_at(bank, ae_smp_bank, joints, weights, frame1) * blend));
}

vertex ae_crowd_pull_vertex_out ae_crowd_pull_vertex_vertex(
    constant ae_VertexParams& ae_params [[buffer(4)]],
    texture2d<float> pose_bank [[texture(0)]], sampler ae_smp_pose_bank [[sampler(0)]],
    const device float* pulled_vertex [[buffer(8)]],
    const device float4* pulled_skin [[buffer(9)]],
    const device float* pulled_figure [[buffer(10)]],
    uint ae_vertex_id [[vertex_id]]) {
    ae_crowd_pull_vertex_out ae_out;
    constant Throng& throng = ae_params.throng;
    constant Eye& viewer = ae_params.viewer;
    constant Shadow& shadow = ae_params.shadow;
    uint bits = uint(throng.pull_bits);
    uint vi = uint(int(ae_vertex_id)) & (uint(1) << bits) - uint(1);
    uint f = (uint(int(ae_vertex_id)) >> bits) * uint(20);
    uint at = vi * uint(9);
    float3 position = float3(pulled_vertex[at], pulled_vertex[(at + uint(1))], pulled_vertex[(at + uint(2))]);
    float2 uv = float2(pulled_vertex[(at + uint(3))], pulled_vertex[(at + uint(4))]);
    float3 normal = float3(pulled_vertex[(at + uint(5))], pulled_vertex[(at + uint(6))], pulled_vertex[(at + uint(7))]);
    float occlusion = pulled_vertex[(at + uint(8))];
    float4 joints = pulled_skin[(vi * uint(3))];
    float4 weights = pulled_skin[(vi * uint(3) + uint(1))];
    float4x4 instance_model = float4x4(pulled_figure[f], pulled_figure[(f + uint(1))], pulled_figure[(f + uint(2))], pulled_figure[(f + uint(3))], pulled_figure[(f + uint(4))], pulled_figure[(f + uint(5))], pulled_figure[(f + uint(6))], pulled_figure[(f + uint(7))], pulled_figure[(f + uint(8))], pulled_figure[(f + uint(9))], pulled_figure[(f + uint(10))], pulled_figure[(f + uint(11))], pulled_figure[(f + uint(12))], pulled_figure[(f + uint(13))], pulled_figure[(f + uint(14))], pulled_figure[(f + uint(15))]);
    float3 instance_color = float3(pulled_figure[(f + uint(16))], pulled_figure[(f + uint(17))], pulled_figure[(f + uint(18))]);
    float instance_phase = pulled_figure[(f + uint(19))];
    float4x4 model_matrix = (throng.model * instance_model);
    float3 walking = normalize(float3(model_matrix[0][0], 0.0, model_matrix[0][2]));
    if (throng.impostor != 0) {
        float3 origin = model_matrix[3].xyz;
        float3 facing = normalize(float3(model_matrix[0][0], 0.0, model_matrix[0][2]));
        float3 to_eye = viewer.position - origin;
        float3 level_ = normalize(float3(to_eye.x, 0.0, to_eye.z));
        float angle = atan2(dot(level_, float3(-facing.z, 0.0, facing.x)), dot(level_, facing));
        float turn = fract(angle / 6.28318530718 + 1.0);
        int column = int(floor(turn * float(throng.columns) + 0.5)) % throng.columns;
        int row = int(floor(fract(instance_phase) * float(throng.rows))) % throng.rows;
        float3 right = normalize(cross(float3(0.0, 1.0, 0.0), level_));
        float3 world = origin + right * (position.x * throng.width) + float3(0.0, position.y * throng.height, 0.0);
        float2 cell = float2((float(column) + uv.x) / float(throng.columns), 1.0 - (float(row) + (1.0 - uv.y)) / float(throng.rows));
        float4 quad_light = (shadow.light_space * float4(world, 1.0));
        float4 quad_now = (viewer.view_projection * float4(world, 1.0));
        float4 quad_prev = (viewer.prev_view_projection * float4(world - walking * throng.travel, 1.0));
        ae_out.ae_position = quad_now;
        ae_out.fragTexCoord = cell;
        ae_out.Normal = facing;
        ae_out.FragPos = world;
        ae_out.InstanceColor = instance_color;
        ae_out.FragPosLightSpace = quad_light;
        ae_out.Occlusion = occlusion;
        ae_out.ClipNow = quad_now;
        ae_out.ClipPrev = quad_prev;
        ae_out.BindPos = position;
        ae_out.ClipLimb = 1.0;
        ae_out.MaskUV = uv;
        ae_out.ParticleAlpha = 1.0;
        ae_out.FlipNext = float3(0.0, 0.0, -1.0);
        ae_out.ae_position.y = -ae_out.ae_position.y;
        return ae_out;
    }
    float4x4 skin = ae3d_shaders_throng_skin_at_phase(pose_bank, ae_smp_pose_bank, joints, weights, instance_phase, throng.frames);
    float4 posed = (skin * float4(position, 1.0));
    float3 posed_normal = (ae_mat3(skin) * normal);
    float3 frag_pos = (model_matrix * posed).xyz;
    float3 normal_out = normalize((ae_mat3(model_matrix) * posed_normal));
    float4 light = (shadow.light_space * float4(frag_pos, 1.0));
    float4 now = ((viewer.view_projection * model_matrix) * posed);
    float4 posed_prev = (ae3d_shaders_throng_skin_at_phase(pose_bank, ae_smp_pose_bank, joints, weights, instance_phase - throng.phase_step, throng.frames) * float4(position, 1.0));
    float4 world_prev = (model_matrix * posed_prev);
    float4 stepped = float4(world_prev.xyz - walking * throng.travel, world_prev.w);
    float4 prev = (viewer.prev_view_projection * stepped);
    ae_out.ae_position = now;
    ae_out.fragTexCoord = uv;
    ae_out.Normal = normal_out;
    ae_out.FragPos = frag_pos;
    ae_out.InstanceColor = instance_color;
    ae_out.FragPosLightSpace = light;
    ae_out.Occlusion = occlusion;
    ae_out.ClipNow = now;
    ae_out.ClipPrev = prev;
    ae_out.BindPos = position;
    ae_out.ClipLimb = 1.0;
    ae_out.MaskUV = uv;
    ae_out.ParticleAlpha = 1.0;
    ae_out.FlipNext = float3(0.0, 0.0, -1.0);
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
