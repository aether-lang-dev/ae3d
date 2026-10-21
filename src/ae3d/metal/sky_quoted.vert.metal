// sky_vertex: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_VertexParams {
    float4x4 projection;
    float4x4 view;
    float4x4 prev_view_projection;
};
static_assert(sizeof(ae_VertexParams) == 192, "ae_VertexParams: std140");
static_assert(__builtin_offsetof(ae_VertexParams, projection) == 0, "ae_VertexParams.projection: std140");
static_assert(__builtin_offsetof(ae_VertexParams, view) == 64, "ae_VertexParams.view: std140");
static_assert(__builtin_offsetof(ae_VertexParams, prev_view_projection) == 128, "ae_VertexParams.prev_view_projection: std140");

struct ae_sky_vertex_in {
    float3 inPosition [[attribute(0)]];
};

struct ae_sky_vertex_out {
    float4 ae_position [[position]];
    float3 tex_coords [[user(locn0)]];
    float4 clip_now [[user(locn1)]];
    float4 clip_prev [[user(locn2)]];
};

vertex ae_sky_vertex_out ae_sky_vertex_vertex(
    ae_sky_vertex_in ae_in [[stage_in]],
    constant ae_VertexParams& ae_params [[buffer(1)]]) {
    ae_sky_vertex_out ae_out;
    float3 inPosition = ae_in.inPosition;
    constant float4x4& projection = ae_params.projection;
    constant float4x4& view = ae_params.view;
    constant float4x4& prev_view_projection = ae_params.prev_view_projection;
    float4 pos = ((projection * view) * float4(inPosition, 1.0));
    ae_out.ae_position = float4(float3(pos.x, pos.y, pos.w), pos.w);
    ae_out.tex_coords = inPosition;
    ae_out.clip_now = pos;
    ae_out.clip_prev = (prev_view_projection * float4(inPosition, 0.0));
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
