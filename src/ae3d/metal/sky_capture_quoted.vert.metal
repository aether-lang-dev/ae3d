// screen: written by ae3d.gpu from its quote.
#include <metal_stdlib>
using namespace metal;

struct ae_screen_in {
    float3 inPosition [[attribute(0)]];
    float2 inTexCoord [[attribute(1)]];
};

struct ae_screen_out {
    float4 ae_position [[position]];
    float2 uv [[user(locn0)]];
};

vertex ae_screen_out ae_screen_vertex(
    ae_screen_in ae_in [[stage_in]]) {
    ae_screen_out ae_out;
    float3 inPosition = ae_in.inPosition;
    float2 inTexCoord = ae_in.inTexCoord;
    ae_out.ae_position = float4(float3(inPosition.x, inPosition.y, 0.0), 1.0);
    ae_out.uv = inTexCoord;
    ae_out.ae_position.y = -ae_out.ae_position.y;
    return ae_out;
}
