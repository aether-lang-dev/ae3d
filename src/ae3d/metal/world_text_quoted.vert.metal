// world_text_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_VertexParams {
    float4x4 view_projection;
    float4x4 prev_view_projection;
};
static_assert(sizeof(ae_VertexParams) == 128, "ae_VertexParams: std140");
static_assert(__builtin_offsetof(ae_VertexParams, view_projection) == 0, "ae_VertexParams.view_projection: std140");
static_assert(__builtin_offsetof(ae_VertexParams, prev_view_projection) == 64, "ae_VertexParams.prev_view_projection: std140");

struct ae_world_text_vertex_in {
    float3 inPosition [[attribute(0)]];
    float2 inTexCoord [[attribute(1)]];
    float3 inNormal [[attribute(2)]];
    float4 instanceModel_0 [[attribute(3)]];
    float4 instanceModel_1 [[attribute(4)]];
    float4 instanceModel_2 [[attribute(5)]];
    float4 instanceModel_3 [[attribute(6)]];
    float inOcclusion [[attribute(10)]];
};

struct ae_world_text_vertex_out {
    float4 ae_position [[position]];
    float2 uv [[user(locn0)]];
    float3 colour [[user(locn1)]];
    float alpha [[user(locn2)]];
    float4 clip_now [[user(locn3)]];
    float4 clip_prev [[user(locn4)]];
};

static float3 ae3d_shaders_lettering_text_place(float3 origin, float3 right, float3 up, float x, float y) {
    return origin + right * x - up * y;
}

vertex ae_world_text_vertex_out ae_world_text_vertex_vertex(
    ae_world_text_vertex_in ae_in [[stage_in]],
    constant ae_VertexParams& ae_params [[buffer(1)]]) {
    ae_world_text_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float2 inTexCoord = ae_in.inTexCoord;
    float3 inNormal = ae_in.inNormal;
    float4x4 instanceModel = float4x4(ae_in.instanceModel_0, ae_in.instanceModel_1, ae_in.instanceModel_2, ae_in.instanceModel_3);
    float inOcclusion = ae_in.inOcclusion;
    constant float4x4& view_projection = ae_params.view_projection;
    constant float4x4& prev_view_projection = ae_params.prev_view_projection;
    float4 right = instanceModel[0];
    float3 world = ae3d_shaders_lettering_text_place(instanceModel[2].xyz, right.xyz, instanceModel[1].xyz, inPosition.x, inPosition.y);
    float4 now = (view_projection * float4(world, 1.0));
    float4 prev = (prev_view_projection * float4(world, 1.0));
    float z = mix(now.z, 0.0001 * now.w, right.w);
    ae_out.ae_position = float4(float3(now.x, now.y, z), now.w);
    ae_out.uv = inTexCoord;
    ae_out.colour = inNormal;
    ae_out.alpha = inOcclusion;
    ae_out.clip_now = now;
    ae_out.clip_prev = prev;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
